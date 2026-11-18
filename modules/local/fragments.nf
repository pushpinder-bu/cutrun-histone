// FRAGMENTS: one line per sequenced DNA fragment (from properly paired reads, < 1 kb), plus chromosome sizes

process FRAGMENTS {
    tag "$meta.id"
    label 'process_medium'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/87/87660348a4d032cc08d6ac8101ff9d4d27164300d39c9472043bb5001f9ba801/data'
        : 'community.wave.seqera.io/library/htslib_samtools:1.25--704fb80d75745bd4' }"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${meta.id}.fragments.bed"), emit: fragments
    path "chrom.sizes",                                 emit: sizes

    script:
    """
    samtools view -H ${bam} | awk -F'\\t' '\$1=="@SQ"{sub("SN:","",\$2); sub("LN:","",\$3); print \$2"\\t"\$3}' > chrom.sizes

    # leftmost read of each proper pair: fragment = start .. start + insert size (TLEN)
    samtools view -@ ${task.cpus} -f 0x2 -F 0x904 ${bam} \\
      | awk -v OFS='\\t' '\$9 > 0 && \$9 < 1000 {print \$3, \$4 - 1, \$4 - 1 + \$9}' \\
      | LC_ALL=C sort -k1,1 -k2,2n -S 2G -T . > ${meta.id}.fragments.bed
    """

    stub:
    """
    touch ${meta.id}.fragments.bed; printf "chr1\\t1000\\n" > chrom.sizes
    """
}
