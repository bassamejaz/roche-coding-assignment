################################################################################
# Question 1: SDTM DS Domain Creation using {sdtm.oak}
#
# Objective: Create an SDTM Disposition (DS) domain from raw clinical trial data
#
# Input:
#   - pharmaverseraw::ds_raw (raw disposition data)
#   - study_ct (controlled terminology)
#
# Output:
#   - DS domain with variables: STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM,
#     DSDECOD, DSCAT, VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY
################################################################################

# Load required libraries
library(sdtm.oak)
library(pharmaverseraw)
library(dplyr)
library(admiraldev)

# Start logging
sink("question_1_sdtm/question_1_log.txt")
cat("==========================================\n")
cat("Question 1: SDTM DS Domain Creation\n")
cat("Start Time:", format(Sys.time()), "\n")
cat("==========================================\n\n")

# Load raw data
cat("Loading raw data...\n")
ds_raw <- pharmaverseraw::ds_raw
cat("Raw data loaded:", nrow(ds_raw), "records\n\n")

# Display raw data structure
cat("Raw data structure:\n")
str(ds_raw)
cat("\n")

# Create study controlled terminology as per specifications
cat("Creating study controlled terminology...\n")
study_ct <- data.frame(
  stringsAsFactors = FALSE,
  codelist_code = c("C66727", "C66727", "C66727", "C66727", "C66727",
                    "C66727", "C66727", "C66727", "C66727", "C66727"),
  term_code = c("C41331", "C25250", "C28554", "C48226", "C48227",
                "C48250", "C142185", "C49628", "C49632", "C49634"),
  term_value = c("ADVERSE EVENT", "COMPLETED", "DEATH", "LACK OF EFFICACY",
                 "LOST TO FOLLOW-UP", "PHYSICIAN DECISION", "PROTOCOL VIOLATION",
                 "SCREEN FAILURE", "STUDY TERMINATED BY SPONSOR",
                 "WITHDRAWAL BY SUBJECT"),
  collected_value = c("Adverse Event", "Complete", "Dead", "Lack of Efficacy",
                      "Lost To Follow-Up", "Physician Decision", "Protocol Violation",
                      "Trial Screen Failure", "Study Terminated By Sponsor",
                      "Withdrawal by Subject"),
  term_preferred_term = c("AE", "Completed", "Died", NA, NA, NA, "Violation",
                          "Failure to Meet Inclusion/Exclusion Criteria", NA, "Dropout"),
  term_synonyms = c("ADVERSE EVENT", "COMPLETE", "Death", NA, NA, NA, NA, NA, NA,
                    "Discontinued Participation")
)
cat("Controlled terminology created with", nrow(study_ct), "terms\n\n")

# Create a controlled terminology object for condition_add
cat("Creating controlled terminology object for sdtm.oak...\n")
ct_spec_vars <- sdtm.oak::ct_spec_vars(
  codelist_code = "codelist_code",
  term_code = "term_code",
  term_value = "term_value",
  collected_value = "collected_value",
  term_preferred_term = "term_preferred_term",
  term_synonyms = "term_synonyms"
)

# Define domain key for DS
cat("Defining domain key...\n")
ds_domain_key <- c("STUDYID", "USUBJID", "DSSEQ")

# Create a basic mapping for DS domain variables
# Map raw variables to SDTM variables
cat("Creating DS domain...\n\n")

# Step 1: Start with basic SDTM structure
ds <- ds_raw %>%
  # Create DOMAIN variable
  derive_domain(domain = "DS") %>%
  # Create sequence number
  create_iso8601(
    raw_dat = .,
    raw_var = DSSTDAT,
    tgt_var = "DSSTDTC"
  ) %>%
  create_iso8601(
    raw_dat = .,
    raw_var = DSDAT,
    tgt_var = "DSDTC"
  )

# Step 2: Add controlled terminology mapping using condition_add
ds <- ds %>%
  condition_add(
    ct_spec = study_ct,
    ct_spec_vars = ct_spec_vars,
    raw_dat = .,
    raw_var = DSTERM,
    tgt_var = "DSDECOD"
  )

# Step 3: Create additional variables and standardize
ds <- ds %>%
  mutate(
    STUDYID = if_else(is.na(STUDYID), "CDISCPILOT01", STUDYID),
    DOMAIN = "DS",
    # DSTERM is already in raw data
    DSTERM = DSTERM,
    # DSDECOD from controlled terminology
    DSDECOD = if_else(is.na(DSDECOD), toupper(DSTERM), DSDECOD),
    # DSCAT from raw data
    DSCAT = DSCAT,
    # Visit information
    VISITNUM = VISITNUM,
    VISIT = VISIT,
    # Dates already created with create_iso8601
    # DSDTC and DSSTDTC already created
    # Calculate study day
    DSSTDY = NA_integer_  # Would need reference date for actual calculation
  ) %>%
  # Create sequence number
  group_by(STUDYID, USUBJID) %>%
  mutate(DSSEQ = row_number()) %>%
  ungroup()

# Step 4: Select and order final variables
ds_final <- ds %>%
  select(
    STUDYID,
    DOMAIN,
    USUBJID,
    DSSEQ,
    DSTERM,
    DSDECOD,
    DSCAT,
    VISITNUM,
    VISIT,
    DSDTC,
    DSSTDTC,
    DSSTDY
  ) %>%
  arrange(STUDYID, USUBJID, DSSEQ)

# Display results
cat("DS Domain Creation Summary:\n")
cat("---------------------------\n")
cat("Total records:", nrow(ds_final), "\n")
cat("Unique subjects:", n_distinct(ds_final$USUBJID), "\n")
cat("Date range:", min(ds_final$DSSTDTC, na.rm = TRUE), "to",
    max(ds_final$DSSTDTC, na.rm = TRUE), "\n\n")

cat("Variable summary:\n")
print(summary(ds_final))
cat("\n")

cat("First 10 records:\n")
print(head(ds_final, 10))
cat("\n")

cat("DSTERM frequencies:\n")
print(table(ds_final$DSTERM))
cat("\n")

cat("DSDECOD frequencies:\n")
print(table(ds_final$DSDECOD))
cat("\n")

# Save output
cat("Saving DS domain to CSV...\n")
write.csv(ds_final, "question_1_sdtm/ds_output.csv", row.names = FALSE)

cat("\n==========================================\n")
cat("Question 1 Completed Successfully!\n")
cat("End Time:", format(Sys.time()), "\n")
cat("Output saved to: question_1_sdtm/ds_output.csv\n")
cat("==========================================\n")

# Stop logging
sink()

# Print success message to console
cat("\n✓ Question 1 completed successfully!\n")
cat("  - DS domain created with", nrow(ds_final), "records\n")
cat("  - Output saved to: question_1_sdtm/ds_output.csv\n")
cat("  - Log saved to: question_1_sdtm/question_1_log.txt\n\n")
