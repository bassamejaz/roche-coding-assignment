################################################################################
# Question 3B: TLG - Adverse Events Visualizations
#
# Objective: Create two visualizations:
#   1. AE severity distribution by treatment (bar chart/heatmap)
#   2. Top 10 most frequent AEs with 95% CI for incidence rates
#
# Input: pharmaverseadam::adae, pharmaverseadam::adsl
#
# Output: Two PNG files
################################################################################

# Load required libraries
library(ggplot2)
library(pharmaverseadam)
library(dplyr)
library(tidyr)
library(scales)
library(forcats)

# Start logging
sink("question_3_tlg/question_3b_log.txt")
cat("==========================================\n")
cat("Question 3B: AE Visualizations Creation\n")
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

cat("Treatment-emergent AEs:", nrow(adae_teae), "records\n\n")

################################################################################
# PLOT 1: AE Severity Distribution by Treatment
################################################################################

cat("Creating Plot 1: AE Severity Distribution by Treatment...\n")

# Get subject counts by treatment
adsl_counts <- adsl %>%
  filter(!is.na(ACTARM)) %>%
  group_by(ACTARM) %>%
  summarise(N = n(), .groups = "drop")

# Summarize severity by treatment
severity_summary <- adae_teae %>%
  # Count unique subjects with each severity level by treatment
  distinct(USUBJID, ACTARM, AESEV) %>%
  group_by(ACTARM, AESEV) %>%
  summarise(n_subjects = n(), .groups = "drop") %>%
  # Add total N
  left_join(adsl_counts, by = "ACTARM") %>%
  mutate(
    percentage = (n_subjects / N) * 100,
    # Create label
    label = paste0(n_subjects, "\n(", round(percentage, 1), "%)")
  )

cat("Severity summary:\n")
print(severity_summary)
cat("\n")

# Create bar chart
plot1 <- ggplot(severity_summary, aes(x = ACTARM, y = percentage, fill = AESEV)) +
  geom_bar(stat = "identity", position = "dodge", color = "black", linewidth = 0.3) +
  geom_text(
    aes(label = label),
    position = position_dodge(width = 0.9),
    vjust = -0.5,
    size = 3
  ) +
  scale_fill_manual(
    values = c("MILD" = "#90EE90", "MODERATE" = "#FFD700", "SEVERE" = "#FF6347"),
    name = "Severity"
  ) +
  labs(
    title = "Treatment-Emergent Adverse Events by Severity and Treatment",
    subtitle = "Percentage of subjects experiencing each severity level",
    x = "Treatment Group",
    y = "Percentage of Subjects (%)",
    caption = "Note: Subjects counted once per severity level"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, size = 10),
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "top",
    panel.grid.major.x = element_blank()
  ) +
  scale_y_continuous(limits = c(0, max(severity_summary$percentage) * 1.15))

# Save Plot 1
cat("Saving Plot 1 to PNG...\n")
ggsave(
  "question_3_tlg/plot1_ae_severity.png",
  plot = plot1,
  width = 10,
  height = 7,
  dpi = 300
)
cat("Plot 1 saved successfully\n\n")

################################################################################
# PLOT 2: Top 10 Most Frequent AEs with 95% CI
################################################################################

cat("Creating Plot 2: Top 10 Most Frequent AEs with 95% CI...\n")

# Calculate total subjects in study (for incidence rate denominator)
total_subjects <- n_distinct(adsl$USUBJID)
cat("Total subjects in study:", total_subjects, "\n")

