# Citations

If you use this pipeline, please cite it (see the README) and the tools it runs.

## Pipeline tools

- **Nextflow**
  Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C. Nextflow enables reproducible computational workflows. *Nat Biotechnol.* 2017;35(4):316-319. doi:10.1038/nbt.3820

- **Bowtie 2**
  Langmead B, Salzberg SL. Fast gapped-read alignment with Bowtie 2. *Nat Methods.* 2012;9(4):357-359. doi:10.1038/nmeth.1923

- **SAMtools**
  Danecek P, Bonfield JK, Liddle J, et al. Twelve years of SAMtools and BCFtools. *GigaScience.* 2021;10(2):giab008. doi:10.1093/gigascience/giab008

- **Sambamba**
  Tarasov A, Vilella AJ, Cuppen E, Nijman IJ, Prins P. Sambamba: fast processing of NGS alignment formats. *Bioinformatics.* 2015;31(12):2032-2034. doi:10.1093/bioinformatics/btv098

- **deepTools**
  Ramírez F, Ryan DP, Grüning B, et al. deepTools2: a next generation web server for deep-sequencing data analysis. *Nucleic Acids Res.* 2016;44(W1):W160-W165. doi:10.1093/nar/gkw257

- **MACS2**
  Zhang Y, Liu T, Meyer CA, et al. Model-based Analysis of ChIP-Seq (MACS). *Genome Biol.* 2008;9(9):R137. doi:10.1186/gb-2008-9-9-r137

- **SEACR**
  Meers MP, Tenenbaum D, Henikoff S. Peak calling by Sparse Enrichment Analysis for CUT&RUN chromatin profiling. *Epigenetics Chromatin.* 2019;12(1):42. doi:10.1186/s13072-019-0287-4

- **BEDTools**
  Quinlan AR, Hall IM. BEDTools: a flexible suite of utilities for comparing genomic features. *Bioinformatics.* 2010;26(6):841-842. doi:10.1093/bioinformatics/btq033

- **FastQC**
  Andrews S. FastQC: a quality control tool for high throughput sequence data. 2010. https://www.bioinformatics.babraham.ac.uk/projects/fastqc/

- **preseq**
  Daley T, Smith AD. Predicting the molecular complexity of sequencing libraries. *Nat Methods.* 2013;10(4):325-327. doi:10.1038/nmeth.2375

- **MultiQC**
  Ewels P, Magnusson M, Lundin S, Käller M. MultiQC: summarize analysis results for multiple tools and samples in a single report. *Bioinformatics.* 2016;32(19):3047-3048. doi:10.1093/bioinformatics/btw354

## Test data

- nf-core test-datasets, `cutandrun` branch: GEO GSE145187 reads subsampled to 10,000 read pairs and an hg38 chromosome 20 bowtie2 index. https://github.com/nf-core/test-datasets/tree/cutandrun
