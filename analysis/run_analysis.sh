#!/bin/bash

# NOTE: This script should be called from the top level of the repository.

SCRIPT=analysis/run_analysis.sh
if [ "$SCRIPT" != "${0}" ]; then
    echo "This script should be called from the top level of the repo"
    exit 1
fi

# Set and print module environment
echo 'Loading additional modules...'
module purge
module load git Mendel
module list

# Verify repo working directory and index are pristine so that current HEAD
# is completely capturing state
GIT_SHA1=$(git rev-parse HEAD)
if [ -n "$(git status --porcelain)" ]; then
    echo "Working directory or index is dirty"
    exit 1
fi

# Redirect relevant output to log file in repository that can be committed
LOGFILE=analysis/analysis.log
echo "Redirecting job log to $LOGFILE"
exec 3>&1 4>&2 1>$LOGFILE 2>&1

# Print analysis start time
echo "Analysis started $(date --rfc-3339=seconds)"

# Output job script information
INPUT_DATA=data/lmna_nonseg_data.csv
MENDEL_DEF=data/mendel_data.def
MENDEL_PED=data/mendel_data.ped
echo '=== JOB INFORMATION ==='
echo "Current Commit: $GIT_SHA1"
echo "Job Script:     --/$SCRIPT"
echo "Input data:     --/$INPUT_DATA"
echo 'Output:         '
echo "                --/$MENDEL_PED"
echo "                --/$MENDEL_DEF"
echo '                --/analysis/*.{ctrl,out}'
echo "Loaded Modules: $LOADEDMODULES"
echo -e '===\n'

# Create input data files for Mendel
echo "Creating $MENDEL_DEF..."
cat <<EOF > $MENDEL_DEF
proband,      factor,   2
    0
    1
vital_status, factor,   2
    Alive
    Deceased
female,       variable, 2 ! Numeric to allow reference parameterization
    lower, 0
    upper, 1
n_lmna_vars,  variable, 2 ! Numeric to allow reference parameterization
    lower, 0
    upper, 1
n_oth_vars,   variable, 2
    lower, 0
    upper, 4
grade,        variable, 2
    lower, 0
    upper, 4
age_echo_yrs, variable, 2
    lower, 0
    upper, 90
lvedd_z,      variable
lvef,         variable, 2
    lower, 1
    upper, 100
EOF

echo "Creating $MENDEL_PED..."
awk '
BEGIN {
    FS = OFS = ","
}
FNR == 1 {
  for (i = 1; i <= NF; i++) {
    colidx[$i] = i
  }
}
FNR > 1 {
  print $colidx["family_ID"],
    $colidx["individual_ID"],
    $colidx["paternal_ID"] == 0 ? "" : $colidx["paternal_ID"],
    $colidx["maternal_ID"] == 0 ? "" : $colidx["maternal_ID"],
    $colidx["sex"],
    $colidx["proband"],
    $colidx["vital_status"] == "n/a" ? "" : $colidx["vital_status"],
    $colidx["sex"] - 1,
    $colidx["n_lmna_vars"] == "n/a" ? "" : $colidx["n_lmna_vars"],
    $colidx["n_oth_vars"] == "n/a" ? "" : $colidx["n_oth_vars"],
    $colidx["grade"]  == "n/a" ? "" : $colidx["grade"],
    $colidx["age_echo_yrs"]  == "n/a" ? "" : $colidx["age_echo_yrs"],
    $colidx["lvedd_z"]  == "n/a" ? "" : $colidx["lvedd_z"],
    $colidx["lvef"]  == "n/a" ? "" : $colidx["lvef"]
}
' $INPUT_DATA > $MENDEL_PED

echo 'Creating control files...'
cat <<EOF > base.ctrl
! Control file for multivariate variance components analysis
DEFINITION_FILE = data/mendel_data.def
PEDIGREE_FILE = data/mendel_data.ped
INPUT_FORMAT = No_Twins
ECHO = yes
ANALYSIS_OPTION = Variance_Components
PROBAND_FACTOR = proband
PROBAND = 1
TRANSFORM = Standardize :: age_echo_yrs
QUANTITATIVE_TRAIT = lvedd_z
PREDICTOR = female :: lvedd_z
PREDICTOR = age_echo_yrs :: lvedd_z
PREDICTOR = n_lmna_vars :: lvedd_z
PREDICTOR = n_oth_vars :: lvedd_z
QUANTITATIVE_TRAIT = lvef
PREDICTOR = female :: lvef
PREDICTOR = age_echo_yrs :: lvef
PREDICTOR = n_lmna_vars :: lvef
PREDICTOR = n_oth_vars :: lvef
QUANTITATIVE_TRAIT = grade
PREDICTOR = female :: grade
PREDICTOR = age_echo_yrs :: grade
PREDICTOR = n_lmna_vars :: grade
PREDICTOR = n_oth_vars :: grade
COVARIANCE_CLASS = Additive
COVARIANCE_CLASS = Environmental
OUTLIERS = True
EOF

cp base.ctrl analysis/mvc_any.ctrl
cat <<EOF >> analysis/mvc_any.ctrl
TRANSFORM = Above_Threshold :: n_oth_vars
INDICATOR_THRESHOLD = 1
OUTPUT_FILE = analysis/mvc_any.out
SUMMARY_FILE = analysis/mvc_any_summary.out
EOF

cp base.ctrl analysis/mvc_count.ctrl
cat <<EOF >> analysis/mvc_count.ctrl
OUTPUT_FILE = analysis/mvc_count.out
SUMMARY_FILE = analysis/mvc_count_summary.out
EOF

sed -n '/grade/! p' analysis/mvc_any.ctrl | \
    sed 's/mvc_any/\0_no_grade/' > analysis/mvc_any_no_grade.ctrl
sed -n '/grade/! p' analysis/mvc_count.ctrl | \
    sed 's/mvc_count/\0_no_grade/' > analysis/mvc_count_no_grade.ctrl
sed -n '/TRANSFORM/! p' analysis/mvc_count.ctrl | \
    sed 's/mvc_count/\0_no_age_tx/' > analysis/mvc_count_no_age_tx.ctrl

rm base.ctrl

# Run Mendel on all available control files
for CTRL_FILE in $(find analysis -name '*.ctrl'); do
    echo "Running Mendel on $CTRL_FILE..."
    mendel -c $CTRL_FILE
done

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
Produced multivariate variance components analysis

All results files were stored in Git. Detailed information
is available in $LOGFILE in this commit.
EOF
if ! git commit -F commit_msg; then
    echo 'Git commit failed'
    exit 1
fi
rm commit_msg
