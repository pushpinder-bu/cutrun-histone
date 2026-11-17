// BAMCOVERAGE: RPGC-normalized bigWig with deepTools bamCoverage

process BAMCOVERAGE {
    tag "$meta.id"
    label 'process_high'
    // Singularity/Apptainer: pre-built Singularity image; Docker: the matching Docker image (same build, as in nf-core modules)
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/aa/aa2a707745965f561e777fdce54f18881d0e53a12c1b3a29ba1b2a6f2112f099/data'
        : 'community.wave.seqera.io/library/deeptools_samtools:22ef5f45259c4336' }"
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
