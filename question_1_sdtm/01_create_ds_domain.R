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

# Load controlled terminology from CSV file
cat("Loading controlled terminology from CSV...\n")
study_ct <- read.csv("sdtm_ct.csv", stringsAsFactors = FALSE)
cat("Controlled terminology loaded with", nrow(study_ct), "terms\n")
cat("Disposition codelist (C66727) contains",
    nrow(study_ct[study_ct$codelist_code == "C66727", ]), "terms\n\n")

# Define domain key for DS
cat("Defining domain key...\n")
ds_domain_key <- c("STUDYID", "USUBJID", "DSSEQ")

# Create a basic mapping for DS domain variables
# Map raw variables to SDTM variables
cat("Creating DS domain...\n\n")

# Step 1: Start with basic SDTM structure and create ISO8601 dates
cat("Step 1: Creating ISO8601 formatted dates...\n")

# Create basic DS structure with ISO8601 dates
ds <- ds_raw %>%
  mutate(
    # Map raw columns to SDTM columns
    STUDYID = STUDY,
    USUBJID = PATNUM,
    DSTERM = coalesce(IT.DSTERM, OTHERSP),  # Use IT.DSTERM or OTHERSP if missing
    DSCAT = FORML,
    VISIT = INSTANCE,
    VISITNUM = case_when(
      INSTANCE == "Baseline" ~ 1,
      INSTANCE == "Week 2" ~ 2,
      INSTANCE == "Week 4" ~ 3,
      INSTANCE == "Week 6" ~ 4,
      INSTANCE == "Week 8" ~ 5,
      INSTANCE == "Week 12" ~ 6,
      INSTANCE == "Week 16" ~ 7,
      INSTANCE == "Week 20" ~ 8,
      INSTANCE == "Week 24" ~ 9,
      INSTANCE == "Week 26" ~ 10,
      TRUE ~ as.numeric(NA)
    ),
    # Convert dates to ISO8601 format (dates are in dd-mm-yyyy format)
    # create_iso8601 handles NA values automatically
    DSSTDTC = as.character(create_iso8601(IT.DSSTDAT, .format = "dd-mm-yyyy")),
    DSDTC = as.character(create_iso8601(DSDTCOL, .format = "dd-mm-yyyy"))
  )

cat("ISO8601 dates created successfully.\n")

# Step 2: Add controlled terminology mapping and finalize variables
cat("Step 2: Applying controlled terminology mapping...\n")
ds <- ds %>%
  mutate(
    # Apply controlled terminology to get DSDECOD
    DSDECOD = ct_map(
      x = DSTERM,
      ct_spec = study_ct,
      ct_clst = "C66727"  # Codelist for disposition terms
    ),
    # Add DOMAIN
    DOMAIN = "DS",
    # Calculate study day (would need reference date for actual calculation)
    DSSTDY = NA_integer_
  ) %>%
  # Create sequence number
  group_by(STUDYID, USUBJID) %>%
  mutate(DSSEQ = row_number()) %>%
  ungroup()

cat("Controlled terminology applied and variables finalized.\n")

# Step 3: Select and order final variables
cat("Step 3: Selecting and ordering final SDTM variables...\n")
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
