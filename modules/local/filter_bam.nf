// FILTER_BAM: Sort, mark duplicates, keep uniquely mapped non-duplicate reads, index (all with sambamba)

process FILTER_BAM {
    tag "$meta.id"
    label 'process_high'
    // Singularity/Apptainer: pre-built Singularity image; Docker: the matching Docker image (same build, as in nf-core modules)
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d9/d92b95f4b1fcff268d632d73b9adc861b0e2db41d4ac5ec1ae598f72f194b8fe/data'
        : 'community.wave.seqera.io/library/sambamba:1.0.1--f6f871dbcf29d001' }"
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
    sambamba index -t ${task.cpus} ${meta.id}.sorted.markdup.filtered.bam
    """

    stub:
    """
    touch ${meta.id}.sorted.markdup.bam ${meta.id}.sorted.markdup.bam.bai
    touch ${meta.id}.sorted.markdup.filtered.bam ${meta.id}.sorted.markdup.filtered.bam.bai ${meta.id}.markdup.log
    """
}
