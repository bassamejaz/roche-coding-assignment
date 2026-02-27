################################################################################
# Question 3A: TLG - Adverse Events Summary Table
#
# Objective: Create a summary table of treatment-emergent adverse events (TEAEs)
#            using {gtsummary}
#
# Input: pharmaverseadam::adae, pharmaverseadam::adsl
#
# Output: HTML table with AE counts and percentages by treatment group
################################################################################

# Load required libraries
library(gtsummary)
library(pharmaverseadam)
library(dplyr)
library(tidyr)
library(gt)

# Start logging
sink("question_3_tlg/question_3a_log.txt")
cat("==========================================\n")
cat("Question 3A: AE Summary Table Creation\n")
cat("Start Time:", format(Sys.time()), "\n")
cat("==========================================\n\n")

# Load data
cat("Loading ADaM datasets...\n")
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl

cat("Datasets loaded:\n")
cat("  - ADAE:", nrow(adae), "records\n")
cat("  - ADSL:", nrow(adsl), "subjects\n\n")

# Filter for treatment-emergent AEs
cat("Filtering for treatment-emergent AEs (TRTEMFL='Y')...\n")
adae_teae <- adae %>%
  filter(TRTEMFL == "Y")

cat("Treatment-emergent AEs:", nrow(adae_teae), "records\n")
cat("Subjects with TEAEs:", n_distinct(adae_teae$USUBJID), "\n\n")

# Get subject counts by treatment for denominator
cat("Calculating treatment group denominators...\n")
adsl_counts <- adsl %>%
  filter(!is.na(ACTARM)) %>%
  group_by(ACTARM) %>%
  summarise(N = n(), .groups = "drop")

print(adsl_counts)
cat("\n")

# Create summary by subject (count each AE term once per subject)
cat("Creating AE summary by subject and term...\n")
ae_summary <- adae_teae %>%
  # Keep unique AETERM per subject
  distinct(USUBJID, ACTARM, AETERM) %>%
  # Add overall category
  mutate(AE_CATEGORY = "Any TEAE")

# Count subjects with each AE term by treatment
ae_counts <- ae_summary %>%
  group_by(AETERM, ACTARM) %>%
  summarise(n_subjects = n_distinct(USUBJID), .groups = "drop") %>%
  # Add total count across all terms
  pivot_wider(
    names_from = ACTARM,
    values_from = n_subjects,
    values_fill = 0
  )

cat("AE terms found:", nrow(ae_counts), "\n\n")

# Create gtsummary table
cat("Creating summary table with gtsummary...\n")

# Prepare data for gtsummary
ae_for_table <- adae_teae %>%
  distinct(USUBJID, ACTARM, AETERM)

# Create the summary table
ae_table <- ae_for_table %>%
  tbl_summary(
    by = ACTARM,
    include = AETERM,
    label = list(AETERM ~ "Adverse Event Term"),
    statistic = all_categorical() ~ "{n} ({p}%)",
    digits = all_categorical() ~ c(0, 1),
    missing = "no"
  ) %>%
  add_overall(last = TRUE) %>%
  modify_header(
    label = "**Adverse Event**",
    all_stat_cols() ~ "**{level}**\nN = {n}"
  ) %>%
  modify_caption("**Treatment-Emergent Adverse Events Summary**") %>%
  bold_labels() %>%
  # Sort by total frequency (descending)
  sort_table_by(
    stat = "p.overall",
    decrease = TRUE
  )

# Display table to console
cat("Summary table created successfully\n\n")
print(ae_table)

# Save as HTML
cat("\nSaving table as HTML...\n")
ae_table %>%
  as_gt() %>%
  gt::gtsave(filename = "question_3_tlg/ae_summary_table.html")

# Alternative: Create a more detailed table by SOC
cat("\nCreating alternative summary by System Organ Class...\n")
ae_soc_table <- adae_teae %>%
  distinct(USUBJID, ACTARM, AESOC, AETERM) %>%
  # Create nested variable
  mutate(AE_DISPLAY = paste0("  ", AETERM)) %>%
  tbl_summary(
    by = ACTARM,
    include = c(AESOC, AE_DISPLAY),
    label = list(
      AESOC ~ "System Organ Class",
      AE_DISPLAY ~ "  Preferred Term"
    ),
    statistic = all_categorical() ~ "{n} ({p}%)",
    digits = all_categorical() ~ c(0, 1),
    missing = "no"
  ) %>%
  add_overall(last = TRUE) %>%
  modify_header(
    label = "**Adverse Event**",
    all_stat_cols() ~ "**{level}**\nN = {n}"
  ) %>%
  modify_caption("**Treatment-Emergent Adverse Events by System Organ Class**") %>%
  bold_labels()

print(ae_soc_table)

# Create frequency summary for reporting
cat("\n==========================================\n")
cat("AE Summary Statistics\n")
cat("==========================================\n")

# Overall TEAE summary
overall_teae <- adae_teae %>%
  group_by(ACTARM) %>%
  summarise(
    Subjects_with_AE = n_distinct(USUBJID),
    Total_AE_Events = n(),
    .groups = "drop"
  ) %>%
  left_join(adsl_counts, by = "ACTARM") %>%
  mutate(Percentage = round(Subjects_with_AE / N * 100, 1))

cat("\nOverall TEAE Summary:\n")
print(overall_teae)
cat("\n")

# Top 10 most frequent AEs
top_aes <- adae_teae %>%
  group_by(AETERM) %>%
  summarise(
    Total_Subjects = n_distinct(USUBJID),
    .groups = "drop"
  ) %>%
  arrange(desc(Total_Subjects)) %>%
  head(10)

cat("Top 10 Most Frequent AEs:\n")
print(top_aes)
cat("\n")

cat("==========================================\n")
cat("Question 3A Completed Successfully!\n")
cat("End Time:", format(Sys.time()), "\n")
cat("Output saved to: question_3_tlg/ae_summary_table.html\n")
cat("==========================================\n")

# Stop logging
sink()

# Print success message to console
cat("\n✓ Question 3A completed successfully!\n")
cat("  - AE summary table created\n")
cat("  - Output saved to: question_3_tlg/ae_summary_table.html\n")
cat("  - Log saved to: question_3_tlg/question_3a_log.txt\n\n")
