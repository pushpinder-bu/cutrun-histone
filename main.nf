#!/usr/bin/env nextflow
// ---------------------------------------------------------------
// cutrun-histone: CUT&RUN histone-mark analysis
// Processes live in modules/local/; settings and resources in nextflow.config and conf/
// ---------------------------------------------------------------

include { UNTAR_INDEX } from './modules/local/untar_index'
include { FASTQC      } from './modules/local/fastqc'
include { ALIGN       } from './modules/local/align'
include { FILTER_BAM  } from './modules/local/filter_bam'
include { BAMCOVERAGE } from './modules/local/bamcoverage'
include { SAMTOOLS_STATS   } from './modules/local/samtools_stats'
include { PRESEQ_LCEXTRAP } from './modules/local/preseq_lcextrap'
include { PLOT_FINGERPRINT } from './modules/local/plot_fingerprint'
include { TSS_PROFILE      } from './modules/local/tss_profile'
include { MULTIQC     } from './modules/local/multiqc'

// Put one cell type's samples in a fixed order: control mark (IgG) first, then the other marks alphabetically.
// marks: list of marks; files: list of lists of files, each in the same order as marks
def orderByMark(cell, marks, files) {
    def idx = (0..<marks.size()).toList().sort { a, b ->
        (marks[a] == params.control_mark ? 0 : 1) <=> (marks[b] == params.control_mark ? 0 : 1) ?: marks[a] <=> marks[b]
    }
    return [cell, idx.collect { i -> marks[i] }] + files.collect { f -> idx.collect { i -> f[i] } }
}

// =================== WORKFLOW ===================

workflow {
    // read the samplesheet -> one item per sample: [meta, R1, R2]
    ch_reads = Channel
        .fromPath(params.input)
        .splitCsv(header: true)
        .map { row ->
            def meta = [id: row.sample, cell: row.cell_type, mark: row.mark]
            tuple(meta, file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true))
        }

    // bowtie2 index: either a .tar.gz (unpacked once) or the prefix of an existing index (e.g. /path/hg38)
    if (params.bowtie2_index.toString().endsWith('.tar.gz')) {
        UNTAR_INDEX(file(params.bowtie2_index, checkIfExists: true))
        ch_index = UNTAR_INDEX.out.index.collect()          // value channel: reused by every ALIGN task
    } else {
        ch_index = Channel.fromPath("${params.bowtie2_index}.*.bt2*", checkIfExists: true).collect()
    }

    // the same channel can feed several processes
    FASTQC(ch_reads)
    ALIGN(ch_reads, ch_index)

    FILTER_BAM(ALIGN.out.bam)
    BAMCOVERAGE(FILTER_BAM.out.filtered)

    // join: line up outputs from different steps by their shared meta (same sample)
    ch_for_qc = FILTER_BAM.out.markdup                 // [meta, markdup.bam, .bai]
        .join(FILTER_BAM.out.filtered)                 // + [filtered.bam, .bai]
        .join(ALIGN.out.log)                           // + [bowtie2.log]
    SAMTOOLS_STATS(ch_for_qc)
    PRESEQ_LCEXTRAP(FILTER_BAM.out.markdup)

    // collectFile: stack every sample's one-line summary into one table
    SAMTOOLS_STATS.out.summary
        .collectFile(name: 'QC_summary.tsv', keepHeader: true, skip: 1, sort: { it.name },   // rows ordered by sample name
                     storeDir: "${params.outdir}/qc")

    // ---- per cell type: gather each cell type's samples into one task ----
    // groupTuple: [cell, mark, file] items with the same cell -> [cell, [marks], [files]],
    // then orderByMark puts every group in the same order (IgG first, then marks alphabetically)
    ch_bams_by_cell = FILTER_BAM.out.filtered
        .map { meta, bam, bai -> tuple(meta.cell, meta.mark, bam, bai) }
        .groupTuple()
        .map { cell, marks, bams, bais -> orderByMark(cell, marks, [bams, bais]) }
    PLOT_FINGERPRINT(ch_bams_by_cell)

    ch_bw_by_cell = BAMCOVERAGE.out.bw
        .map { meta, bw -> tuple(meta.cell, meta.mark, bw) }
        .groupTuple()
        .map { cell, marks, bws -> orderByMark(cell, marks, [bws]) }
    TSS_PROFILE(ch_bw_by_cell, Channel.value(file(params.gene_annotation, checkIfExists: true)))

    // mix + collect: gather QC files from all samples and steps, then run MultiQC once
    ch_multiqc = FASTQC.out.reports.flatten()
        .mix(ALIGN.out.log.map { meta, log -> log })
        .mix(FILTER_BAM.out.log)
        .mix(SAMTOOLS_STATS.out.flagstat)
        .mix(PRESEQ_LCEXTRAP.out.lc_extrap)
        .mix(PLOT_FINGERPRINT.out.counts)
        .mix(PLOT_FINGERPRINT.out.metrics)
        .mix(TSS_PROFILE.out.profile_data)
        .collect()
    MULTIQC(ch_multiqc)
}
