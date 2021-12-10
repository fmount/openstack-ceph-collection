#!/usr/bin/env python

from bs4 import BeautifulSoup
import requests
import sys
import argparse

DEFAULT_ENDPOINT = 'https://download.ceph.com/tarballs/'


def check_target(soup, ceph_version):
    for el in soup.find_all("a"):
        if ceph_version in el.contents[0]:
            print("FOUND %s" % el.contents[0])
            return True
    return False


# -- MAIN --

def parse_opts(argv):
    parser = argparse.ArgumentParser(description='Parameters')
    parser.add_argument('-c', '--check', metavar='CHECK',
                        help=("What Ceph version you're looking for"),
                        default=None)
    parser.add_argument('-u', '--url', metavar='URL',
                        help=("The endpoint to query"),
                        default="https://download.ceph.com/tarballs/")

    opts = parser.parse_args(argv[1:])

    return opts


if __name__ == "__main__":

    OPTS = parse_opts(sys.argv)
    url = DEFAULT_ENDPOINT
    ceph_version = "ceph-16.2.7"

    if OPTS.check is not None:
        ceph_version = OPTS.check

    html_content = requests.get(DEFAULT_ENDPOINT).text
    soup = BeautifulSoup(html_content, "html.parser")

    check_target(soup, ceph_version)
