echo "=== QUARANTINE CLASSIFICATION (200 file sample) ===" | tee -a "$OUTPUT_FILE"

  GLANCE_LIST="/tmp/quarantined_glance.txt"
  GNOCCHI_LIST="/tmp/quarantined_gnocchi.txt"
  OTHER_LIST="/tmp/quarantined_other.txt"
  > "$GLANCE_LIST"
  > "$GNOCCHI_LIST"
  > "$OTHER_LIST"

  find /srv/node*/*/quarantined/objects -name "*.data" 2>/dev/null | \
      shuf -n 200 | while read QFILE; do
      META=$(swift-object-info "$QFILE" 2>/dev/null)
      [ -z "$META" ] && continue
      CNTR=$(echo "$META" | grep "^  Container:" | awk '{print $2}' | tr -d '\r')

      case "$CNTR" in
          glance) echo "$QFILE" >> "$GLANCE_LIST" ;;
          gnocchi) echo "$QFILE" >> "$GNOCCHI_LIST" ;;
          *) echo "$QFILE" >> "$OTHER_LIST" ;;
      esac
  done
