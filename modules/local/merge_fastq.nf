// MERGE_FASTQ: join the FASTQs of a sample sequenced in several runs (several samplesheet rows) into one pair

process MERGE_FASTQ {
    tag "$meta.id"
    label 'process_low'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/52/52ccce28d2ab928ab862e25aae26314d69c8e38bd41ca9431c67ef05221348aa/data'
        : 'community.wave.seqera.io/library/coreutils_grep_gzip_lbzip2_pruned:838ba80435a629f8' }"

    input:
    tuple val(meta), path(r1, stageAs: 'r1_?/*'), path(r2, stageAs: 'r2_?/*')   // one folder per run: same file names cannot clash

    output:
    tuple val(meta), path("${meta.id}_R1.merged.fastq.gz"), path("${meta.id}_R2.merged.fastq.gz"), emit: reads

    script:
    // gzip files can simply be concatenated; R1 and R2 are joined in the same run order
    """
    cat ${r1.join(' ')} > ${meta.id}_R1.merged.fastq.gz
    cat ${r2.join(' ')} > ${meta.id}_R2.merged.fastq.gz
    """

    stub:
    """
    touch ${meta.id}_R1.merged.fastq.gz ${meta.id}_R2.merged.fastq.gz
    """
}
