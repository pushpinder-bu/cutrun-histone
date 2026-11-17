// ALIGN: Align paired-end reads with bowtie2 (--local, --reorder) and write a BAM; the index is an input, so changing it reruns alignment

process ALIGN {
    tag "$meta.id"
    label 'process_high'
    // Singularity/Apptainer: pre-built Singularity image; Docker: the matching Docker image (same build, as in nf-core modules)
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/70/7093a62c894ad3337cabda5efadce78a3ecdb5ba34cf8646743c6d43d8c4b77d/data'
        : 'community.wave.seqera.io/library/bowtie2_htslib_samtools_pigz:e1c7af09e1513a6c' }"

    input:
    tuple val(meta), path(r1), path(r2)
    path index                                   // all bowtie2 index files (*.bt2), staged into the task folder

    output:
    tuple val(meta), path("${meta.id}.bam"),         emit: bam
    tuple val(meta), path("${meta.id}.bowtie2.log"), emit: log

    script:
    // --reorder: write reads in input order, so the same input always gives identical output
    """
    # index prefix = name of the *.rev.1.bt2 (or .bt2l) file without that ending
    idx=\$(ls *.rev.1.bt2* | head -1 | sed -E 's/\\.rev\\.1\\.bt2l?\$//')

    bowtie2 -p ${task.cpus} --reorder -q --local -x \$idx \\
        -1 ${r1} -2 ${r2} 2> ${meta.id}.bowtie2.log \\
      | samtools view -h -b -@ ${task.cpus} -o ${meta.id}.bam -
    """

    stub:
    """
    touch ${meta.id}.bam ${meta.id}.bowtie2.log
    """
}
