################################################################################
# Question 2: ADaM ADSL Dataset Creation
#
# Objective: Create an ADSL (Subject Level Analysis) dataset using SDTM source
#            data and {admiral} family of packages
#
# Input: pharmaversesdtm::dm, pharmaversesdtm::vs, pharmaversesdtm::ex,
#        pharmaversesdtm::ds, pharmaversesdtm::ae
#
# Key Derivations:
#   - AGEGR9 & AGEGR9N: Age grouping ("<18", "18-50", ">50")
#   - TRTSDTM & TRTSTMF: Treatment start date-time with time imputation
#   - ITTFL: Intent-to-treat flag
#   - LSTAVLDT: Last known alive date
################################################################################

# Load required libraries
library(admiral)
library(pharmaversesdtm)
library(dplyr)
library(lubridate)
library(stringr)

# Start logging
sink("question_2_adam/question_2_log.txt")
cat("==========================================\n")
cat("Question 2: ADaM ADSL Creation\n")
cat("Start Time:", format(Sys.time()), "\n")
cat("==========================================\n\n")

# Load SDTM datasets
cat("Loading SDTM datasets...\n")
dm <- pharmaversesdtm::dm
vs <- pharmaversesdtm::vs
ex <- pharmaversesdtm::ex
ds <- pharmaversesdtm::ds
ae <- pharmaversesdtm::ae

cat("Datasets loaded:\n")
cat("  - DM:", nrow(dm), "records\n")
cat("  - VS:", nrow(vs), "records\n")
cat("  - EX:", nrow(ex), "records\n")
cat("  - DS:", nrow(ds), "records\n")
cat("  - AE:", nrow(ae), "records\n\n")

# Start with DM as base for ADSL
cat("Creating ADSL from DM domain...\n")
adsl <- dm %>%
  # Convert DM variables to ADSL variables
  mutate(
    STUDYID = STUDYID,
    USUBJID = USUBJID,
    SUBJID = SUBJID,
    SITEID = SITEID,
    AGE = AGE,
    AGEU = AGEU,
    SEX = SEX,
    RACE = RACE,
    ETHNIC = ETHNIC,
    COUNTRY = COUNTRY,
    ARM = ARM,
    ARMCD = ARMCD,
    ACTARM = ARM,
    ACTARMCD = ARMCD,
    RFSTDTC = RFSTDTC,
    RFENDTC = RFENDTC
  )

cat("Base ADSL created with", nrow(adsl), "subjects\n\n")

# Derive AGEGR9 and AGEGR9N
cat("Deriving age grouping variables (AGEGR9, AGEGR9N)...\n")
adsl <- adsl %>%
  mutate(
    AGEGR9 = case_when(
      AGE < 18 ~ "<18",
      AGE >= 18 & AGE <= 50 ~ "18 - 50",
      AGE > 50 ~ ">50",
      TRUE ~ NA_character_
    ),
    AGEGR9N = case_when(
      AGE < 18 ~ 1,
      AGE >= 18 & AGE <= 50 ~ 2,
      AGE > 50 ~ 3,
      TRUE ~ NA_real_
    )
  )

cat("Age grouping frequencies:\n")
print(table(adsl$AGEGR9, useNA = "ifany"))
cat("\n")

# Derive TRTSDTM and TRTSTMF (Treatment Start Date-Time with imputation flag)
cat("Deriving treatment start date-time (TRTSDTM, TRTSTMF)...\n")

# Process EX data to find first valid exposure
ex_first <- ex %>%
  # Filter for valid doses
  filter(
    (EXDOSE > 0) | (EXDOSE == 0 & grepl("PLACEBO", toupper(EXTRT), fixed = FALSE))
  ) %>%
  # Convert EXSTDTC to date-time with imputation
  derive_vars_dtm(
    new_vars_prefix = "EXST",
    dtc = EXSTDTC,
    highest_imputation = "M",  # Impute missing time parts
    date_imputation = "first",
    time_imputation = "first"
  ) %>%
  # Keep only complete date part records
  filter(!is.na(EXSTDTM)) %>%
  # Select first exposure per subject
  group_by(STUDYID, USUBJID) %>%
  arrange(EXSTDTM) %>%
  slice(1) %>%
  ungroup() %>%
  select(STUDYID, USUBJID, EXSTDTM, EXSTTMF)

# Merge with ADSL
adsl <- adsl %>%
  left_join(
    ex_first %>% select(USUBJID, TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF),
    by = "USUBJID"
  )

cat("Treatment start dates derived for", sum(!is.na(adsl$TRTSDTM)), "subjects\n\n")

# Derive TRTEDTM (Treatment End Date-Time) for LSTAVLDT calculation
ex_last <- ex %>%
  filter(
    (EXDOSE > 0) | (EXDOSE == 0 & grepl("PLACEBO", toupper(EXTRT), fixed = FALSE))
  ) %>%
  derive_vars_dtm(
    new_vars_prefix = "EXEN",
    dtc = EXENDTC,
    highest_imputation = "M",
    date_imputation = "last",
    time_imputation = "last"
  ) %>%
  filter(!is.na(EXENDTM)) %>%
  group_by(STUDYID, USUBJID) %>%
  arrange(desc(EXENDTM)) %>%
  slice(1) %>%
  ungroup() %>%
  select(STUDYID, USUBJID, EXENDTM)

adsl <- adsl %>%
  left_join(
    ex_last %>% select(USUBJID, TRTEDTM = EXENDTM),
    by = "USUBJID"
  )

