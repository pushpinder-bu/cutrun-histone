// SAMTOOLS_STATS: flagstat and a one-line QC summary per sample (read pairs, mapping, duplication, final reads)

process SAMTOOLS_STATS {
    tag "$meta.id"
    label 'process_medium'
    // Singularity/Apptainer: pre-built Singularity image; Docker: the matching Docker image (same build, as in nf-core modules)
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/87/87660348a4d032cc08d6ac8101ff9d4d27164300d39c9472043bb5001f9ba801/data'
        : 'community.wave.seqera.io/library/htslib_samtools:1.25--704fb80d75745bd4' }"
    publishDir "${params.outdir}/qc/flagstat", mode: 'copy', pattern: '*.flagstat.txt'

    input:
    tuple val(meta), path(mbam), path(mbai), path(fbam), path(fbai), path(bt2log)

    output:
    path "${meta.id}.markdup.flagstat.txt", emit: flagstat
    path "${meta.id}.summary.tsv",          emit: summary

    script:
    """
    # duplication / mapping stats on the duplicate-marked BAM
    samtools flagstat -@ ${task.cpus} ${mbam} > ${meta.id}.markdup.flagstat.txt

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
    touch ${meta.id}.markdup.flagstat.txt
    echo -e "sample\\tcell_type\\tmark\\traw_read_pairs\\tprimary_reads\\tprimary_mapped\\tduplicates\\tdup_pct\\tfinal_filtered_reads" > ${meta.id}.summary.tsv
    echo -e "${meta.id}\\t${meta.cell}\\t${meta.mark}\\t0\\t0\\t0\\t0\\t0.0\\t0" >> ${meta.id}.summary.tsv
    """
}
