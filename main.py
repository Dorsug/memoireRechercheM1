from itertools import combinations, product
import collections
import typing
import random
import sys

OPTI = True

if not OPTI:
    from matplotlib import pyplot as plt

N = 9

Tri = typing.Tuple[int, int, int]


def count():
    for a, b, c in combinatons(rangep(7), 3):
        print(a, b, c)

def sortLex(tri: Tri) -> Tri:
    return tuple(sorted(tri))

def move(S, x, y, z, xp, yp, zp):
    for tri in [
        x  + y  + z,
        x  + yp + zp,
        xp + y  +  zp,
        xp + yp + z,
    ]:
        S[tri] += 1

    for tri in [
        xp + y  + z,
        x  + yp + z,
        x  + y  + zp,
        xp + yp + zp,
    ]:
        S[tri] -= 1

    return S


def packSTS(f):
    return hash(tuple(sorted([k for k, v in f.items() if v == 1])))


def findComp(ones, bi):
    for tri in ones:
        if bi & tri == bi:
            return bi ^ tri
    # should be unreachable

def chooseComp(ones, bi):
    choices = []
    for tri in ones:
        if bi & tri == bi:
            choices.append(bi ^ tri)
    assert(len(choices) == 2)
    return random.choice(choices)

def split(h):
    res = []
    for i in range(N):
        t = h & (1 << i)
        if t > 0:
            res.append(t)
    assert(len(res) == 3)
    return res


def mh(steps=1e5):
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


    f = {sum([(1 << n) for n in k]): v for k, v in f.items()}
    seen = [packSTS(f)]
    sawNewSteps = []

 # 1_197504000
    for n in range(int(steps)):
        ones = [k for k, v in f.items() if v == 1]
        if -1 not in list(f.values()): # f is proper
            x, y, z = split(random.choice([k for k, v in f.items() if v == 0]))
            xp = findComp(ones, y + z)
            yp = findComp(ones, x + z)
            zp = findComp(ones, x + y)
        else: # f is improper
            x, y, z = split(next((k for k, v in f.items() if v == -1)))
            xp = chooseComp(ones, y + z)
            yp = chooseComp(ones, x + z)
            zp = chooseComp(ones, x + y)

        f = move(f, x, y, z, xp, yp, zp)
        if -1 not in f.values():
            packf = packSTS(f)
            if packf not in seen:
                sawNewSteps.append(n)
                seen.append(packf)

    print(f'{len(seen)} systèmes différents')
    if not OPTI:
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

def isSts(S):
    stsDuo_l = []
    for a, b, c in S:
        stsDuo_l += [(a, b), (a, c), (b, c)]
    stsDuo = set(stsDuo_l)

    if len(stsDuo) != len(stsDuo_l):
        print(len(stsDuo), len(stsDuo_l))
        print('elements not unique')
        print([k for k, v in collections.Counter(stsDuo_l).items() if v > 1])
        return False

    allDuos = set(combinations(range(N), 2))
    truth = stsDuo == allDuos
    if not truth:
        print(f'expected {len(allDuos)} couples got {len(stsDuo)}')
        print(f'{allDuos - stsDuo} not in sts')

    return truth


# constructSTS()

mh()
