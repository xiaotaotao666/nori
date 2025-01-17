#!/usr/bin/env nextflow

params.projectdir = '../../'
params.out = "."

// PARAMETERS
/////////////////////////////////////
// setup
params.perms = 10
params.n = [100, 1000, 10000]
params.d = [1000, 2500, 5000, 10000]
params.noise = 0

params.data_generation = 'continuous'
if (params.data_generation == 'continuous') causal = [5, 10, 20]
else if (params.data_generation == 'discrete') causal = [5, 10, 20]
else if (params.data_generation == 'yamada_additive') causal = 4
else if (params.data_generation == 'yamada_nonadditive') causal = 3
NOISE = params.noise

// classifier
params.mode = 'regression'
MODE = params.mode
STAT = (MODE == 'regression')? 'mse' : 'accuracy'

// HSIC lasso
params.B = [0,5,10,20]
params.M = 3
params.hl_select = 50

M = params.M

//  GENERATE DATA
/////////////////////////////////////
process simulate_data {

    clusterOptions = '-V -jc pcc-large'

    input:
        each N from params.n
        each D from params.d
        each I from 1..params.perms
        each C from causal

    output:
        set N,D,I,C,"x_train.npy","y_train.npy",'covars_train.npy',"x_test.npy","y_test.npy","featnames.npy" into data

    script:
    if (params.data_generation == 'continuous') template 'data_processing/generate_continuous_data.py'
    else if (params.data_generation == 'discrete') template 'data_processing/generate_discrete_data.py'
    else if (params.data_generation == 'yamada_additive') template 'data_processing/yamada_additive.py'
    else if (params.data_generation == 'yamada_nonadditive') template 'data_processing/yamada_nonadditive.py'

}

//  FEATURE SELECTION
/////////////////////////////////////
data.into { data_hsic; data_lhsic; data_lasso; data_mrmr }

process run_lars {

    tag { "${C} (${I})" }
    clusterOptions = '-V -jc pcc-skl'

    input:
        set N,D,I,C, file(X_TRAIN), file(Y_TRAIN), file(COVARS), file(X_TEST), file(Y_TEST), file(FEATNAMES) from data_lasso
    
    output:
        set val('LARS'),N,D,I,C, file(X_TRAIN), file(Y_TRAIN), file(COVARS), file(X_TEST), file(Y_TEST), 'features_lars.npy' into features_lars

    script:
    template 'feature_selection/lars_spams.py'

}

process run_hsic_lasso {

    tag { "${C}, B = ${HL_B}, M = ${HL_M} (${I})" }
    clusterOptions = '-V -jc pcc-large'
    validExitStatus 0,77
    errorStrategy 'ignore'

    input:
        set N,D,I,C, file(X_TRAIN), file(Y_TRAIN), file(COVARS), file(X_TEST), file(Y_TEST), file(FEATNAMES) from data_hsic
        each HL_M from M
        each HL_B from params.B
        each HL_SELECT from params.hl_select
    
    output:
        set val("HSIC_lasso-B=$HL_B-M=$HL_M"),N,D,I,C, file(X_TRAIN), file(Y_TRAIN), file(COVARS), file(X_TEST), file(Y_TEST), 'features_hl.npy' into features_hsic

    script:
    template 'feature_selection/hsic_lasso.py'

}

process run_mrmr {

    tag { "${C} (${I})" }
    clusterOptions = '-V -jc pcc-large'

    input:
        set N,D,I,C, file(X_TRAIN), file(Y_TRAIN), file(COVARS), file(X_TEST), file(Y_TEST), file(FEATNAMES) from data_mrmr
    
    output:
        set val("mRMR"),N,D,I,C, file(X_TRAIN), file(Y_TRAIN), file(COVARS), file(X_TEST), file(Y_TEST), 'features_mrmr.npy' into features_mrmr

    script:
    template 'feature_selection/mrmr.py'

}

//  FEATURE SELECTION ANALYSIS
/////////////////////////////////////
features_hsic
    .mix( features_lars, features_mrmr ) 
    .into { features_qc; features_prediction }

process analyze_features {

    tag { "${MODEL}, ${C} causal (${I})" }
    clusterOptions = '-V -jc pcc-skl'

    input:
        set MODEL,N,D,I,C, file(X_TRAIN), file(Y_TRAIN), file(COVARS), file(X_TEST), file(Y_TEST), file(SELECTED_FEATURES) from features_qc

    output:
        file 'feature_stats' into feature_analyses

    script:
    template 'analysis/analyze_features.py'

}

process join_feature_analyses {

    clusterOptions = '-V -jc pcc-skl'
    publishDir "$params.out", overwrite: true, mode: "copy"

    input:
        file "feature_stats*" from feature_analyses. collect()

    output:
        file "${params.data_generation}_feature_selection.tsv"

    """
    echo 'model\tsamples\tfeatures\tcausal\tselected\ti\ttpr' >${params.data_generation}_feature_selection.tsv
    cat feature_stats* | sort >>${params.data_generation}_feature_selection.tsv
    """

}

//  PREDICTION
/////////////////////////////////////
process prediction {

    tag { "${MODEL}, ${C} causal (${I})" }
    clusterOptions = '-V -jc pcc-skl'
    validExitStatus 0,77

    input:
        set MODEL,N,D,I,C, file(X_TRAIN), file(Y_TRAIN), file(COVARS), file(X_TEST), file(Y_TEST), file(SELECTED_FEATURES) from features_prediction

    output:
        set MODEL,N,D,I,C, file(Y_TEST),'y_pred.npy' into predictions

    script:
    if (MODE == 'regression') template 'classifier/kernel_svm.py'
    else if (MODE == 'classification') template 'classifier/random_forest.py'

}

//  PREDICTION ANALYSIS
/////////////////////////////////////
process analyze_predictions {

    tag { "${MODEL}, ${C} causal (${I})" }
    clusterOptions = '-V -jc pcc-skl'
    
    input:
        set MODEL,N,D,I,C, file(Y_TEST),file(Y_PRED) from predictions

    output:
        file 'prediction_stats' into prediction_analysis

    script:
    template 'analysis/analyze_predictions.py'

}

process join_prediction_analyses {

    clusterOptions = '-V -jc pcc-skl'
    publishDir "$params.out", overwrite: true, mode: "copy"

    input:
        file "prediction_stats*" from prediction_analysis. collect()

    output:
        file "${params.data_generation}_prediction.tsv"

    """
    echo 'model\tsamples\tfeatures\tcausal\ti\t$STAT' >${params.data_generation}_prediction.tsv
    cat prediction_stats* | sort >>${params.data_generation}_prediction.tsv
    """

}
