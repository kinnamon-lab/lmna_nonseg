# Overview
This Git repository contains the data files and programs necessary to reproduce
the analyses presented in the "Modeling the Impact of Non-*LMNA* Variants on
Disease Severity" section of:

>Cowan JR, Kinnamon DD, Morales A, Salyer L, Nickerson DA, Hershberger RE.
>Multigenic Disease and Bilineal Inheritance in Dilated Cardiomyopathy Is
>Illustrated in Nonsegregating LMNA Pedigrees. *Circ Genom Precis Med*. In
>press.

The head of this repository contains the final analysis results presented in
the paper. The Git log message for each commit leading to the current head 
describes the changes made to existing files and the provenance of any new
files. In cases where a script or program was used to produce new files, the
Git log will refer to a more detailed log file included in the commit that
documents the program run, input files, and their versions (commit SHA1) as
well as the results of running the script or program.

# Repository Map
## data/
This directory contains the original data file `lmna_nonseg_data.csv` as well
as derivative data files produced in later commits by running scripts in the
`pedigrees` and `analysis` directories.
## pedigrees/
This directory contains the script `draw_pedigrees.sh` that was used to prepare
the data file for Madeline 2.0, draw pedigress for each family, and commit the
results to this respository. The log from running this script is in
`draw_pedigrees.log`, and the resulting pedigrees are in SVG files indicating the
family letter. These pedigrees were used to ensure that the data files for analysis
correctly reproduced the pedigrees presented in Figures 1 - 5 of the paper. Note
that the age at echocardiogram used for analysis is presented on these pedigrees
whereas current or death ages and onset ages, which were not used for these analyses,
are presented on the pedigrees in the paper.
## analysis/
This directory contains the script `run_analysis.sh` that was used to produce the
data and control files for Mendel, run all analyses, and commit the results to this
repository. The log from running this script is in `analysis.log`. Each analysis
was defined by a particular control file named according to the convention
`[analysis name].ctrl`. Summary and full output for the analysis requested by this
control file is in the files `[analysis name]_summary.out` and `[analysis name].out`,
respectively. A description of each `[analysis name]` is given in the following table:

Analysis Name | Description
:------------- | :-----------
`mvc_any` | Main analysis presented in the paper. Descriptive statistics in Table 3 (except for untransformed age at echocardiogram) are from `mvc_any.out`, and results in Table 4 are from `mvc_any_summary.out`.
`mvc_any_no_grade` | Same as `mvc_any` without phenotypic grade as an outcome. This is alternative analysis (1) referred to in the "Results" section of the paper.
`mvc_count` | Same as `mvc_any` except that the effect of the *number* of non-*LMNA* variants rather than simple presence/absence was modeled. This is alternative analysis (2) referred to in the "Results" section of the paper.
`mvc_count_no_grade` | Same as `mvc_count` without phenotypic grade as an outcome.
`mvc_count_no_age_tx` | Same as `mvc_count` without standardization of the age variable. Descriptive statistics for untransformed age at echocardiogram in Table 3 are from `mvc_count_no_age_tx.out`.

# Dependencies
[Madeline 2.0](https://github.com/piratical/Madeline_2.0_PDE)
(built from commit 70dcd93b) was used for pedigree drawings, and
[Mendel 16.0](https://www.genetics.ucla.edu/software/mendel) was used for the
multivariate linear mixed model analysis.
