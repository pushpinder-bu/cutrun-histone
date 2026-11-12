// ---------------------------------------------------------------
// cutrun-histone - Lesson 2: alignment, filtering, bigWigs and QC
// ---------------------------------------------------------------

// PARAMETERS (override with --name value)
params.input                 = 'samplesheet.csv'
params.outdir                = 'results'
params.bowtie2_index         = '/restricted/projectnb/crem-bioinfo/reference_data/REFERENCES/GRCh38/bwa/withChr/bowtie/hg38'
params.effective_genome_size = 2913022398
params.bw_bin_size           = 10
params.extend_reads          = 200

// =================== PROCESSES ===================

process FASTQC {
    tag "$meta.id"
    label 'medium'
    publishDir "${params.outdir}/qc/fastqc", mode: 'copy'

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    path "*_fastqc.{zip,html}", emit: reports

    script:
    """
    fastqc -t ${task.cpus} ${r1} ${r2}
    """

    stub:
    """
    touch ${meta.id}_R1_fastqc.zip ${meta.id}_R1_fastqc.html
    """
}

process ALIGN {
    tag "$meta.id"
    label 'big'

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    tuple val(meta), path("${meta.id}.bam"),         emit: bam
    tuple val(meta), path("${meta.id}.bowtie2.log"), emit: log

    script:
    // --reorder: write reads in input order, so the same input always gives identical output
    """
    bowtie2 -p ${task.cpus} --reorder -q --local -x ${params.bowtie2_index} \\
        -1 ${r1} -2 ${r2} 2> ${meta.id}.bowtie2.log \\
      | samtools view -h -b -@ ${task.cpus} -o ${meta.id}.bam -
    """

    stub:
    """
    touch ${meta.id}.bam ${meta.id}.bowtie2.log
    """
}

process FILTER_BAM {
    tag "$meta.id"
    label 'big'
    publishDir "${params.outdir}/alignment/${meta.id}", mode: 'copy'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${meta.id}.sorted.markdup.bam"), path("${meta.id}.sorted.markdup.bam.bai"), emit: markdup
    tuple val(meta), path("${meta.id}.sorted.markdup.filtered.bam"), path("${meta.id}.sorted.markdup.filtered.bam.bai"), emit: filtered
    path "${meta.id}.markdup.log", emit: log

    script:
    """
    mkdir -p tmp
    sambamba sort -t ${task.cpus} --tmpdir tmp -o ${meta.id}.sorted.bam ${bam}
    sambamba markdup -t ${task.cpus} --tmpdir tmp ${meta.id}.sorted.bam ${meta.id}.sorted.markdup.bam 2> ${meta.id}.markdup.log
    sambamba view -h -t ${task.cpus} -f bam \\
        -F "[XS] == null and not unmapped and not duplicate" \\
        ${meta.id}.sorted.markdup.bam > ${meta.id}.sorted.markdup.filtered.bam
    samtools index -@ ${task.cpus} ${meta.id}.sorted.markdup.filtered.bam
    """

    stub:
    """
    touch ${meta.id}.sorted.markdup.bam ${meta.id}.sorted.markdup.bam.bai
    touch ${meta.id}.sorted.markdup.filtered.bam ${meta.id}.sorted.markdup.filtered.bam.bai ${meta.id}.markdup.log
    """
}

process BAMCOVERAGE {
    tag "$meta.id"
    label 'big'
    publishDir "${params.outdir}/bigwig", mode: 'copy'

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${meta.id}.bw"), emit: bw

    script:
    """
    bamCoverage --bam ${bam} -o ${meta.id}.bw \\
        --binSize ${params.bw_bin_size} --normalizeUsing RPGC \\
        --effectiveGenomeSize ${params.effective_genome_size} \\
        --extendReads ${params.extend_reads} -p ${task.cpus}
    """

    stub:
    """
    touch ${meta.id}.bw
    """
}

process QC_STATS {
    tag "$meta.id"
    label 'medium'
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

process MULTIQC {
    label 'small'
    publishDir "${params.outdir}/qc/multiqc", mode: 'copy'

    input:
    path qc_files              // every QC file from every sample, staged in one folder

    output:
    path "multiqc_report.html"
    path "multiqc_report_data"

    script:
    """
    multiqc -f -n multiqc_report.html .
    """

    stub:
    """
    touch multiqc_report.html; mkdir multiqc_report_data
    """
}

// =================== WORKFLOW ===================

workflow {
    // read the samplesheet -> one item per sample: [meta, R1, R2]
    ch_reads = Channel
        .fromPath(params.input)
        .splitCsv(header: true)
        .map { row ->
            def meta = [id: row.sample, cell: row.cell_type, mark: row.mark]
            tuple(meta, file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true))
        }

    // (1) the same channel can feed several processes
    FASTQC(ch_reads)
    ALIGN(ch_reads)

    FILTER_BAM(ALIGN.out.bam)
    BAMCOVERAGE(FILTER_BAM.out.filtered)

    // (2) join: line up outputs from different steps by their shared meta (same sample)
    ch_for_qc = FILTER_BAM.out.markdup                 // [meta, markdup.bam, .bai]
        .join(FILTER_BAM.out.filtered)                 // + [filtered.bam, .bai]
        .join(ALIGN.out.log)                           // + [bowtie2.log]
    QC_STATS(ch_for_qc)

    // collectFile: stack every sample's one-line summary into one table
    QC_STATS.out.summary
        .collectFile(name: 'QC_summary.tsv', keepHeader: true, skip: 1, sort: true,
                     storeDir: "${params.outdir}/qc")

    // (3) mix + collect: gather QC files from all samples and steps, then run MultiQC once
    ch_multiqc = FASTQC.out.reports.flatten()
        .mix(ALIGN.out.log.map { meta, log -> log })
        .mix(FILTER_BAM.out.log)
        .mix(QC_STATS.out.flagstat)
        .mix(QC_STATS.out.preseq)
        .collect()
    MULTIQC(ch_multiqc)
}
