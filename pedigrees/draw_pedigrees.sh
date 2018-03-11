#!/bin/bash

# NOTE: This script should be called from the top level of the repository.

SCRIPT=pedigrees/draw_pedigrees.sh
if [ "$SCRIPT" != "${0}" ]; then
    echo "This script should be called from the top level of the repo"
    exit 1
fi

# Set and print module environment
echo 'Loading additional modules...'
module purge
module load git Madeline
module list

# Verify repo working directory and index are pristine so that current HEAD
# is completely capturing state
GIT_SHA1=$(git rev-parse HEAD)
if [ -n "$(git status --porcelain)" ]; then
    echo "Working directory or index is dirty"
    exit 1
fi

# Redirect relevant output to log file in repository that can be committed
LOGFILE=pedigrees/draw_pedigrees.log
echo "Redirecting job log to $LOGFILE"
exec 3>&1 4>&2 1>$LOGFILE 2>&1

# Print analysis start time
echo "Analysis started $(date --rfc-3339=seconds)"

# Output job script information
INPUT_DATA=data/lmna_nonseg_data.csv
MADELINE_DATA=data/madeline_data.dat
echo '=== JOB INFORMATION ==='
echo "Current Commit: $GIT_SHA1"
echo "Job Script:     --/$SCRIPT"
echo "Input data:     --/$INPUT_DATA"
echo 'Output:         '
echo "                --/$MADELINE_DATA"
echo '                --/pedigrees/*.svg'
echo "Loaded Modules: $LOADEDMODULES"
echo -e '===\n'

# Create input data file for Madeline
echo "Creating $MADELINE_DATA..."
awk '
BEGIN {
  FS = ","
  OFS = "\t"
}
FNR == 1 {
  for (i = 1; i <= NF; i++) {
    colidx[$i] = i
  }
  print "FamilyID", "IndividualID", "Gender", "Father", "Mother", "Affected",
      "Proband", "Deceased", "n_lmna_vars", "n_oth_vars", "age_echo_yrs",
      "lvedd_z", "lvef"
}
FNR > 1 {

  if ($colidx["sex"] == 1) sex = "M"
  else if ($colidx["sex"] == 2) sex = "F"
  else sex = "."

  if ($colidx["vital_status"] == "Deceased") dead = "Y"
  else if ($colidx["vital_status"] == "Alive") dead = "N"
  else dead = "."

  if ($colidx["proband"] == 1) proband = "Y"
  else if ($colidx["proband"] == 0) proband = "N"
  else proband = "."

  print $colidx["family_ID"],
    $colidx["individual_ID"],
    sex,
    $colidx["paternal_ID"] == 0 ? "." : $colidx["paternal_ID"],
    $colidx["maternal_ID"] == 0 ? "." : $colidx["maternal_ID"],
    $colidx["grade"] == "n/a" ? "." : $colidx["grade"],
    proband,
    dead,
    $colidx["n_lmna_vars"] == "n/a" ? "." : $colidx["n_lmna_vars"],
    $colidx["n_oth_vars"] == "n/a" ? "." : $colidx["n_oth_vars"],
    $colidx["age_echo_yrs"]  == "n/a" ? "." : $colidx["age_echo_yrs"],
    $colidx["lvedd_z"]  == "n/a" ? "." : $colidx["lvedd_z"],
    $colidx["lvef"]  == "n/a" ? "." : $colidx["lvef"]
}
' $INPUT_DATA > $MADELINE_DATA

# Run Madeline
madeline2 -L "IndividualID n_lmna_vars n_oth_vars age_echo_yrs lvedd_z lvef" \
    -o pedigrees/family $MADELINE_DATA

# Print analysis completion time
echo "Analysis completed successfully $(date --rfc-3339=seconds)"

# Close log file and redirect output to terminal
exec 1>&3 2>&4
echo 'Returned output to terminal'

# Add analysis results to Git
if ! git add .; then
    echo 'Adding analysis results to Git failed'
    exit 1
fi

# Commit files in Git index
echo 'Committing files in Git index...'
cat <<EOF > commit_msg
Produced pedigrees for families used in analysis

All results files were stored in Git. Detailed information
is available in $LOGFILE in this commit.
EOF
if ! git commit -F commit_msg; then
    echo 'Git commit failed'
    exit 1
fi
rm commit_msg
