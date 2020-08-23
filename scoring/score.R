#!/usr/bin/env Rscript
suppressPackageStartupMessages(library(argparse))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(PRROC))
parser <- ArgumentParser(description = 'Score submission')
parser$add_argument('-f', '--submission_file',  type = "character", required = T,
                    help = 'Submission path')
parser$add_argument('-g', '--goldstandard',  type = "character", required = T,
                    help = 'Goldstandard path')
parser$add_argument('-r', '--results',  type = "character", required = T,
                    help = 'Results file')
parser$add_argument('-q', '--question',  type = "character", required = T,
                    help = 'Question Number')
args <- parser$parse_args()

compute_scores <- function(submission_path, goldstandard_path) {
  predictions <- read.csv(submission_path)
  goldstandard <- read.csv(goldstandard_path)
  data <- merge(goldstandard, predictions, by="person_id")

  pos <- subset(data, status == 1)
  neg <- subset(data, status == 0)

  x = pos$score
  y = neg$score

  roc<-roc.curve(x,y)
  pr <- pr.curve(x,y)
  # just return roc and pr
  c('AUC' = round(roc$auc, 6),
    'PRAUC' = round(pr$auc.integral, 6))
}
# Mapping of scores
score_map = list("1" = compute_scores,
                 "2" = compute_scores)

scores = score_map[[args$question]](args$submission_file, args$goldstandard)
scores[['submission_status']] = "SCORED"

result_list = list()
for (key in names(scores)) {
  result_list[[key]] = scores[[key]]
}
result_list[['AUC']] = as.numeric(result_list$AUC)
result_list[['PRAUC']] = as.numeric(result_list$PRAUC)

export_json <- toJSON(result_list, auto_unbox = TRUE, pretty=T)
write(export_json, args$results)
