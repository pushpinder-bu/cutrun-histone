// TSS_PROFILE: signal of every sample of one cell type around transcription start sites (TSS):
// a profile plot per window size, and a heatmap clustered on one mark (default H3K27me3)

process TSS_PROFILE {
    tag "$cell"
    label 'process_medium'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/aa/aa2a707745965f561e777fdce54f18881d0e53a12c1b3a29ba1b2a6f2112f099/data'
        : 'community.wave.seqera.io/library/deeptools_samtools:22ef5f45259c4336' }"
    publishDir "${params.outdir}/tss_profiles", mode: 'copy', pattern: '*.{png,bed,tab}'

    input:
    tuple val(cell), val(marks), path(bigwigs)    // one cell type; lists in matching order
    path genes                                    // GTF (with transcript lines) or BED of transcripts

    output:
    path "*.png",                   emit: plots
    path "*_profile_data.tab",      emit: profile_data       // read by MultiQC
    path "*_heatmap_clusters.bed",  emit: clusters, optional: true

    script:
    def windows = params.profile_windows.toString().tokenize(',')*.trim()
    def largest = windows.collect { it as int }.max()
    def k       = marks.indexOf(params.heatmap_cluster_mark)    // position of the clustering mark; -1 if absent
    def regions = genes.name.replaceAll(/\.gz$/, '')                // deepTools cannot read gzipped BED: unpack if needed
    def cluster = k >= 0 ? "--kmeans ${params.heatmap_kmeans} --clusterUsingSamples ${k + 1} --sortUsingSamples ${k + 1} --outFileSortedRegions ${cell}_heatmap_clusters.bed" : ''
    """
    if [ "${genes}" != "${regions}" ]; then gunzip -c ${genes} > ${regions}; fi

    for w in ${windows.join(' ')}; do
        lab=TSS_\$((w/1000))kb
        computeMatrix reference-point -R ${regions} --referencePoint TSS -b \$w -a \$w \\
            -S ${bigwigs.join(' ')} --samplesLabel ${marks.join(' ')} \\
            --skipZeros -p ${task.cpus} -o ${cell}_\$lab.mat.gz
        plotProfile -m ${cell}_\$lab.mat.gz -out ${cell}_\$lab.png --perGroup \\
            --plotTitle "${cell} - TSS +/- \$((w/1000)) kb" \\
            --outFileNameData ${cell}_\${lab}_profile_data.tab
    done

    # heatmap on the largest window, clustered on one mark; a failed heatmap does not stop the run
    plotHeatmap -m ${cell}_TSS_\$((${largest}/1000))kb.mat.gz -out ${cell}_heatmap.png \\
        --plotTitle "${cell} - TSS +/- \$((${largest}/1000)) kb" --colorMap Blues ${cluster} \\
      || echo "WARNING: heatmap could not be drawn for ${cell} (too few regions for clustering?)" >&2
    """

    stub:
    """
    touch ${cell}_TSS_2kb.png ${cell}_TSS_2kb_profile_data.tab ${cell}_heatmap.png
    """
}