# Get top 10 AEs by frequency
top10_aes <- adae_teae %>%
  group_by(AETERM) %>%
  summarise(n_subjects = n_distinct(USUBJID), .groups = "drop") %>%
  arrange(desc(n_subjects)) %>%
  head(10) %>%
  mutate(
    # Calculate incidence rate (per 100 subjects)
    incidence_rate = (n_subjects / total_subjects) * 100,
    # Calculate 95% CI using Wilson score method
    # For binomial proportion
    p = n_subjects / total_subjects,
    se = sqrt(p * (1 - p) / total_subjects),
    # Approximate 95% CI
    ci_lower = pmax(0, (p - 1.96 * se)) * 100,
    ci_upper = pmin(1, (p + 1.96 * se)) * 100,
    # Reorder by frequency for plotting
    AETERM = fct_reorder(AETERM, incidence_rate)
  )

cat("Top 10 AEs summary:\n")
print(top10_aes)
cat("\n")

# Create forest plot style visualization
plot2 <- ggplot(top10_aes, aes(x = incidence_rate, y = AETERM)) +
  # Error bars for CI
  geom_errorbarh(
    aes(xmin = ci_lower, xmax = ci_upper),
    height = 0.3,
    color = "steelblue",
    linewidth = 0.8
  ) +
  # Point estimates
  geom_point(
    aes(size = n_subjects),
    color = "darkblue",
    shape = 18
  ) +
  # Add labels with counts
  geom_text(
    aes(label = paste0(n_subjects, " (", round(incidence_rate, 1), "%)")),
    hjust = -0.2,
    size = 3
  ) +
  scale_size_continuous(
    range = c(3, 8),
    name = "Number of\nSubjects"
  ) +
  labs(
    title = "Top 10 Most Frequent Treatment-Emergent Adverse Events",
    subtitle = "Incidence rates per 100 subjects with 95% Confidence Intervals",
    x = "Incidence Rate (% of Subjects)",
    y = "Adverse Event Term",
    caption = paste0("Total N = ", total_subjects, " subjects\nError bars represent 95% confidence intervals")
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, size = 10),
    axis.text.y = element_text(size = 9),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.x = element_blank(),
    legend.position = "right"
  ) +
  scale_x_continuous(
    limits = c(0, max(top10_aes$ci_upper) * 1.25),
    breaks = seq(0, ceiling(max(top10_aes$ci_upper)), by = 5)
  )

# Save Plot 2
cat("Saving Plot 2 to PNG...\n")
ggsave(
  "question_3_tlg/plot2_top10_aes.png",
  plot = plot2,
  width = 12,
  height = 8,
  dpi = 300
)
cat("Plot 2 saved successfully\n\n")

# Create summary statistics
cat("==========================================\n")
cat("Visualization Summary Statistics\n")
cat("==========================================\n\n")

cat("Plot 1 - Severity Distribution:\n")
cat("  Total unique subjects with AEs by severity:\n")
severity_totals <- adae_teae %>%
  distinct(USUBJID, AESEV) %>%
  group_by(AESEV) %>%
  summarise(n = n(), .groups = "drop")
print(severity_totals)
cat("\n")

cat("Plot 2 - Top 10 AEs:\n")
cat("  Incidence rate range:",
    round(min(top10_aes$incidence_rate), 1), "% to",
    round(max(top10_aes$incidence_rate), 1), "%\n")
cat("  Total subjects with any of top 10 AEs:",
    n_distinct(adae_teae %>%
                 filter(AETERM %in% top10_aes$AETERM) %>%
                 pull(USUBJID)), "\n\n")

cat("==========================================\n")
cat("Question 3B Completed Successfully!\n")
cat("End Time:", format(Sys.time()), "\n")
cat("Outputs saved:\n")
cat("  - question_3_tlg/plot1_ae_severity.png\n")
cat("  - question_3_tlg/plot2_top10_aes.png\n")
cat("==========================================\n")

# Stop logging
sink()

# Print success message to console
cat("\n✓ Question 3B completed successfully!\n")
cat("  - Plot 1: AE severity distribution created\n")
cat("  - Plot 2: Top 10 AEs with CI created\n")
cat("  - Outputs saved to: question_3_tlg/\n")
cat("  - Log saved to: question_3_tlg/question_3b_log.txt\n\n")
