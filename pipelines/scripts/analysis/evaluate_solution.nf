params.out = '.'

features = file("$params.features")
predictions = file("$params.predictions")
Y = file("$params.Y")

process evaluate_features {

  publishDir "$params.out", overwrite: true, mode: "copy"

  input:
    file features

  output:
    file 'feature_stats' into feature_stats

  """
  #!/usr/bin/env Rscript
  library(tidyverse)

  features <- read_tsv("$features", col_types = 'i', col_names = FALSE)
  selected <- intersect(seq(1, $params.causal), features\$X1)
  tpr <- length(selected) / $params.causal

  data_frame(model = "$params.model", n = $params.n,
             d = $params.d, i = $params.i,
             c = $params.causal, tpr = tpr) %>%
    write_tsv("feature_stats", col_names = FALSE)
  """

}

process evaluate_predictions {

  publishDir "$params.out", overwrite: true, mode: "copy"

  input:
    file predictions
    file Y

  output:
    file 'prediction_stats' into prediction_stats

  """
  #!/usr/bin/env Rscript
  library(tidyverse)
  library(RcppCNPy)

  predictions <- read_tsv("$predictions", col_names = FALSE, col_types = 'd')\$X1
  Y <- npyLoad("$Y") %>% t
  r2 <- cor(predictions, Y) ^ 2

  data_frame(model = "$params.model", n = $params.n,
             d = $params.d, i = $params.i,
             c = $params.causal, r2 = as.numeric(r2)) %>%
    write_tsv("prediction_stats", col_names = FALSE)
  """

}
