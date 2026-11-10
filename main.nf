// ---------------------------------------------------------------
// CUT&RUN histone pipeline - Lesson 1: alignment + filtering
// ---------------------------------------------------------------

// 1) PARAMETERS: values you can change from the command line (--name value)
params.input        = 'samplesheet.csv'
params.outdir       = 'results'
params.bowtie2_index = '/restricted/projectnb/crem-bioinfo/reference_data/REFERENCES/GRCh38/bwa/withChr/bowtie/hg38'

// 2) PROCESSES: one step of work each (like one block of your qsub script)

process ALIGN {
    tag "$meta.id"                              // label shown in the log for this task
    label 'big'                                 // resources come from nextflow.config

    input:
    tuple val(meta), path(r1), path(r2)

    output:
    tuple val(meta), path("${meta.id}.bam"),      emit: bam
    path "${meta.id}.bowtie2.log",                emit: log

    script:
    """
    bowtie2 -p ${task.cpus} -q --local -x ${params.bowtie2_index} \\
        -1 ${r1} -2 ${r2} 2> ${meta.id}.bowtie2.log \\
      | samtools view -h -b -@ ${task.cpus} -o ${meta.id}.bam -
    """

    stub:   // used only with -stub-run, to test the wiring without real data
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

// 3) WORKFLOW: read the samplesheet, then connect the processes
workflow {
    ch_reads = Channel
        .fromPath(params.input)
        .splitCsv(header: true)                       // one map per row: [sample:..., cell_type:..., ...]
        .map { row ->
            def meta = [id: row.sample, cell: row.cell_type, mark: row.mark]
            tuple(meta, file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true))
        }

    ALIGN(ch_reads)
    FILTER_BAM(ALIGN.out.bam)
}
