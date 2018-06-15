#!/usr/bin/env nextflow

params.projectdir = '../../'
params.out = "."

params.perms = 10
params.n = [100, 1000, 10000]
params.d = [1000, 2500, 5000, 10000]
params.B = [10, 20, 30, 40, 50]

bins = file("${params.projectdir}/pipelines/scripts")
binSimulateData = file("$bins/io/generate_non-linear_data.nf")
binHSICLasso = file("$bins/methods/hsic_lasso.nf")
binLasso = file("$bins/methods/lasso.nf")
binmRMR = file("$bins/methods/mrmr.nf")
binKernelRegression = file("$bins/methods/kernel_regression.nf")
binSimulateData = file("$bins/io/generate_non-linear_data.nf")
binEvaluateSolution = file("$bins/analysis/evaluate_solution.nf")

process simulate_data {

  input:
    each n from params.n
    each d from params.d
    each i from 1..params.perms
    file binSimulateData

  output:
    set n,d,i, "X.npy", "Y.npy", "snps.npy" into data

  """
  nextflow run $binSimulateData --n $n --d $d
  """

}

data.into { data_hsic; data_block_hsic; data_lasso; data_mrmr }

process run_HSIC_lasso {

  input:
    file binHSICLasso
    file binEvaluateSolution
    set n,d,i,"X.npy","Y.npy","snps.npy" from data_hsic

  output:
    file 'feature_stats' into features_hsic
    file 'prediction_stats' into predictions_hsic

  """
  nextflow run $binHSICLasso --X X.npy --Y Y.npy --snps snps.npy --B 0 --mode regression
  nextflow run $binKernelRegression --X X.npy --Y Y.npy --selected_features features
  nextflow run $binEvaluateSolution --features features --Y Y.npy --predictions predictions --n $n --d $d --i $i --model 'hsic_lasso'
  """

}

process run_block_HSIC_lasso {

  input:
    file binHSICLasso
    file binEvaluateSolution
    each B from params.B
    set n,d,i,"X.npy", "Y.npy", "snps.npy" from data_block_hsic

  output:
    file 'feature_stats' into features_block_hsic
    file 'prediction_stats' into predictions_block_hsic

  """
  nextflow run $binHSICLasso --X X.npy --Y Y.npy --snps snps.npy --B $B --mode regression
  nextflow run $binKernelRegression --X X.npy --Y Y.npy --selected_features features
  nextflow run $binEvaluateSolution --features features --Y Y.npy --predictions predictions --n $n --d $d --i $i --model 'hsic_lasso-b$B'
  """

}

process run_lasso {

  input:
    file binLasso
    file binEvaluateSolution
    set n,d,i,"X.npy", "Y.npy", "snps.npy" from data_lasso

  output:
    file 'feature_stats' into features_lasso
    file 'prediction_stats' into predictions_lasso

  """
  nextflow run $binLasso --X X.npy --Y Y.npy --snps snps.npy
  nextflow run $binEvaluateSolution --features features --Y Y.npy --predictions predictions --n $n --d $d --i $i --model 'lasso'
  """

}

process run_mRMR {

  input:
    file binmRMR
    file binEvaluateSolution
    set n,d,i,"X.npy", "Y.npy", "snps.npy" from data_mrmr

  output:
    file 'feature_stats' into features_mrmr
    file 'prediction_stats' into predictions_mrmr

  """
  nextflow run $binmRMR --X X.npy --Y Y.npy --snps snps.npy
  nextflow run $binKernelRegression --X X.npy --Y Y.npy --selected_features features
  nextflow run $binEvaluateSolution --features features --Y Y.npy --predictions predictions --n $n --d $d --i $i --model 'mRMR'
  """

}

features = features_block_hsic. mix(features_hsic, features_lasso, features_mrmr)
predictions = predictions_block_hsic. mix(predictions_hsic, predictions_lasso, predictions_mrmr)

process benchmark {

  publishDir "$params.out", overwrite: true, mode: "copy"

  input:
    file "feature_stats*" from features. collect()
    file "prediction_stats*" from predictions. collect()

  output:
    file 'feature_selection.tsv'
    file 'prediction.tsv'

  """
  echo 'model\tn\td\ti\tTPR' >feature_selection.tsv
  cat feature_stats* >>feature_selection.tsv

  echo 'model\tn\td\ti\tr2' >prediction.tsv
  cat prediction_stats* >>prediction.tsv
  """

}
