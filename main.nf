#!/usr/bin/env nextflow
// ---------------------------------------------------------------
// cutrun-histone: CUT&RUN histone-mark analysis
// Processes live in modules/local/; settings and resources in nextflow.config and conf/
// ---------------------------------------------------------------

include { FASTQC      } from './modules/local/fastqc'
include { ALIGN       } from './modules/local/align'
include { FILTER_BAM  } from './modules/local/filter_bam'
include { BAMCOVERAGE } from './modules/local/bamcoverage'
include { QC_STATS    } from './modules/local/qc_stats'
include { MULTIQC     } from './modules/local/multiqc'

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

    // (1) the same channel can feed several processes
    FASTQC(ch_reads)
    ALIGN(ch_reads)

    FILTER_BAM(ALIGN.out.bam)
    BAMCOVERAGE(FILTER_BAM.out.filtered)

    // (2) join: line up outputs from different steps by their shared meta (same sample)
    ch_for_qc = FILTER_BAM.out.markdup                 // [meta, markdup.bam, .bai]
        .join(FILTER_BAM.out.filtered)                 // + [filtered.bam, .bai]
        .join(ALIGN.out.log)                           // + [bowtie2.log]
    QC_STATS(ch_for_qc)

    // collectFile: stack every sample's one-line summary into one table
    QC_STATS.out.summary
        .collectFile(name: 'QC_summary.tsv', keepHeader: true, skip: 1, sort: true,
                     storeDir: "${params.outdir}/qc")

    // (3) mix + collect: gather QC files from all samples and steps, then run MultiQC once
    ch_multiqc = FASTQC.out.reports.flatten()
        .mix(ALIGN.out.log.map { meta, log -> log })
        .mix(FILTER_BAM.out.log)
        .mix(QC_STATS.out.flagstat)
        .mix(QC_STATS.out.preseq)
        .collect()
    MULTIQC(ch_multiqc)
}
