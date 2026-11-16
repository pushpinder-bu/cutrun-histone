// QC_STATS: flagstat, preseq library complexity and a one-line QC summary per sample

process QC_STATS {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}/qc", mode: 'copy', pattern: '{flagstat,preseq}/*'

    input:
    tuple val(meta), path(mbam), path(mbai), path(fbam), path(fbai), path(bt2log)

    output:
    path "flagstat/${meta.id}.markdup.flagstat.txt", emit: flagstat
    path "preseq/${meta.id}.lc_extrap.txt",          emit: preseq, optional: true
    path "${meta.id}.summary.tsv",                   emit: summary

    script:
    """
    mkdir -p flagstat preseq tmp

    # duplication / mapping stats on the duplicate-marked BAM
    samtools flagstat -@ ${task.cpus} ${mbam} > flagstat/${meta.id}.markdup.flagstat.txt

    # library complexity; paired BAM mode, fall back to a BED of reads if needed
    run_preseq () { out=\$1; shift; preseq lc_extrap -o "\$out" "\$@" || preseq lc_extrap -D -o "\$out" "\$@"; }
    if ! run_preseq preseq/${meta.id}.lc_extrap.txt -P -B ${mbam}; then
        samtools view -b -F 0x904 ${mbam} | bedtools bamtobed -i - \\
            | sort -k1,1 -k2,2n -k3,3n -k6,6 -T tmp > tmp/reads.bed
        run_preseq preseq/${meta.id}.lc_extrap.txt tmp/reads.bed || rm -f preseq/${meta.id}.lc_extrap.txt
    fi

    # one-line summary (raw read pairs come from the bowtie2 log)
    raw_pairs=\$(awk '/reads; of these:/{print \$1; exit}' ${bt2log})
    primary=\$(samtools view -c -@ ${task.cpus} -F 0x900 ${mbam})
    mapped=\$(samtools view -c -@ ${task.cpus} -F 0x904 ${mbam})
    dups=\$(samtools view -c -@ ${task.cpus} -f 0x400 -F 0x904 ${mbam})
    final=\$(samtools view -c -@ ${task.cpus} -F 0x904 ${fbam})
    echo -e "sample\\tcell_type\\tmark\\traw_read_pairs\\tprimary_reads\\tprimary_mapped\\tduplicates\\tdup_pct\\tfinal_filtered_reads" > ${meta.id}.summary.tsv
    awk -v s=${meta.id} -v c=${meta.cell} -v k=${meta.mark} -v r=\$raw_pairs -v t=\$primary -v m=\$mapped -v d=\$dups -v f=\$final \\
        'BEGIN{printf "%s\\t%s\\t%s\\t%d\\t%d\\t%d\\t%d\\t%.1f\\t%d\\n", s, c, k, r, t, m, d, (m>0?100*d/m:0), f}' >> ${meta.id}.summary.tsv
    """

    stub:
    """
    mkdir -p flagstat preseq
    touch flagstat/${meta.id}.markdup.flagstat.txt preseq/${meta.id}.lc_extrap.txt
    echo -e "sample\\tcell_type\\tmark\\traw_read_pairs\\tprimary_reads\\tprimary_mapped\\tduplicates\\tdup_pct\\tfinal_filtered_reads" > ${meta.id}.summary.tsv
    echo -e "${meta.id}\\t${meta.cell}\\t${meta.mark}\\t0\\t0\\t0\\t0\\t0.0\\t0" >> ${meta.id}.summary.tsv
    """
}
