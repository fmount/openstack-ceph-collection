#!/usr/bin/env bash
#
# Run tempest
# -----------
# ARTIFACT_DIR="$HOME/tempest-dir" TEMPEST_REGEX="^tempest.api.image.*" ./openstack-tempest-run.sh
set -ex

NS_SERVICES=${NS_SERVICES:-"openstack"}

unset NAMESPACE

oc project "${NS_SERVICES}"

# Create clouds.yaml file to be used in further tests.
mkdir -p ~/.config/openstack

cat > ~/.config/openstack/clouds.yaml << EOF
$(oc get cm openstack-config -o json | jq -r '.data["clouds.yaml"]')
EOF

# Disable TLS CA verification for now
yq -i ".clouds.default.verify = False" ~/.config/openstack/clouds.yaml

export OS_CLOUD=default
KEYSTONE_SECRET_NAME=$(oc get keystoneapi keystone -o json | jq -r .spec.secret)
KEYSTONE_PASSWD_SELECT=$(oc get keystoneapi keystone -o json | jq -r .spec.passwordSelectors.admin)
OS_PASSWORD=$(oc get secret "${KEYSTONE_SECRET_NAME}" -o json | jq -r .data."${KEYSTONE_PASSWD_SELECT}" | base64 -d)
export OS_PASSWORD

# Because tempestconf complain if we don't have the password in the clouds.yaml
YQ_PASSWD=(".clouds.default.auth.password = ${OS_PASSWORD}")
yq -i "${YQ_PASSWD[@]}" ~/.config/openstack/clouds.yaml

# Configuring tempest

mkdir -p ~/tempest
pushd ~/tempest

tempest init openshift || true

pushd ~/tempest/openshift

TEMPEST_CONF_OVERRIDES=${TEMPEST_CONF_OVERRIDES:-}

discover-tempest-config --os-cloud ${OS_CLOUD} --debug --create \
identity.v3_endpoint_type public \
identity.disable_ssl_certificate_validation true \
dashboard.disable_ssl_certificate_validation true "${TEMPEST_CONF_OVERRIDES}"

# NOTE: if manila is deployed, build a default share required by tempest
if [[ "${SERVICE_NAME}" == "MANILA" ]]; then
    oc exec -it pod/openstackclient -- openstack share type create default false
fi

set +e

TEMPEST_REGEX=${TEMPEST_REGEX:-}
TEMPEST_ARGS=()

if [ "$TEMPEST_CONCURRENCY" ]; then
        TEMPEST_ARGS+=( --concurrency "$TEMPEST_CONCURRENCY")
fi

if [ "$TEMPEST_REGEX" ]; then
    tempest run --regex "$TEMPEST_REGEX" "${TEMPEST_ARGS[@]}"
else
    curl -O https://raw.githubusercontent.com/openstack-k8s-operators/ci-framework/main/roles/test_operator/files/list_allowed.yml
    curl -O https://raw.githubusercontent.com/openstack-k8s-operators/ci-framework/main/roles/test_operator/files/list_skipped.yml

    tempest-skip list-allowed --file list_allowed.yml --group "${BASE_OP}" --job "${BASE_OP}" -f value > allow.txt
    tempest-skip list-skipped --file list_skipped.yml --job "${BASE_OP}" -f value > skip.txt
    if [ -f allow.txt ] && [ -f skip.txt ]; then
        TEMPEST_ARGS+=( --exclude-list skip.txt --include-list allow.txt)
        cp allow.txt skip.txt "${ARTIFACT_DIR}"
    else
        TEMPEST_ARGS+=( --regex 'tempest.api.compute.admin.test_aggregates_negative.AggregatesAdminNegativeTestJSON')
    fi
    tempest run "${TEMPEST_ARGS[@]}"
fi
EXIT_CODE=$?
set -e

# Generate subunit
stestr last --subunit > testrepository.subunit || true

# Generate html
subunit2html testrepository.subunit stestr_results.html || true

# Copy stestr_results.html and tempest.conf to artifacts directory
if [ -f etc/tempest.conf ]; then
    cp etc/tempest.conf "${ARTIFACT_DIR}"
fi
if [ -f stestr_results.html ]; then
    cp stestr_results.html "${ARTIFACT_DIR}"
fi

if [ -f tempest.log ]; then
    cp tempest.log "${ARTIFACT_DIR}"
fi
exit $EXIT_CODE
