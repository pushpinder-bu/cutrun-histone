// FASTQC: FastQC on raw paired-end reads

process FASTQC {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}/qc/fastqc", mode: 'copy'

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    path "*_fastqc.{zip,html}", emit: reports

    script:
    """
    fastqc -t ${task.cpus} ${r1} ${r2}
    """

    stub:
    """
    touch ${meta.id}_R1_fastqc.zip ${meta.id}_R1_fastqc.html
    """
}
