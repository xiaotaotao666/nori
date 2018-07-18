#!/usr/bin/env nextflow

params.out = "."

params.causal = 5

process generate_data {

  publishDir "$params.out", overwrite: true, mode: "copy"

  output:
    file "*.npy" into npy
    stdout equation

  """
  #!/usr/bin/env python

  import numpy as np

  x_train = 10 * np.random.rand($params.d, $params.n)
  x_val = 10 * np.random.rand($params.d, 100)

  F = [(np.power, [4]), (np.power, [5]), (np.power, [6]),
       (np.log, None), (np.sin, None), (np.cos, None)]
  funs = np.random.choice(np.arange(len(F)), $params.causal)

  y_train = np.zeros((1, $params.n))
  y_val = np.zeros((1, 100))

  print('Y = 0', end='')
  for i in range($params.causal):
    f,args = F[funs[i]]
    print(' + {}(X[{},],{})'.format(f.__name__, i, args), end='')
    yx_train = f(x_train[i,:], args)
    yx_val = f(x_val[i,:], args)
    # normalize by the variance
    y_train += (yx_train - min(yx_train))/(max(yx_train) - min(yx_train))
    y_val += (yx_val - min(yx_val))/(max(yx_val) - min(yx_val))

  featnames = [ str(x) for x in np.arange($params.d) ]

  np.save("x_train.npy", x_train)
  np.save("y_train.npy", y_train)
  np.save("x_val.npy", x_val)
  np.save("y_val.npy", y_val)
  np.save("featnames.npy", featnames)
  """

}

equation .subscribe { println it }