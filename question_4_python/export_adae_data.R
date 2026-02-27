################################################################################
# Export ADAE Data for Python Question 4
#
# This script exports the ADAE dataset from pharmaverseadam to CSV format
# for use in the Python GenAI Clinical Data Assistant question
################################################################################

# Load required library
library(pharmaverseadam)

# Load ADAE dataset
cat("Loading ADAE dataset from pharmaverseadam package...\n")
adae <- pharmaverseadam::adae

cat("Dataset loaded:\n")
cat("  - Records:", nrow(adae), "\n")
cat("  - Subjects:", length(unique(adae$USUBJID)), "\n")
cat("  - Variables:", ncol(adae), "\n\n")

# Display structure
cat("Dataset structure:\n")
str(adae)
cat("\n")

# Display key variables
cat("Key variables summary:\n")
cat("  - AESEV values:", paste(unique(adae$AESEV), collapse=", "), "\n")
cat("  - ACTARM values:", paste(unique(adae$ACTARM), collapse=", "), "\n")
cat("  - Number of unique AETERMs:", length(unique(adae$AETERM)), "\n")
cat("  - Number of unique AESOCs:", length(unique(adae$AESOC)), "\n\n")

# Save to CSV
output_file <- "question_4_python/adae.csv"
cat("Exporting to CSV:", output_file, "\n")
write.csv(adae, output_file, row.names = FALSE)

cat("\n✓ Export completed successfully!\n")
cat("  File saved to:", output_file, "\n")
cat("  File size:", round(file.size(output_file) / 1024, 2), "KB\n\n")
