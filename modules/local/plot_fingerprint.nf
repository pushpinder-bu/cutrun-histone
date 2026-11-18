// PLOT_FINGERPRINT: deepTools fingerprint plot for all samples of one cell type (marks + IgG),
// with quality metrics (e.g. Jensen-Shannon distance) of each mark against that cell type's IgG

process PLOT_FINGERPRINT {
    tag "$cell"
    label 'process_medium'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/aa/aa2a707745965f561e777fdce54f18881d0e53a12c1b3a29ba1b2a6f2112f099/data'
        : 'community.wave.seqera.io/library/deeptools_samtools:22ef5f45259c4336' }"
    publishDir "${params.outdir}/fingerprint", mode: 'copy'

    input:
    tuple val(cell), val(marks), path(bams), path(bais)   // one cell type; lists in matching order

    output:
    path "${cell}_fingerprint.png",          emit: plot
    path "${cell}_fingerprint.tab",          emit: counts
    path "${cell}_fingerprint_metrics.txt",  emit: metrics, optional: true

    script:
    // compare every mark against this cell type's IgG, if it has one
    def ctrl = marks.indexOf(params.control_mark)
    def jsd  = ctrl >= 0 ? "--JSDsample ${bams[ctrl]} --outQualityMetrics ${cell}_fingerprint_metrics.txt" : ''
    """
    plotFingerprint \\
        -b ${bams.join(' ')} \\
        --labels ${marks.join(' ')} \\
        --minMappingQuality 10 --skipZeros \\
        -T "Fingerprints - ${cell}" \\
        --plotFile ${cell}_fingerprint.png \\
        --outRawCounts ${cell}_fingerprint.tab \\
        ${jsd} \\
        -p ${task.cpus}
    """

    stub:
    """
    touch ${cell}_fingerprint.png ${cell}_fingerprint.tab ${cell}_fingerprint_metrics.txt
    """
}
