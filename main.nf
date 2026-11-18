#!/usr/bin/env nextflow
// ---------------------------------------------------------------
// cutrun-histone: CUT&RUN histone-mark analysis
// Processes live in modules/local/; settings and resources in nextflow.config and conf/
// ---------------------------------------------------------------

include { UNTAR_INDEX } from './modules/local/untar_index'
include { MERGE_FASTQ } from './modules/local/merge_fastq'
include { FASTQC      } from './modules/local/fastqc'
include { ALIGN       } from './modules/local/align'
include { FILTER_BAM  } from './modules/local/filter_bam'
include { BAMCOVERAGE } from './modules/local/bamcoverage'
include { SAMTOOLS_STATS   } from './modules/local/samtools_stats'
include { PRESEQ_LCEXTRAP } from './modules/local/preseq_lcextrap'
include { PLOT_FINGERPRINT } from './modules/local/plot_fingerprint'
include { TSS_PROFILE      } from './modules/local/tss_profile'
include { FRAGMENTS       } from './modules/local/fragments'
include { MACS2_CALLPEAK  } from './modules/local/macs2_callpeak'
include { SEACR_CALLPEAK  } from './modules/local/seacr_callpeak'
include { PEAK_QC         } from './modules/local/peak_qc'
include { PROMOTERS       } from './modules/local/promoters'
include { PEAK_OVERLAP    } from './modules/local/peak_overlap'
include { UPSET_PLOT      } from './modules/local/upset_plot'
include { MULTIQC     } from './modules/local/multiqc'

// Put one cell type's samples in a fixed order: control mark (IgG) first, then the other marks alphabetically.
// marks: list of marks; files: list of lists of files, each in the same order as marks
def orderByMark(cell, marks, files) {
    def idx = (0..<marks.size()).toList().sort { a, b ->
        (marks[a] == params.control_mark ? 0 : 1) <=> (marks[b] == params.control_mark ? 0 : 1) ?: marks[a] <=> marks[b]
    }
    return [cell, idx.collect { i -> marks[i] }] + files.collect { f -> idx.collect { i -> f[i] } }
}

// True for control samples (mark == --control_mark, default IgG)
def isControl(meta) {
    return meta.mark == params.control_mark
}

// =================== WORKFLOW ===================

workflow {
    // ---- read the samplesheet ----
    // one row per FASTQ pair; a sample sequenced in several runs has several rows with the same 'sample'
    ch_rows = Channel
        .fromPath(params.input)
        .splitCsv(header: true)
        .map { row ->
            ['sample', 'cell_type', 'mark', 'fastq_1', 'fastq_2'].each { col ->
                if (!row[col]) error("Samplesheet: column '${col}' is missing or empty in row ${row}")
            }
            tuple(row.sample, [id: row.sample, cell: row.cell_type, mark: row.mark],
                  file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true))
        }
        .groupTuple()                                         // [sample, [metas], [R1s], [R2s]]
        .map { id, metas, r1s, r2s ->
            if (metas.unique().size() > 1) error("Samplesheet: sample '${id}' has rows with different cell_type or mark")
            tuple(metas[0], r1s, r2s)
        }
        // branch: samples with one FASTQ pair go straight on; samples with several are merged first
        .branch { meta, r1s, r2s ->
            single:   r1s.size() == 1
            multiple: true
        }
    MERGE_FASTQ(ch_rows.multiple)
    ch_reads = ch_rows.single
        .map { meta, r1s, r2s -> tuple(meta, r1s[0], r2s[0]) }
        .mix(MERGE_FASTQ.out.reads)

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

    // ---- peak calling: each mark against the IgG of the same cell type ----
    FRAGMENTS(FILTER_BAM.out.filtered)
    ch_sizes = FRAGMENTS.out.sizes.first()                // chromosome sizes (same for every sample)

    ch_ctrl_bam  = FILTER_BAM.out.filtered.filter { meta, bam, bai -> isControl(meta) }.map { meta, bam, bai -> tuple(meta.cell, bam, bai) }
    ch_ctrl_frag = FRAGMENTS.out.fragments.filter { meta, f -> isControl(meta) }.map { meta, f -> tuple(meta.cell, f) }

    // combine(by: 0): pair every mark with the control that has the same cell type
    ch_macs2_in = FILTER_BAM.out.filtered
        .filter { meta, bam, bai -> !isControl(meta) }
        .map { meta, bam, bai -> tuple(meta.cell, meta, bam, bai) }
        .combine(ch_ctrl_bam, by: 0)
        .map { cell, meta, bam, bai, cbam, cbai -> tuple(meta, bam, bai, cbam, cbai) }
    MACS2_CALLPEAK(ch_macs2_in)

    ch_seacr_in = FRAGMENTS.out.fragments
        .filter { meta, f -> !isControl(meta) }
        .map { meta, f -> tuple(meta.cell, meta, f) }
        .combine(ch_ctrl_frag, by: 0)
        .map { cell, meta, f, cf -> tuple(meta, f, cf) }
    SEACR_CALLPEAK(ch_seacr_in, ch_sizes)

    ch_blacklist = Channel.value(file(params.blacklist ?: "${projectDir}/assets/NO_FILE", checkIfExists: true))
    PEAK_QC(MACS2_CALLPEAK.out.peaks.join(SEACR_CALLPEAK.out.peaks).join(FRAGMENTS.out.fragments), ch_blacklist)
    PEAK_QC.out.summary
        .collectFile(name: 'peak_summary.tsv', keepHeader: true, skip: 1, sort: { it.name },
                     storeDir: "${params.outdir}/peaks")

    // ---- overlaps across cell types, per mark (MACS2 peaks, blacklist removed) ----
    PROMOTERS(file(params.gene_annotation, checkIfExists: true))
    ch_by_mark = PEAK_QC.out.macs2
        .map { meta, bed -> tuple(meta.mark, meta.cell, bed) }
        .groupTuple()
        .map { mark, cells, beds ->                       // order cell types alphabetically
            def idx = (0..<cells.size()).toList().sort { a, b -> cells[a] <=> cells[b] }
            tuple(mark, idx.collect { i -> cells[i] }, idx.collect { i -> beds[i] })
        }
    PEAK_OVERLAP(ch_by_mark, PROMOTERS.out.bed, ch_sizes)
    UPSET_PLOT(PEAK_OVERLAP.out.matrices, Channel.value(file("${projectDir}/bin/upset_plot.py", checkIfExists: true)))

    // mix + collect: gather QC files from all samples and steps, then run MultiQC once
    ch_multiqc = FASTQC.out.reports.flatten()
        .mix(ALIGN.out.log.map { meta, log -> log })
        .mix(FILTER_BAM.out.log)
        .mix(SAMTOOLS_STATS.out.flagstat)
        .mix(PRESEQ_LCEXTRAP.out.lc_extrap)
        .mix(PLOT_FINGERPRINT.out.counts)
        .mix(PLOT_FINGERPRINT.out.metrics)
        .mix(TSS_PROFILE.out.profile_data)
        .mix(MACS2_CALLPEAK.out.xls)
        .collect()
    MULTIQC(ch_multiqc)
}
