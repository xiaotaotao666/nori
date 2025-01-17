#!/usr/bin/env nextflow

params.projectdir = '../../'
params.out = "."

input_file = file(params.input)

// PARAMETERS
/////////////////////////////////////

// HSIC lasso
params.causal = 50
params.select = 50
params.M = 3
params.B = 5
params.type = 'classification'

// READ DATA
/////////////////////////////////////
if (input_file.getExtension() == 'mat') {

    process read_matlab {

        clusterOptions = '-V -jc pcc-skl'

        input:
            file INPUT_FILE from input_file

        output:
            file 'x.npy' into X
            file 'y.npy' into Y
            file 'featnames.npy' into FEATNAMES

        script:
        template 'io/mat2npy.py'

    }

    process normalize_data {

        clusterOptions = '-V -jc pcc-skl'

        input:
            file X

        output:
            file "x_normalized.npy" into normalized_X

        script:
        template 'data_processing/normalize.py'

    }

} else if (input_file.getExtension() == 'tsv' || input_file.getExtension() == 'txt') {

    metadata = file(params.metadata)
    M = params.M
    
    process read_tsv {

        clusterOptions = '-V -jc pcc-skl'

        input:
            file INPUT_FILE from input_file
            file METADATA from metadata
            val COL_FEATS from params.col_feats
            val COL_ID from params.col_id
            val COL_Y from params.col_y

        output:
            file 'x.npy' into RAW_X
            file 'y.npy' into Y
            file 'featnames.npy' into FEATNAMES

        script:
        template 'io/tsv2npy.py'

    }

    process impute_expression {

        clusterOptions = '-V -jc pcc-skl'

        input:
            file X from RAW_X

        output:
            file 'x_imputed.npy' into X

        script:
        template 'data_processing/impute_magic.py'

    }
} else if (input_file.getExtension() == 'ped') {

    ped1 = input_file
    map1 = file(params.map1)
    ped2 = file(params.ped2)
    map2 = file(params.map2)

    input_files = Channel.from ( [ped1,map1], [ped2,map2] )

    M = String.valueOf(params.M) + ', discrete_x = True'

    process set_phenotypes {

        clusterOptions = '-V -jc pcc-skl'

        input:
            set file(PED), file(MAP) from input_files
            val Y from 1..2

        output:
            file MAP into maps
            file 'new_phenotype.ped' into peds

        script:
        """
        awk '{\$6 = "$Y"; print}' $PED >new_phenotype.ped
        """

    }

    process merge_datasets {

        clusterOptions = '-V -jc pcc-skl'

        input:
            file 'map*' from maps. collect()
            file 'ped*' from peds. collect()

        output:
            file 'merged.ped' into ped
            file 'merged.map' into map, map_out

        """
        plink --ped ped1 --map map1 --merge ped2 map2 --allow-extra-chr --allow-no-sex --recode --out merged
        """

    }

    process read_genotype {

    clusterOptions = '-V -jc pcc-skl'

    input:
        file MAP from map
        file PED from ped

    output:
        file 'x.npy' into X
        file 'y.npy' into Y
        file 'featnames.npy' into FEATNAMES

    script:
    template 'io/ped2npy.R' 

    }

}

//  FEATURE SELECTION
/////////////////////////////////////
process run_hsic_clustering {

    clusterOptions = '-V -jc pcc-large'
    publishDir "$params.out", overwrite: true, mode: "copy"

    input:
        file X_TRAIN from X
        file Y_TRAIN from Y
        file FEATNAMES
        val C from params.causal
        val HL_SELECT from params.select
        val HL_M from params.M
        val HL_B from params.B
        val MODE from params.type
    
    output:
        file 'dendrogram.png'
        file 'heatmap.png'

    script:
    template 'feature_selection/hsic_clustering.py'

}