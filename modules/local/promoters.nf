// PROMOTERS: promoter regions (TSS +/- --promoter_flank) with a gene name, from a GTF or BED annotation

process PROMOTERS {
    tag "$genes.name"
    label 'process_low'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/52/52ccce28d2ab928ab862e25aae26314d69c8e38bd41ca9431c67ef05221348aa/data'
        : 'community.wave.seqera.io/library/coreutils_grep_gzip_lbzip2_pruned:838ba80435a629f8' }"

    input:
    path genes

    output:
    path "promoters.bed", emit: bed

    script:
    def flank = params.promoter_flank
    """
    zcat -f ${genes} > annotation.txt
    if awk -F'\\t' 'NF >= 9 && \$9 ~ /gene_id/ {found=1; exit} END{exit !found}' annotation.txt; then
        # GTF: gene lines (protein-coding only when a biotype is given); fall back to transcript lines
        feat=gene; awk -F'\\t' '\$3=="gene"{f=1; exit} END{exit !f}' annotation.txt || feat=transcript
        awk -F'\\t' -v feat=\$feat -v fl=${flank} 'BEGIN{OFS="\\t"} \$3==feat {
            if (\$9 ~ /gene_(bio)?type "/ && \$9 !~ /gene_(bio)?type "protein_coding"/) next
            name=""; if (match(\$9,/gene_name "[^"]+"/)) name=substr(\$9,RSTART+11,RLENGTH-12)
            else if (match(\$9,/gene_id "[^"]+"/)) name=substr(\$9,RSTART+9,RLENGTH-10)
            tss=(\$7=="-") ? \$5-1 : \$4-1; s=tss-fl; if (s<0) s=0; print \$1, s, tss+fl, name }' annotation.txt > raw.bed
    else
        # BED: name in column 4, strand in column 6
        awk -F'\\t' -v fl=${flank} 'BEGIN{OFS="\\t"} !/^(#|track|browser)/ && NF>=3 {
            tss=(\$6=="-") ? \$3-1 : \$2; s=tss-fl; if (s<0) s=0; print \$1, s, tss+fl, (NF>=4 ? \$4 : \$1":"\$2) }' annotation.txt > raw.bed
    fi
    LC_ALL=C sort -k1,1 -k2,2n -u raw.bed > promoters.bed
    """

    stub:
    """
    touch promoters.bed
    """
}