# Derive ITTFL (Intent-to-Treat Flag)
cat("Deriving ITT flag (ITTFL)...\n")
adsl <- adsl %>%
  mutate(
    ITTFL = if_else(!is.na(ARM), "Y", "N")
  )

cat("ITTFL frequencies:\n")
print(table(adsl$ITTFL, useNA = "ifany"))
cat("\n")

# Derive LSTAVLDT (Last Known Alive Date)
cat("Deriving last known alive date (LSTAVLDT)...\n")

# 1. Last vital signs date with valid result
vs_last <- vs %>%
  filter(!is.na(VSSTRESN) | !is.na(VSSTRESC)) %>%
  derive_vars_dt(
    new_vars_prefix = "VS",
    dtc = VSDTC
  ) %>%
  filter(!is.na(VSDT)) %>%
  group_by(USUBJID) %>%
  summarise(VS_LAST_DT = max(VSDT, na.rm = TRUE), .groups = "drop")

# 2. Last AE onset date
ae_last <- ae %>%
  derive_vars_dt(
    new_vars_prefix = "AEST",
    dtc = AESTDTC
  ) %>%
  filter(!is.na(AESTDT)) %>%
  group_by(USUBJID) %>%
  summarise(AE_LAST_DT = max(AESTDT, na.rm = TRUE), .groups = "drop")

# 3. Last disposition date
ds_last <- ds %>%
  derive_vars_dt(
    new_vars_prefix = "DSST",
    dtc = DSSTDTC
  ) %>%
  filter(!is.na(DSSTDT)) %>%
  group_by(USUBJID) %>%
  summarise(DS_LAST_DT = max(DSSTDT, na.rm = TRUE), .groups = "drop")

# 4. Last exposure date (from TRTEDTM)
ex_last_dt <- adsl %>%
  filter(!is.na(TRTEDTM)) %>%
  mutate(EX_LAST_DT = as.Date(TRTEDTM)) %>%
  select(USUBJID, EX_LAST_DT)

# Combine all last dates
adsl <- adsl %>%
  left_join(vs_last, by = "USUBJID") %>%
  left_join(ae_last, by = "USUBJID") %>%
  left_join(ds_last, by = "USUBJID") %>%
  left_join(ex_last_dt, by = "USUBJID") %>%
  rowwise() %>%
  mutate(
    LSTAVLDT = max(c(VS_LAST_DT, AE_LAST_DT, DS_LAST_DT, EX_LAST_DT), na.rm = TRUE)
  ) %>%
  ungroup() %>%
  # Remove temporary variables
  select(-VS_LAST_DT, -AE_LAST_DT, -DS_LAST_DT, -EX_LAST_DT)

# Handle Inf values (when all dates are NA)
adsl <- adsl %>%
  mutate(LSTAVLDT = if_else(is.infinite(LSTAVLDT), as.Date(NA), LSTAVLDT))

cat("Last alive date derived for", sum(!is.na(adsl$LSTAVLDT)), "subjects\n\n")

# Add reference start date and study day calculations
adsl <- adsl %>%
  derive_vars_dt(
    new_vars_prefix = "TRTS",
    dtc = RFSTDTC
  ) %>%
  derive_vars_dt(
    new_vars_prefix = "TRTE",
    dtc = RFENDTC
  )

# Final variable selection and ordering
cat("Finalizing ADSL dataset...\n")
adsl_final <- adsl %>%
  select(
    STUDYID, USUBJID, SUBJID, SITEID,
    AGE, AGEU, AGEGR9, AGEGR9N,
    SEX, RACE, ETHNIC, COUNTRY,
    ARM, ARMCD, ACTARM, ACTARMCD,
    TRTSDTM, TRTSTMF, TRTEDTM,
    ITTFL, LSTAVLDT,
    RFSTDTC, RFENDTC, TRTSDT, TRTEDT,
    everything()
  ) %>%
  arrange(STUDYID, USUBJID)

# Display summary
cat("\n==========================================\n")
cat("ADSL Creation Summary\n")
cat("==========================================\n")
cat("Total subjects:", nrow(adsl_final), "\n")
cat("ITT population (ITTFL='Y'):", sum(adsl_final$ITTFL == "Y"), "\n\n")

cat("Age Group Distribution:\n")
print(table(adsl_final$AGEGR9, adsl_final$ACTARM, useNA = "ifany"))
cat("\n")

cat("Key Variables Summary:\n")
cat("  - TRTSDTM populated:", sum(!is.na(adsl_final$TRTSDTM)), "subjects\n")
cat("  - TRTSTMF populated:", sum(!is.na(adsl_final$TRTSTMF)), "subjects\n")
cat("  - LSTAVLDT populated:", sum(!is.na(adsl_final$LSTAVLDT)), "subjects\n\n")

cat("First 5 records:\n")
print(head(adsl_final %>% select(USUBJID, AGE, AGEGR9, TRTSDTM, ITTFL, LSTAVLDT), 5))
cat("\n")

# Save output
cat("Saving ADSL dataset to CSV...\n")
write.csv(adsl_final, "question_2_adam/adsl_output.csv", row.names = FALSE)

cat("\n==========================================\n")
cat("Question 2 Completed Successfully!\n")
cat("End Time:", format(Sys.time()), "\n")
cat("Output saved to: question_2_adam/adsl_output.csv\n")
cat("==========================================\n")

# Stop logging
sink()

# Print success message to console
cat("\n✓ Question 2 completed successfully!\n")
cat("  - ADSL created with", nrow(adsl_final), "subjects\n")
cat("  - All required variables derived\n")
cat("  - Output saved to: question_2_adam/adsl_output.csv\n")
cat("  - Log saved to: question_2_adam/question_2_log.txt\n\n")
