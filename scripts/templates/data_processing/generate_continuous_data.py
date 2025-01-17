#!/usr/bin/env python
'''
Input variables:
    - N: desired number of samples.
    - D: desired number of features.
    - I: seed.
    - C: number of causal features.
Output files:
    - x_train.npy
    - y_train.npy
    - x_test.npy
    - y_test.npy
    - featnames.npy
'''

import numpy as np

np.random.seed(${I})
F = [(np.square, None), (np.sin, None), (np.cos, None)]
funs = np.random.choice(np.arange(len(F)), ${C})

print('Y = 0', end='')
for i in range(${C}):
    f,args = F[funs[i]]
    print(' + {}(x{},{})'.format(f.__name__, i, args), end='')
for i in range(2):
    f,args = F[funs[i]]
    print(' + {}(x{},{})'.format(f.__name__, ${C} + i, args), end='')

for set_type,n in zip(['train', 'test'], [${N}, 100]):

    x = np.random.randn(n, ${D})
    y = np.zeros(n)
    covars = x[:,[${C}, ${C} + 1]] + np.random.normal(scale = 0.5, size = (n,2))

    for i in range(${C}):
        f,args = F[funs[i]]
        y += f(x[:,i], args)

    for i in range(2):
        f,args = F[funs[i]]
        y += f(covars[:,i], args)
        
    np.save("x_{}.npy".format(set_type), x)
    np.save("y_{}.npy".format(set_type), y)
    np.save("covars_{}.npy".format(set_type), covars)

featnames = [ str(x) for x in np.arange(${D}) ]

np.save("featnames.npy", featnames)
