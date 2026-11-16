// FILTER_BAM: Sort, mark duplicates, keep uniquely mapped non-duplicate reads, index

process FILTER_BAM {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}/alignment/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.id}.sorted.markdup.bam"), path("${meta.id}.sorted.markdup.bam.bai"), emit: markdup
    tuple val(meta), path("${meta.id}.sorted.markdup.filtered.bam"), path("${meta.id}.sorted.markdup.filtered.bam.bai"), emit: filtered
    path "${meta.id}.markdup.log", emit: log

    script:
    """
    mkdir -p tmp
    sambamba sort -t ${task.cpus} --tmpdir tmp -o ${meta.id}.sorted.bam ${bam}
    sambamba markdup -t ${task.cpus} --tmpdir tmp ${meta.id}.sorted.bam ${meta.id}.sorted.markdup.bam 2> ${meta.id}.markdup.log
    sambamba view -h -t ${task.cpus} -f bam \\
        -F "[XS] == null and not unmapped and not duplicate" \\
        ${meta.id}.sorted.markdup.bam > ${meta.id}.sorted.markdup.filtered.bam
    samtools index -@ ${task.cpus} ${meta.id}.sorted.markdup.filtered.bam
    """

    stub:
    """
    touch ${meta.id}.sorted.markdup.bam ${meta.id}.sorted.markdup.bam.bai
    touch ${meta.id}.sorted.markdup.filtered.bam ${meta.id}.sorted.markdup.filtered.bam.bai ${meta.id}.markdup.log
    """
}
