// PEAK_QC: remove blacklisted regions, make consensus peaks (MACS2 peaks also found by SEACR),
// and report the number of peaks and FRiP (fraction of fragments in peaks) for each peak set

process PEAK_QC {
    tag "$meta.id"
    label 'process_low'
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/52/52d3fbb86c48b8c39a989733ca97bfd84cf665a9ab279be7cfbbb36f5a53c46a/data'
        : 'community.wave.seqera.io/library/bedtools:2.31.1--897920cd303d6413' }"
    publishDir "${params.outdir}/peaks/final", mode: 'copy', pattern: '*.bed'

    input:
    tuple val(meta), path(macs2), path(seacr), path(fragments)
    path blacklist                                   // assets/NO_FILE when no blacklist is given

    output:
    tuple val(meta), path("${meta.id}.macs2.bed"),     emit: macs2
    tuple val(meta), path("${meta.id}.consensus.bed"), emit: consensus
    path "${meta.id}.seacr.filtered.bed",              emit: seacr
    path "${meta.id}.peak_summary.tsv",                emit: summary

    script:
    def use_bl = blacklist.name != 'NO_FILE'
    """
    filt () {   # \$1 in, \$2 out: first 3 columns+, sorted, blacklisted regions removed
        cut -f1-3 \$1 | LC_ALL=C sort -k1,1 -k2,2n > tmp.bed
        if ${use_bl}; then bedtools intersect -v -a tmp.bed -b ${blacklist} > \$2; else mv tmp.bed \$2; fi
    }
    filt ${macs2} ${meta.id}.macs2.bed
    filt ${seacr} ${meta.id}.seacr.filtered.bed

    # consensus: MACS2 peaks overlapping a SEACR peak (both callers agree)
    bedtools intersect -u -a ${meta.id}.macs2.bed -b ${meta.id}.seacr.filtered.bed > ${meta.id}.consensus.bed

    total=\$(wc -l < ${fragments})
    echo -e "sample\\tcell_type\\tmark\\tpeak_set\\tn_peaks\\tmedian_width_bp\\tfrip" > ${meta.id}.peak_summary.tsv
    for set in macs2 seacr.filtered consensus; do
        f=${meta.id}.\$set.bed
        n=\$(wc -l < \$f)
        w=\$(awk '{print \$3-\$2}' \$f | sort -n | awk '{a[NR]=\$1} END{print (NR ? a[int((NR+1)/2)] : 0)}')
        inp=\$( [ \$n -gt 0 ] && bedtools intersect -u -a ${fragments} -b \$f | wc -l || echo 0 )
        awk -v s=${meta.id} -v c=${meta.cell} -v m=${meta.mark} -v p=\${set%.filtered} -v n=\$n -v w=\$w -v i=\$inp -v t=\$total \\
            'BEGIN{printf "%s\\t%s\\t%s\\t%s\\t%d\\t%d\\t%.3f\\n", s, c, m, p, n, w, (t > 0 ? i / t : 0)}' >> ${meta.id}.peak_summary.tsv
    done
    """

    stub:
    """
    touch ${meta.id}.macs2.bed ${meta.id}.consensus.bed ${meta.id}.seacr.filtered.bed
    echo -e "sample\\tcell_type\\tmark\\tpeak_set\\tn_peaks\\tmedian_width_bp\\tfrip" > ${meta.id}.peak_summary.tsv
    """
}
