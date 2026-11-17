# Changelog

All notable changes to this pipeline are recorded here.
Versions follow [semantic versioning](https://semver.org): MAJOR.MINOR.PATCH.

## [Unreleased]

## [0.4.0] - 2026-11-16

### Added
- A pinned container for every process (BioContainers / Seqera community images, same tags as nf-core modules).
- `docker` and `singularity` profiles; combine with where to run, e.g. `-profile scc,singularity` or `-profile local,docker`.
- Singularity image cache in project space on the SCC.

### Changed
- Tool versions now come from containers instead of SCC modules: FastQC 0.13.0, bowtie2 2.5.5 + samtools 1.24, sambamba 1.0.1, samtools 1.25, deepTools 3.5.6, preseq 3.2.0, MultiQC 1.35.
- `QC_STATS` split into `SAMTOOLS_STATS` and `PRESEQ_LCEXTRAP` (one tool per container); preseq now reads BAM directly and retries once without the defect check.
- BAM indexing in `FILTER_BAM` uses `sambamba index` (same `.bai` output), so the step needs one tool.
- The `local` profile never requests more CPUs than the machine has; requires Nextflow >= 24.04.

### Removed
- SCC environment modules (`module` directives). Use tag `v0.3.0` to reproduce earlier module-based runs.

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
