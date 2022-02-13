from itertools import combinations, product
import collections
from pprint import pprint
import typing
import random
from matplotlib import pyplot as plt
import sys
import functools
import numpy as np

N = 7

Tri = typing.Tuple[int, int, int]


def count():
    for a, b, c in combinatons(rangep(7), 3):
        print(a, b, c)


def _ptri(tri):
    print(f'{tri[0]}{tri[1]}{tri[2]}')

def _pS(S):
    for tri, v in S.items():
        if v != 0:
            _ptri(tri)

def sortLex(tri: Tri) -> Tri:
    return tuple(sorted(tri))

def move(S, a, b):
    for tri in [
        a,
        (a[0], b[1], b[2]),
        (b[0], a[1], b[2]),
        (b[0], b[1], a[2]),
    ]:
        S[sortLex(tri)] += 1

    for tri in [
        (b[0], a[1], a[2]),
        (a[0], b[1], a[2]),
        (a[0], a[1], b[2]),
        b,
    ]:
        S[sortLex(tri)] -= 1

    return S


def _packNb(v, base, padding):
    return f'{np.base_repr(v, base=base):0>{padding}}'

packNb = functools.partial(_packNb, base=min(N, 36), padding = max(0, N - 36 + 1))


def packSTS(S):
    result = ''
    for i in (1, -1):
        result += ''.join([''.join(packNb(n) for n in tri) for tri, v in S.items() if v == i])
    return result

def findComp(ones, a, b):
    for tri in ones:
        if (a in tri) and (b in tri):
            return list(set(tri) - set([a, b]))[0]
    # should be unreachable

def packSTS(f):
    return hash(tuple([(k, v) for k, v in f.items()]))

def chooseComp(ones, a, b):
    choices = []
    for tri in ones:
        if (a in tri) and (b in tri):
            choices.append(list(set(tri) - set([a, b]))[0])
    assert(len(choices) == 2)
    return random.choice(choices)

def mh():
    f = {k: 0 for k in combinations(range(N), 3)}

    # starting system
    if N == 7:
        for tri in [(0, 1, 2), (0, 3, 4), (0, 5, 6), (1, 3, 5), (1, 4, 6), (2, 3, 6), (2, 4, 5)]:
            f[tri] = 1
    elif N == 9:
        for tri in [(0, 1, 2), (0, 3, 6), (0, 4, 8), (0, 5, 7), (1, 3, 8), (1, 4, 7), (1, 5, 6), (2, 3, 7), (2, 4, 6), (2, 5, 8), (3, 4, 5), (6, 7, 8)]:
            f[tri] = 1
    elif N == 13:
        for tri in [(0, 1, 2), (0, 3, 4), (0, 5, 6), (0, 7, 8), (0, 9, 10), (0, 11, 12), (1, 3, 5), (1, 4, 7), (1, 6, 8), (1, 9, 11), (1, 10, 12), (2, 3, 9), (2, 4, 5), (2, 6, 10), (2, 7, 12), (2, 8, 11), (3, 6, 11), (3, 7, 10), (3, 8, 12), (4, 6, 12), (4, 8, 9), (4, 10, 11), (5, 7, 11), (5, 8, 10), (5, 9, 12), (6, 7, 9)]:
            f[tri] = 1


    seen = [packSTS(f)]
    sawNewSteps = []

    a, b = 1, 2

 # 1_197504000
    for n in range(5000):
        ones = [k for k, v in f.items() if v == 1]
        if -1 not in list(f.values()): # f is proper
            x, y, z = random.choice([k for k, v in f.items() if v == 0])
            xp = findComp(ones, y, z)
            yp = findComp(ones, x, z)
            zp = findComp(ones, x, y)
        else: # f is improper
            x, y, z = next((k for k, v in f.items() if v == -1))
            xp = chooseComp(ones, y, z)
            yp = chooseComp(ones, x, z)
            zp = chooseComp(ones, x, y)

        # print((x, y, z), (xp, yp, zp))
        f = move(f, (x, y, z), (xp, yp, zp))
        # breakpoint()
        if -1 not in f.values():
            packf = packSTS(f)
            if packf not in seen:
                sawNewSteps.append(n)
                seen.append(packf)

    print(f'{len(seen)} systèmes différents')
    # print(sawNewSteps)
    plt.hist(sawNewSteps)
    plt.show()

def constructSTS(n=15):
    sts = []
    sts.append((0, n - 2, n - 1))
    i = 0
    everyTriple = set([
        sortLex(x) for x in product(range(n - 2), repeat=3)
        if sum(x) % (n - 2) == 0
    ])
    for tri in everyTriple:
        if len(set(tri)) == 2: # TODO need to deal with odd cycle
            print(tri)
            sts.append(sortLex(tuple(list(set(tri)) + [n - 1 - (i % 2)])))
            # print(sts[-1])
            i += 1
        elif len(set(tri)) == 1:
            pass # nothing to be done (only (0, 0, 0) and already dealt with)
        elif len(set(tri)) == 3:
            sts.append(sortLex(tri))
    sts = sorted(list(set(sts)))
    # pprint(sts)
    # print(len(sts))
    print(isSts(sts, n))

def isSts(S, n):
    stsDuo_l = []
    for a, b, c in S:
        stsDuo_l += [(a, b), (a, c), (b, c)]
    stsDuo = set(stsDuo_l)

    if len(stsDuo) != len(stsDuo_l):
        print(len(stsDuo), len(stsDuo_l))
        print('elements not unique')
        print([k for k, v in collections.Counter(stsDuo_l).items() if v > 1])

    allDuos = set(combinations(range(n), 2))
    truth = stsDuo == allDuos
    if not truth:
        print(f'expected {len(allDuos)} couples got {len(stsDuo)}')
        print(f'{allDuos - stsDuo} not in sts')

    return truth


# constructSTS()

mh()
