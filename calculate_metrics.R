library(slider)
library(ggpubr)
library(agricolae)


# Users will need to adjust for their own file directory.
source("C:/Users/gage1/Box/Scripts/R scripts/functions/functions.R")



# For testing, use "test".
# Request the user to input the file name for analysis.
file <- ""
while (file == "") {
  file <- paste0(
    readline(
      "Please input the Excel file name without .xlsx extension: "
    ),
    ".xlsx"
  )
  if (!file.exists(file)) {
    print(paste(file, "does not exist. Please enter a valid file name."))
    file <- ""
  }
}

# Get the real-time data from the BMG export file.
df <- get_real(file, ordered=FALSE)

# Ask the user which real-time data set they want to use.
df_id <- as.integer(
  readline(
    paste(
      "There are",
      length(df),
      "real-time data sets. Please enter a number in that range: "
      )
    )
  )

# Select the real-time data set that the user signified.
df <- df[[df_id]]

# Export the tables in the first sheet of the file.
dic <- organize_tables(file)
column_names <- c("Time")
for (i in t(dic[["Sample IDs"]])) {
  for (j in i) {
    if (!is.na(j)) {
      column_names <- cbind(column_names, j)
    }
  }
}
# Apply the column names.
colnames(df) <- column_names

################################################################################

# Calculate the normalized real-time data.
df_norm <- normalize_RFU(df)

# Define the number of hours that the rxn ran for.
hours <- as.numeric(colnames(df_norm)[ncol(df_norm)])

# Initialized the dataframe with the calculated metrics.
df_analyzed <- data.frame(`Sample_ID` = df_norm$`Sample ID`) %>%
  mutate(
    # Maxpoint Ratio
    MPR = calculate_MPR(df_norm, start_col=3, data_is_norm=TRUE),
    # Max Slope
    MS  = calculate_MS(df_norm, start_col=3),
    # Time to Threshold
    TtT = calculate_TtT(df_norm, threshold=2, start_col=3)
  ) %>%
  # Rate of Amyloid Formation
  mutate(RAF = ifelse(is.na(TtT), 0, 1 / (3600 * TtT)))

################################################################################

# Order the data frame based on Sample_ID.
df_analyzed <- df_analyzed[order(df_analyzed$Sample_ID),]

# Reorganize the columns of df_analyzed.
df_analyzed <- data.frame(Sample_ID = df_analyzed$Sample_ID,
                          MPR = df_analyzed$MPR,
                          RAF = df_analyzed$RAF,
                          MS  = df_analyzed$MS,
                          TtT = df_analyzed$TtT)

# Create a summary data frame.
summary <- df_analyzed %>%
  group_by(Sample_ID) %>%
  summarise(mean_TtT   = mean(TtT), 
            mean_RAF   = mean(RAF),
            mean_MPR   = mean(MPR),
            mean_MS    = mean(MS))

################################################################################

<<<<<<< HEAD
metrics <- c("MPR", "MS")
for (metric in metrics) {
  
  # Create a dataframe of the individual comparisons.
  comps <- LSD.test( # Perform the post-hoc multiple comparisons test.
    # Create the statistical model using ANOVA.
    aov(as.formula(paste0(metric, " ~ ", "`", "Sample_ID", "`")), 
        data = df_analyzed),
    "Sample_ID",  p.adj = "none", group = F)[["comparison"]]
  
  # Initialize columns which will hold unique IDs for each sample compared.
  comps <- cbind(comps, rownames(comps) %>%
                   strsplit(" - ") %>%
                   as.data.frame() %>%
                   t() %>%
                   as.data.frame()) %>%
    
    # Remove all comparisons that are not against "N_1".
    subset(V1 == "N" | V2 == "N") %>%
    rename("{metric}_pvalue" := pvalue,
           "{metric}_significance" := signif.)
  
  assign(names(comps[2]), comps[2])
  assign(names(comps[3]), comps[3])
}


=======
# Calculate the statistical comparisons for MPR.
# ANOVA
model <- aov(MPR ~ Sample_ID, data=df_analyzed)

# Fisher's LSD test
stats <- LSD.test(model, "Sample_ID", p.adj = "bonferroni")
stats <- stats$groups[order(row.names(stats$groups)),]

# Define the negative control group.
neg_group <- stats["N", "groups"]

# Apply the statistical test to the summary data frame.
summary$MPR_Result <- c(ifelse(stats$groups == neg_group, "ns", "*"))


# Perform the same statistical comparisons for Max Slope.
model <- aov(MS ~ Sample_ID, data=df_analyzed)
stats <- LSD.test(model, "Sample_ID")

stats <- stats$groups[order(row.names(stats$groups)),]
neg_group <- stats["N", "groups"]

summary$MS_Result <- c(ifelse(stats$groups == neg_group, "ns", "*"))
>>>>>>> e35b6d582f0b715e928cee84dac15246e4f97dab

################################################################################

# Initialize the workbook for Excel.
wb <- createWorkbook()

# Add the sheets.
addWorksheet(wb, "Total")
addWorksheet(wb, "Summary")

# Write the "summary" df to the "Summary" sheet.
writeData(wb, "Total", df_analyzed)
writeData(wb, "Summary", summary)

# Save the Excel file.
saveWorkbook(wb, "output.xlsx", overwrite = TRUE)

################################################################################

# Plot the summary metrics
df_analyzed_melted <- reshape2::melt(df_analyzed, id.vars = "Sample_ID")
p <- ggplot(df_analyzed_melted, aes(Sample_ID, value, fill=Sample_ID)) +
  scale_fill_discrete() +
  geom_boxplot() +
  # stat_compare_means() +
  facet_wrap(vars(variable),
             scales = "free",
             labeller = as_labeller(c(MPR = "MPR (Max RFU / Initial RFU)",
                                      RAF = "RAF (1/s)",
                                      MS = "Max Slope (RFU/s)",
                                      TtT = "Time to Threshold (h)")),
             strip.position = "left") +
  ylim(0, NA) +
  xlab(NULL) +
  ylab(NULL) +
  theme(axis.line = element_line(colour = "black"),
        axis.text.x = element_text(angle = 45, hjust = 1),
        panel.background = element_blank(),
        panel.grid = element_line(colour = "lightgrey"),
        panel.border = element_rect(colour = "black", fill=NA, size=1),
        legend.position = "none",
        strip.background = element_blank(),
        strip.placement = "outside")
p

ggsave("Summary.png", p, width = 3600, height = 2400, units = "px")
