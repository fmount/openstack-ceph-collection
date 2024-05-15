#! /usr/bin/python

from typing import List, Dict

WEIGHTS = {
        'mon': 0.5,
        'mgr': 0.5,
        'rgw': 1,
        'osd': 1,
        'mds': 1,
        'dashboard': 1,
        'ingress': 1,
        'ganesha': 1,
}

DEFAULT_CARDINALITY = 2.0


class Node():
    def __init__(self, name: str, labels: List, crd: int):
        self.hostname = name
        self.labels: List = labels
        # cardinality is expressed as the max number of space
        # I can allocate on a given node
        self.cardinality = crd
        allocated = 0
        # allocated represents the current space allocated on
        # a given node (in terms of daemon colocation number)
        self.allocated = sum(allocated + WEIGHTS.get(label, 0)
                             for label in labels)

    def _add_daemon(self, lb: str):
        '''
        add daemon if there's enough space on the current
        Node
        '''
        assert lb is not None
        if self.allocated <= self.cardinality:
            self.labels.append(lb)
        self.allocated += WEIGHTS.get(lb, 0)

    def __repr__(self):
        d: Dict = dict()
        for attr in dir(self):
            if not callable(attr) and not attr.startswith("__") and not attr.startswith("_"):
                d[attr] = getattr(self, attr)
        return str(d)


if __name__ == '__main__':
    hosts = ['cephstorage-0', 'cephstorage-1', 'cephstorage-2']
    nodes = []
    [nodes.append(Node(h, ['osd'], 2)) for h in hosts]

    nodes[0]._add_daemon('mon')
    nodes[1]._add_daemon('rgw')

    # n = Node('cephstorage-0', ['osd'], 2)
    # n._add_daemon('mon')
    # n._add_daemon('rgw')
    [print(n) for n in nodes]
