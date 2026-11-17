// PRESEQ_LCEXTRAP: library complexity (how many new unique reads more sequencing would give)

process PRESEQ_LCEXTRAP {
    tag "$meta.id"
    label 'process_medium'
    container 'community.wave.seqera.io/library/preseq:3.2.0--c485d1f68d51de10'
    publishDir "${params.outdir}/qc/preseq", mode: 'copy', pattern: '*.lc_extrap.txt'

    // preseq sometimes fails on very low-duplication libraries: retry once without the defect check,
    // and if it still fails, carry on without a preseq curve for that sample
    errorStrategy { task.attempt <= 1 ? 'retry' : 'ignore' }
    maxRetries 1

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    path "${meta.id}.lc_extrap.txt", emit: lc_extrap

    script:
    def defects = task.attempt > 1 ? '-defects' : ''
    """
    preseq lc_extrap -pe ${defects} -output ${meta.id}.lc_extrap.txt ${bam}
    """

    stub:
    """
    touch ${meta.id}.lc_extrap.txt
    """
}
