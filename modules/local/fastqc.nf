// FASTQC: FastQC on raw paired-end reads

process FASTQC {
    tag "$meta.id"
    label 'process_medium'
    // Singularity/Apptainer: pre-built Singularity image; Docker: the matching Docker image (same build, as in nf-core modules)
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/81/816bda6dd014e810753f642611232443ddeabb2b47f9681ad43f9044816f00ff/data'
        : 'community.wave.seqera.io/library/fastqc:0.13.0--b342db7b694c9af4' }"
    publishDir "${params.outdir}/qc/fastqc", mode: 'copy'

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    path "*_fastqc.{zip,html}", emit: reports

    script:
    // link the reads under the sample name, so reports (and MultiQC) are labelled by sample, not by file name
    """
    ln -s ${r1} ${meta.id}_R1.fastq.gz
    ln -s ${r2} ${meta.id}_R2.fastq.gz
    fastqc -t ${task.cpus} ${meta.id}_R1.fastq.gz ${meta.id}_R2.fastq.gz
    """

    stub:
    """
    touch ${meta.id}_R1_fastqc.zip ${meta.id}_R1_fastqc.html
    """
}
