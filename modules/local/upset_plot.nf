// UPSET_PLOT: UpSet plot and combination counts for each overlap table (Python with numpy + matplotlib)

process UPSET_PLOT {
    tag "$mark"
    label 'process_low'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/aa/aa2a707745965f561e777fdce54f18881d0e53a12c1b3a29ba1b2a6f2112f099/data'
        : 'community.wave.seqera.io/library/deeptools_samtools:22ef5f45259c4336' }"
    publishDir "${params.outdir}/overlap", mode: 'copy'

    input:
    tuple val(mark), path(matrices)
    path script                                   // bin/upset_plot.py, staged as an input

    output:
    path "*_upset.png",         emit: plots
    path "*_combinations.tsv",  emit: counts

    script:
    """
    for m in ${matrices.join(' ')}; do
        python3 ${script} \$m "\$(basename \$m _matrix.tsv)"
    done
    """

    stub:
    """
    touch ${mark}_upset.png ${mark}_combinations.tsv
    """
}
