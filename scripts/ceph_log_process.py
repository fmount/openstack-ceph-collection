import json
import sys
import argparse
from pprint import pprint


def parse_opts(argv):
    parser = argparse.ArgumentParser(description='Parameters')
    parser.add_argument('-l', '--log', metavar='LOG',
                        help=("Json Log file to parse"),
                        default=None)
    opts = parser.parse_args(argv[1:])
    return opts


if __name__ == "__main__":

    OPTS = parse_opts(sys.argv)
    if OPTS.log is None:
        print("No valid log input file passed")
        sys.exit(1)

    # Try to read the input log file
    try:
        with open(OPTS.log, "r") as f:
            d = json.load(f)
            f.close()
        pprint(d[1])
    except OSError as oe:
        print(f"File error: {oe}")
        sys.exit(1)
    except json.JSONDecodeError as je:
        print(f"Invalid JSON format in {OPTS.log}: {je}")
        print("The file appears to contain non-JSON data. Please check if it's the correct log file.")
        sys.exit(1)
    except (IndexError, KeyError) as ie:
        print(f"Unexpected data structure in {OPTS.log}: {ie}")
        print("The JSON data doesn't match the expected format.")
        sys.exit(1)

########################################################
#
# USAGE:
#
# python ceph_log_process.py --log /tmp/ceph_health.log
#
########################################################
