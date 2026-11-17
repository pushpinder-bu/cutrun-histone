// UNTAR_INDEX: unpack a bowtie2 index supplied as a .tar.gz (e.g. the test-profile reference)

process UNTAR_INDEX {
    tag "$archive.name"
    label 'process_low'
    // Singularity/Apptainer: pre-built Singularity image; Docker: the matching Docker image (same build, as in nf-core modules)
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/52/52ccce28d2ab928ab862e25aae26314d69c8e38bd41ca9431c67ef05221348aa/data'
        : 'community.wave.seqera.io/library/coreutils_grep_gzip_lbzip2_pruned:838ba80435a629f8' }"

    input:
    path archive

    output:
    path "index/*", emit: index

    script:
    """
    mkdir -p index
    tar -xzf ${archive} -C index --strip-components 1
    """

    stub:
    """
    mkdir -p index
    touch index/genome.1.bt2 index/genome.rev.1.bt2
    """
}
