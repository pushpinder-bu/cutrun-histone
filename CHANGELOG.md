# Changelog

All notable changes to this pipeline are recorded here.
Versions follow [semantic versioning](https://semver.org): MAJOR.MINOR.PATCH.

## [Unreleased]

## [0.3.0] - 2026-11-16

### Changed
- Processes moved from `main.nf` into `modules/local/*.nf`; `main.nf` now holds only the workflow.
- Resource labels renamed to `process_low` / `process_medium` / `process_high` and defined once in `conf/base.config`.
- SCC (SGE) settings moved to `conf/scc.config`; default parameters moved to `nextflow.config`.
- The local stub-testing profile is now called `local` (the name `test` is reserved for the upcoming test dataset).

### Added
- Automatic retry (once, with doubled time limit) when the scheduler kills a job.
- `PYTHONNOUSERSITE=1` for all tasks, so tools ignore Python packages installed in the user's home directory.
- Run reports (timeline, resource report, trace) in `<outdir>/pipeline_info/`.

## [0.2.0] - 2026-11-12

### Added
- RPGC-normalized bigWigs (deepTools `bamCoverage`).
- FastQC on raw reads.
- Per-sample QC: `samtools flagstat`, preseq library complexity, and a combined `QC_summary.tsv` (raw read pairs, mapping, duplication, final reads).
- MultiQC report (FastQC, bowtie2, sambamba markdup, flagstat, preseq).

### Changed
- bowtie2 now runs with `--reorder`, so identical input gives identical output.

## [0.1.0] - 2026-11-10

### Added
- Samplesheet input (`sample`, `cell_type`, `mark`, `fastq_1`, `fastq_2`).
- Alignment with bowtie2 (`--local`, paired-end) piped to samtools.
- Sorting and duplicate marking with sambamba; filtering to uniquely mapped, non-duplicate reads.
- SCC (SGE) profile and `-stub-run` support.
