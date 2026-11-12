# Changelog

All notable changes to this pipeline are recorded here.
Versions follow [semantic versioning](https://semver.org): MAJOR.MINOR.PATCH.

## [Unreleased]

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
