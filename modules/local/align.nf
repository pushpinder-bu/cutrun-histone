// ALIGN: Align paired-end reads with bowtie2 (--local, --reorder) and write a BAM

process ALIGN {
    tag "$meta.id"
    label 'process_high'
    container 'community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:e1c7af09e1513a6c'

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    tuple val(meta), path("${meta.id}.bam"),         emit: bam
    tuple val(meta), path("${meta.id}.bowtie2.log"), emit: log

    script:
    // --reorder: write reads in input order, so the same input always gives identical output
    """
    bowtie2 -p ${task.cpus} --reorder -q --local -x ${params.bowtie2_index} \\
        -1 ${r1} -2 ${r2} 2> ${meta.id}.bowtie2.log \\
      | samtools view -h -b -@ ${task.cpus} -o ${meta.id}.bam -
    """

    stub:
    """
    touch ${meta.id}.bam ${meta.id}.bowtie2.log
    """
}
