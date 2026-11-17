# cutrun-histone

A Nextflow pipeline for paired-end CUT&RUN histone-mark data (e.g. H3K27me3, H3K4me3 with IgG controls), set up for the BU SCC cluster.

> **Version:** 0.4.0 (see [CHANGELOG](CHANGELOG.md)). **Status:** in development. Alignment, filtering, bigWigs and QC are implemented, each step in its own pinned container; the remaining steps are being added one at a time (see [Roadmap](#roadmap)).

## What it does

| Step | Tools | Status |
|---|---|---|
| Alignment to GRCh38 (`--local`, paired-end) | bowtie2, samtools | done |
| Sort, mark duplicates, keep uniquely mapped non-duplicate reads | sambamba, samtools | done |
| RPGC-normalized bigWigs | deepTools `bamCoverage` | done |
| QC: FastQC, duplication, library complexity, MultiQC | FastQC, samtools, preseq, MultiQC | done |
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

## Software: containers

Every step runs in its own container with a pinned tool version, so results do not depend on what is installed on the machine. Images are the BioContainers / Seqera community builds also used by nf-core modules.

| Step | Tool (version) |
|---|---|
| FASTQC | FastQC 0.13.0 |
| ALIGN | bowtie2 2.5.5, samtools 1.24 |
| FILTER_BAM | sambamba 1.0.1 |
| BAMCOVERAGE | deepTools 3.5.6 |
| SAMTOOLS_STATS | samtools 1.25 |
| PRESEQ_LCEXTRAP | preseq 3.2.0 |
| MULTIQC | MultiQC 1.35 |

Choose **where** to run and **how** software is provided with two profiles:

| | Docker | Singularity / Apptainer |
|---|---|---|
| Laptop / workstation / CI | `-profile local,docker` | `-profile local,singularity` |
| BU SCC (SGE) | – | `-profile scc,singularity` |

## Running on the SCC

The `scc` profile uses Nextflow's **SGE executor**: every step of every sample is submitted as its own SGE job (project `crem-bioinfo`, `-pe omp <cpus>`, `mem_per_core=8G`), with up to 50 jobs queued at once. Nextflow tracks the jobs, starts each step when its inputs are ready, and retries a step once if the scheduler kills it. Container images are downloaded once into `/restricted/projectnb/crem-bioinfo/$USER/singularity_cache` and reused.

```bash
module load nextflow

# 1. Check the wiring without running anything (seconds, runs locally, no containers needed)
nextflow run main.nf -profile local -stub-run --input samplesheet.csv --outdir stub_test

# 2. Real run: each step is dispatched to SGE and runs in its container
nextflow run main.nf -profile scc,singularity --input samplesheet.csv --outdir results

# 3. After changing inputs or code, rerun only what changed
nextflow run main.nf -profile scc,singularity --input samplesheet.csv --outdir results -resume
```

The Nextflow controller itself needs to keep running for the whole run. Either start it inside `tmux`/`screen` on a login node, or submit it as a small job with [`run_nextflow.qsub`](run_nextflow.qsub); it then submits the pipeline steps as separate jobs.

### Tip: keep stub runs in their own folder

`-resume` reuses results from the most recent run started in the same folder. Run `-stub-run` checks from a separate folder (e.g. `mkdir stub && cd stub`) so they never become the "most recent run" of a real analysis. To resume a specific earlier run, give its name from `nextflow log`: `-resume <run_name>`.

### Parameters

| parameter | default |
|---|---|
| `--input` | `samplesheet.csv` |
| `--outdir` | `results` |
| `--bowtie2_index` | GRCh38 bowtie2 index on `crem-bioinfo` (chr-prefixed); built with bowtie2, compatible with 2.5.x |
| `--effective_genome_size` | `2913022398` (GRCh38) |
| `--bw_bin_size` | `10` |
| `--extend_reads` | `200` |

## Reproducibility

bowtie2 runs with `--reorder`, so identical inputs give identical outputs.

- **Repeat runs:** two independent runs from scratch on a 43.5M read-pair H3K27me3 library produced the same final filtered BAM, read for read (54,219,337 reads).
- **Modules vs containers:** the containerised pipeline (v0.4.0) and the earlier SCC-module version (v0.3.0) gave identical read counts at every stage (raw, mapped, duplicates, final) for H3K27me3, H3K4me3 and IgG libraries, and bigWigs with Pearson correlation 1.0000, despite newer bowtie2, samtools and sambamba versions.

## Repository layout

```
main.nf                  # workflow: reads the samplesheet and connects the steps
modules/local/*.nf       # one file per step (process)
nextflow.config          # metadata, default parameters, profiles
conf/base.config         # CPUs and time limits per label (process_low / medium / high)
conf/scc.config          # BU SCC: SGE executor and Singularity image cache
assets/                  # example samplesheet
```

## Outputs

```
results/
├── alignment/<sample>/
│   ├── <sample>.sorted.markdup.bam(.bai)            # duplicates marked, not removed
│   └── <sample>.sorted.markdup.filtered.bam(.bai)   # final BAM used downstream
├── bigwig/<sample>.bw                               # RPGC-normalized coverage
├── qc/
│   ├── QC_summary.tsv                               # one row per sample
│   ├── fastqc/  flagstat/  preseq/
│   └── multiqc/multiqc_report.html
└── pipeline_info/                                   # timeline, resource report and trace of each run
```

Intermediate files stay in `work/`. Once a run is complete and checked, `work/` can be deleted to save space (but then `-resume` will start from scratch).

## Running a specific version

Each release is tagged on GitHub (e.g. `v0.4.0`). To run exactly that version, so results can be reproduced later:

```bash
nextflow run pushpinder-bu/cutrun-histone -r v0.4.0 -profile scc,singularity --input samplesheet.csv --outdir results
```

Nextflow downloads the tagged version from GitHub; no manual copy is needed.

## Roadmap

1. Alignment and filtering ✅
2. bigWigs and QC ✅
3. Modular layout (`modules/local`, `conf/`) ✅
4. Containers for every step (Docker and Singularity profiles) ✅
5. Test profile on a small public dataset, with continuous integration on GitHub Actions
6. Per-cell-type fingerprint plots and TSS profiles
7. Peak calling with matched IgG: MACS2 (narrow or broad by mark) and SEACR
8. Overlap tables and UpSet plots across cell types
9. Merging re-sequenced FASTQs (multiple rows per sample)

## Citation

If you use this pipeline, please cite:

> Pushpinder Bawa. cutrun-histone: a Nextflow pipeline for CUT&RUN histone-mark analysis (version 0.4.0). https://github.com/pushpinder-bu/cutrun-histone

and the tools it uses, listed in [CITATIONS.md](CITATIONS.md).

## License

Released under the [MIT License](LICENSE).

## Author

Pushpinder Bawa
