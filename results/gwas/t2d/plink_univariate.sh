merge_cc --file1 controls.bed --file2 t2d.bed -with-docker hclimente/gwas-tools
plink --bfile merged --assoc fisher
sed 's/^ \+//' plink.assoc.fisher | sed 's/ \+/\t/g' | sed 's/\t$//' >univariate_association.tsv