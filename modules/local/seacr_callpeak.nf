// SEACR_CALLPEAK: SEACR (designed for CUT&RUN) on fragment coverage, against the matched IgG

process SEACR_CALLPEAK {
    tag "$meta.id"
    label 'process_low'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://depot.galaxyproject.org/singularity/mulled-v2-03bfeb32fe80910c231f630d4262b83677c8c0f4:f4bb19b68e66de27e4c64306f951d5ff11919931-0'
        : 'quay.io/biocontainers/mulled-v2-03bfeb32fe80910c231f630d4262b83677c8c0f4:f4bb19b68e66de27e4c64306f951d5ff11919931-0' }"
    publishDir "${params.outdir}/peaks/seacr", mode: 'copy', pattern: '*.bed'

    input:
    tuple val(meta), path(fragments), path(ctrl_fragments)
    path sizes

    output:
    tuple val(meta), path("${meta.id}.seacr.bed"), emit: peaks

    script:
    """
    bedtools genomecov -bg -i ${fragments}      -g ${sizes} > target.bedgraph
    bedtools genomecov -bg -i ${ctrl_fragments} -g ${sizes} > control.bedgraph

    # 'norm': scale the IgG to the target; mode = stringent or relaxed.
    # SEACR can fail on very sparse data (e.g. "awk: Division by zero" when nothing passes its threshold).
    # Then continue with no SEACR peaks for this sample, so its MACS2 peaks still reach the later steps.
    if SEACR_1.3.sh target.bedgraph control.bedgraph norm ${params.seacr_mode} ${meta.id}; then
        mv ${meta.id}.${params.seacr_mode}.bed ${meta.id}.seacr.bed
    else
        echo "WARNING: SEACR failed for ${meta.id} (usually too little signal); continuing with no SEACR peaks" >&2
        : > ${meta.id}.seacr.bed
    fi
    """

    stub:
    """
    touch ${meta.id}.seacr.bed
    """
}
