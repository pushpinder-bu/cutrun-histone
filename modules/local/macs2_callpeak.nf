// MACS2_CALLPEAK: peaks against the matched IgG, using paired-end fragments (BAMPE).
// Marks listed in --broad_marks (default H3K27me3) are called in broad mode, all others in narrow mode.

process MACS2_CALLPEAK {
    tag "$meta.id"
    label 'process_medium'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://depot.galaxyproject.org/singularity/macs2:2.2.9.1--py39hff71179_1'
        : 'quay.io/biocontainers/macs2:2.2.9.1--py39hff71179_1' }"
    publishDir "${params.outdir}/peaks/macs2", mode: 'copy'

    input:
    tuple val(meta), path(bam), path(bai), path(ctrl_bam), path(ctrl_bai)

    output:
    tuple val(meta), path("${meta.id}_peaks.{narrowPeak,broadPeak}"), emit: peaks
    path "${meta.id}_peaks.xls",                                       emit: xls      // read by MultiQC

    script:
    def broad = meta.mark in params.broad_marks.toString().tokenize(',')*.trim()
    def mode  = broad ? "--broad --broad-cutoff ${params.macs2_broad_cutoff}" : "-q ${params.macs2_qvalue}"
    def gsize = params.macs2_gsize ?: params.effective_genome_size
    """
    # --keep-dup all: duplicates were already removed by FILTER_BAM
    macs2 callpeak -t ${bam} -c ${ctrl_bam} -f BAMPE -g ${gsize} ${mode} --keep-dup all -n ${meta.id}
    """

    stub:
    def ext = meta.mark in params.broad_marks.toString().tokenize(',')*.trim() ? 'broadPeak' : 'narrowPeak'
    """
    touch ${meta.id}_peaks.${ext} ${meta.id}_peaks.xls
    """
}
