# Changelog

All notable changes to this pipeline are recorded here.
Versions follow [semantic versioning](https://semver.org): MAJOR.MINOR.PATCH.

## [Unreleased]

## [0.6.0] - 2026-11-18

### Added
- `PLOT_FINGERPRINT`: deepTools fingerprint plot per cell type (all marks + IgG), with quality metrics (Jensen-Shannon distance etc.) of each mark against that cell type's IgG.
- `TSS_PROFILE`: signal around transcription start sites per cell type: a profile plot for each window (`--profile_windows`, default 2 kb and 5 kb) and a heatmap of the largest window, k-means clustered on one mark (`--heatmap_cluster_mark`, default H3K27me3).
- Parameters `--gene_annotation` (GTF with transcript lines, or BED of transcripts; gzipped accepted), `--control_mark`, `--profile_windows`, `--heatmap_cluster_mark`, `--heatmap_kmeans`.
- Fingerprint and profile data in the MultiQC report.
- Samples of each cell type are always ordered the same way in plots: IgG first, then marks alphabetically.

## [0.5.0] - 2026-11-17

### Added
- `test` profile (`conf/test.config`) with a small public CUT&RUN dataset (nf-core test-datasets, GEO GSE145187, hg38 chr20): `nextflow run . -profile test,docker`.
- GitHub Actions CI (`.github/workflows/ci.yml`): a stub run, then the test data with Docker on the oldest supported and the latest Nextflow.
- `--bowtie2_index` accepts a `.tar.gz` of an index folder (new `UNTAR_INDEX` step) as well as an index prefix.
- `container` and `cpus` columns in the run trace.
- Singularity/Apptainer now uses pre-built Singularity images (as nf-core modules do) instead of converting Docker images; fixes `multiqc: command not found` under Singularity and skips the conversion step.

### Changed
- The bowtie2 index is now a tracked input of `ALIGN` (changing the index reruns alignment).
- FastQC reports are named by sample (`<sample>_R1/_R2`) instead of by FASTQ file name.
- Rows of `QC_summary.tsv` are always ordered by sample name.
- The test profile and the `local` profile never request more CPUs than the machine has.

### Fixed
- Compatibility with Nextflow 26.x strict syntax: run-report timestamp is now a parameter (`params.trace_report_suffix`) instead of a config variable, and `FILTER_BAM`'s per-sample `publishDir` is evaluated per task. Tested on Nextflow 24.10 and 26.10.
- CI uses `actions/checkout@v7` and `actions/upload-artifact@v7` (Node.js 24).

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
