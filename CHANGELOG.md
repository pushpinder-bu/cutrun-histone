# Changelog

All notable changes to this pipeline are recorded here.
Versions follow [semantic versioning](https://semver.org): MAJOR.MINOR.PATCH.

## [Unreleased]

## [0.1.0] - 2026-11-10

### Added
- Samplesheet input (`sample`, `cell_type`, `mark`, `fastq_1`, `fastq_2`).
- Alignment with bowtie2 (`--local`, paired-end) piped to samtools.
- Sorting and duplicate marking with sambamba; filtering to uniquely mapped, non-duplicate reads.
- SCC (SGE) profile and `-stub-run` support.
