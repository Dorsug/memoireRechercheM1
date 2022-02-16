from itertools import combinations, product
import collections
import typing
import random
import sys
from math import log2

OPTI = True

if not OPTI:
    from matplotlib import pyplot as plt

N = 9

def move(S, x, y, z, xp, yp, zp):
    addOne = [x  + y + z, x + yp + zp, xp + y + zp, xp + yp + z]
    subOne = [xp + y + z, x + yp + z,  x  + y + zp, xp + yp + zp]

    temp = [[], [], []]
    try:
        if S[-1][0] in addOne:
            addOne.remove(S[-1][0])
            S[-1] = []
    except IndexError:
        pass

    for j in reversed(range(len(S[1]))):
        x = S[1][j]
        if x in subOne:
            del(S[1][j])
            subOne.remove(x)

    S[-1] = subOne
    S[1] = S[1] + addOne

    return S


def packSTS(f):
    return hash(tuple(sorted(list(f[1]))))


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
    f = [[k for k, v in f.items() if v == 0], [k for k, v in f.items() if v == 1], []]

    seen = [packSTS(f)]
    sawNewSteps = []

    for n in range(int(steps)):
        ones = f[1]
        if f[-1] == []:
            x, y, z = chooseRandomZero(f)
            xp = findComp(ones, y + z)
            yp = findComp(ones, x + z)
            zp = findComp(ones, x + y)
        else: # f is improper
            x, y, z = split(f[-1][0])
            xp = chooseComp(ones, y + z)
            yp = chooseComp(ones, x + z)
            zp = chooseComp(ones, x + y)

        f = move(f, x, y, z, xp, yp, zp)
        if f[-1] == []:
            packf = packSTS(f)
            if packf not in seen:
                sawNewSteps.append(n)
                seen.append(packf)

    print(f'{len(seen)} systèmes différents')
    if not OPTI:
        plt.hist(sawNewSteps)
        plt.show()

def chooseRandomZero(f):
    def get():
        return [1 << x for x in random.sample(range(N), 3)]
    tri = get()
    while sum(tri) in (f[1] + f[-1]):
        tri = get()
    return tri

mh()
