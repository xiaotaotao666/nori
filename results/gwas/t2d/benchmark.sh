nextflow run ../../../scripts/benchmark_real.nf  --input t2d.bed --bim1 t2d.bim --fam1 t2d.fam --bed2 controls.bed --bim2 controls.bim --fam2 controls.fam --causal 50 --B 20 --perms 5 -profile cluster -resume "$@"