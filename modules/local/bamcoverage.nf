// BAMCOVERAGE: RPGC-normalized bigWig with deepTools bamCoverage

process BAMCOVERAGE {
    tag "$meta.id"
    label 'process_high'
    container 'community.wave.seqera.io/library/deeptools_samtools:22ef5f45259c4336'
    publishDir "${params.outdir}/bigwig", mode: 'copy'

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${meta.id}.bw"), emit: bw

    script:
    """
    bamCoverage --bam ${bam} -o ${meta.id}.bw \\
        --binSize ${params.bw_bin_size} --normalizeUsing RPGC \\
        --effectiveGenomeSize ${params.effective_genome_size} \\
        --extendReads ${params.extend_reads} -p ${task.cpus}
    """

    stub:
    """
    touch ${meta.id}.bw
    """
}
