#--- Libraries ---
library(tidyverse)   # includes readr
library(svDialogs)
library(conflicted)
library(openxlsx)
library(googlesheets4)

conflicts_prefer(dplyr::filter)

#--- Helper: find file(s) matching a pattern and read them with the given reader ---
find_and_read <- function(dir, pattern, reader, recursive = TRUE, required = TRUE, ...) {
  matches <- list.files(dir, pattern = pattern, full.names = TRUE, recursive = recursive)
  
  if (length(matches) == 0) {
    if (required) stop(sprintf("No file matching '%s' found in %s", pattern, dir))
    warning(sprintf("No file matching '%s' found in %s", pattern, dir))
    return(NULL)
  }
  
  reader(matches[1], ...)
}

#--- User input ---
batch_code <- dlgInput("Enter Batch Code:", Sys.info()["user"])$res

base_path      <- file.path("F:/SequenceData/batch", batch_code)
bactopia_path  <- file.path(base_path, "bactopia")

#--- Read each result file ---
bactscout_result   <- find_and_read(base_path, "^final_summary\\.csv$", read.csv, stringsAsFactors = FALSE)
amrfinder_result    <- find_and_read(file.path(bactopia_path, "amrfinder"), "amrfinder_all_results", read.xlsx, recursive = FALSE)
checkm2_result      <- read_tsv(file.path(bactopia_path, "checkm2/checkm2_out/quality_report.tsv"))
gambit_result       <- read_tsv(file.path(bactopia_path, "gambit", paste0(batch_code, "_gambit.tsv")))
mlst_result         <- read_tsv(file.path(bactopia_path, "mlst/combined_mlst.tsv"))

assembly_scan_data  <- find_and_read(
  file.path(bactopia_path, "output/bactopia-runs"),
  "^assembly-scan\\.tsv$",
  read_tsv
)

#--- Append results to Google Sheet ---
sheet_id <- "1VD5jlpE3sa63OLb6NEZWwq05ZQS8TZ8nQPYiRupgfmE"

results_to_append <- list(
  bactscout     = bactscout_result,
  gambit        = gambit_result,
  mlst_new      = mlst_result,
  checkm2       = checkm2_result,
  "assembly-scan" = assembly_scan_data,
  amrfinderplus = amrfinder_result
)

#for (sheet_name in names(results_to_append)) {
#  sheet_append(ss = sheet_id, sheet = sheet_name, data = results_to_append[[sheet_name]])
#}

walk2(results_to_append, names(results_to_append), function(data, sheet_name) {
  sheet_append(ss = sheet_id, sheet = sheet_name, data = data)
})

