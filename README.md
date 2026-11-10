# cutrun-histone

A Nextflow pipeline for paired-end CUT&RUN histone-mark data (e.g. H3K27me3, H3K4me3 with IgG controls), set up for the BU SCC cluster.

> **Version:** 0.1.0 (see [CHANGELOG](CHANGELOG.md)). **Status:** in development. Alignment and filtering are implemented; the remaining steps are being added one at a time (see [Roadmap](#roadmap)).

## What it does

| Step | Tools | Status |
|---|---|---|
| Alignment to GRCh38 (`--local`, paired-end) | bowtie2, samtools | done |
| Sort, mark duplicates, keep uniquely mapped non-duplicate reads | sambamba, samtools | done |
| RPGC-normalized bigWigs | deepTools `bamCoverage` | planned |
| QC: FastQC, duplication, library complexity, MultiQC | FastQC, samtools, preseq, MultiQC | planned |
| Fingerprint plots and TSS profiles/heatmaps per cell type | deepTools | planned |
| Peak calling against each cell type's IgG (narrow / broad) | MACS2 | planned |
| Peak overlap tables and UpSet plots across cell types | bedtools, Python | planned |
| Merging re-sequenced FASTQs into an existing sample | - | planned |

## Samplesheet

A CSV with one row per FASTQ pair:

| column | meaning |
|---|---|
| `sample` | sample name used for all output files |
| `cell_type` | groups samples for per-cell-type plots, and matches each mark to its IgG |
| `mark` | histone mark, or `IgG` for the control |
| `fastq_1`, `fastq_2` | full paths to R1 and R2 |

See [`assets/samplesheet_example.csv`](assets/samplesheet_example.csv).

## Running on the SCC

```bash
module load nextflow

# 1. Check the wiring without running anything (seconds)
nextflow run main.nf -profile scc -stub-run --input samplesheet.csv --outdir stub_test

# 2. Real run (inside tmux/screen, or submit run_nextflow.qsub)
nextflow run main.nf -profile scc --input samplesheet.csv --outdir results

# 3. After changing inputs or code, rerun only what changed
nextflow run main.nf -profile scc --input samplesheet.csv --outdir results -resume
```

Each step is submitted as its own SGE job (project `crem-bioinfo`, `-pe omp`, `mem_per_core=8G`); resources and modules are set in `nextflow.config`.

### Parameters

| parameter | default |
|---|---|
| `--input` | `samplesheet.csv` |
| `--outdir` | `results` |
| `--bowtie2_index` | GRCh38 bowtie2 index on `crem-bioinfo` (chr-prefixed) |

## Outputs

```
results/
└── alignment/<sample>/
    ├── <sample>.sorted.markdup.bam(.bai)            # duplicates marked, not removed
    └── <sample>.sorted.markdup.filtered.bam(.bai)   # final BAM used downstream
```

Intermediate files stay in `work/`. Once a run is complete and checked, `work/` can be deleted to save space (but then `-resume` will start from scratch).

## Running a specific version

Each release is tagged on GitHub (e.g. `v0.1.0`). To run exactly that version, so results can be reproduced later:

```bash
nextflow run pushpinder-bu/cutrun-histone -r v0.1.0 -profile scc --input samplesheet.csv --outdir results
```

Nextflow downloads the tagged version from GitHub; no manual copy is needed.

## Roadmap

1. Alignment and filtering ✅
2. bigWigs and QC
3. Per-cell-type fingerprint plots and TSS profiles
4. MACS2 peak calling with matched IgG
5. Overlap tables and UpSet plots
6. Merging re-sequenced FASTQs (multiple rows per sample)

## Citation

If you use this pipeline, please cite:

> Pushpinder Bawa. cutrun-histone: a Nextflow pipeline for CUT&RUN histone-mark analysis (version 0.1.0). https://github.com/pushpinder-bu/cutrun-histone

and the tools it uses, listed in [CITATIONS.md](CITATIONS.md).

## License

Released under the [MIT License](LICENSE).

## Author

Pushpinder Bawa
