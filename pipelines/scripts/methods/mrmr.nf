#!/usr/bin/env nextflow

params.out = "."

X = file(params.X)
Y = file(params.Y)

process prepare_csv {

  input:
    file X
    file Y

  output:
    file 'dataset.csv' into csv


  """
  #!/usr/bin/env python

  import numpy as np

  X = np.load("$X")
  Y = np.load("$Y")

  np.savetxt('dataset.csv', np.vstack((Y,X)).T,
             header = 'y,' + ','.join([ str(x) for x in np.arange(X.shape[0])]),
             delimiter = ',', comments='')
  """

}

process run_mRMR {

  publishDir "$params.out", overwrite: true, mode: "copy"

  input:
    file csv

  output:
    file 'features' into features

  """
  mrmr -i $csv -t 0 -n $params.causal >results
  grep -A `expr $params.causal + 1` mRMR results | head -n `expr $params.causal + 2` | tail -n $params.causal | cut -f3 | sed 's/ //g' >features
  """

}
