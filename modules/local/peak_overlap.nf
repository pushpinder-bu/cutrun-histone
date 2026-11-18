// PEAK_OVERLAP: which regions and genes carry a mark in which cell types.
// Narrow marks: union of peaks (overlapping peaks merged). Broad marks (--broad_marks): peaks within
// --domain_merge_distance joined into domains, then the genome in --overlap_bin_size bins, marked when
// >= 50% covered. Genes: a promoter (TSS +/- --promoter_flank) overlapping a peak/domain.
// Output: 0/1 tables (one column per cell type), used for UpSet plots.

process PEAK_OVERLAP {
    tag "$mark"
    label 'process_low'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/52/52d3fbb86c48b8c39a989733ca97bfd84cf665a9ab279be7cfbbb36f5a53c46a/data'
        : 'community.wave.seqera.io/library/bedtools:2.31.1--897920cd303d6413' }"
    publishDir "${params.outdir}/overlap", mode: 'copy'

    input:
    tuple val(mark), val(cells), path(peaks)        // all cell types for one mark; lists in matching order
    path promoters
    path sizes

    output:
    tuple val(mark), path("${mark}_*_matrix.tsv"), emit: matrices

    script:
    def broad = mark in params.broad_marks.toString().tokenize(',')*.trim()
    def header = "chr\\tstart\\tend\\t" + cells.join('\\t')
    """
    cells=(${cells.join(' ')}); peaks=(${peaks.join(' ')})
    for i in \${!cells[@]}; do
        if ${broad}; then
            bedtools merge -d ${params.domain_merge_distance} -i \${peaks[\$i]} > \${cells[\$i]}.regions.bed
        else
            cp \${peaks[\$i]} \${cells[\$i]}.regions.bed
        fi
    done

    if ${broad}; then
        # fixed bins, so long domains are compared by how much of them is shared
        bedtools makewindows -g ${sizes} -w ${params.overlap_bin_size} | LC_ALL=C sort -k1,1 -k2,2n > bins.bed
        flags=()
        for c in \${cells[@]}; do
            bedtools coverage -a bins.bed -b \$c.regions.bed | LC_ALL=C sort -k1,1 -k2,2n | awk '{print (\$NF >= 0.5) ? 1 : 0}' > \$c.flag
            flags+=(\$c.flag)
        done
        { echo -e "${header}"; paste bins.bed \${flags[@]} | awk '{s=0; for(i=4;i<=NF;i++) s+=\$i} s>0'; } > ${mark}_bins_matrix.tsv
    else
        # union of peaks; record which cell types contributed to each merged region
        for c in \${cells[@]}; do awk -v c=\$c 'BEGIN{OFS="\\t"} {print \$1,\$2,\$3,c}' \$c.regions.bed; done \\
          | LC_ALL=C sort -k1,1 -k2,2n | bedtools merge -c 4 -o distinct > union.bed
        { echo -e "${header}"
          awk -v list="\${cells[*]}" 'BEGIN{OFS="\\t"; n=split(list,C," ")} {
              delete has; k=split(\$4,L,","); for(j=1;j<=k;j++) has[L[j]]=1
              line=\$1 OFS \$2 OFS \$3; for(j=1;j<=n;j++) line=line OFS ((C[j] in has) ? 1 : 0); print line }' union.bed
        } > ${mark}_regions_matrix.tsv
    fi

    # genes: promoter overlapping a peak/domain in each cell type
    for c in \${cells[@]}; do bedtools intersect -u -a ${promoters} -b \$c.regions.bed | cut -f4 | LC_ALL=C sort -u > \$c.genes; done
    { echo -e "${header}" | sed 's/^chr\\tstart\\tend/gene\\t.\\t./'
      cut -f4 ${promoters} | LC_ALL=C sort -u | awk -v list="\${cells[*]}" 'BEGIN{OFS="\\t"; n=split(list,C," ")
          for(j=1;j<=n;j++) while((getline g < (C[j] ".genes")) > 0) has[C[j],g]=1 }
          { line=\$1 OFS "." OFS "."; s=0; for(j=1;j<=n;j++){ v=((C[j],\$1) in has) ? 1 : 0; s+=v; line=line OFS v } if (s>0) print line }'
    } > ${mark}_genes_matrix.tsv
    """

    stub:
    def stub_header = "chr\\tstart\\tend\\t" + cells.join('\\t')
    """
    echo -e "${stub_header}" > ${mark}_genes_matrix.tsv
    """
}
