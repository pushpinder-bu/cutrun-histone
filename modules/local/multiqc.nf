// MULTIQC: Aggregate QC reports from all samples into one MultiQC report

process MULTIQC {
    label 'process_low'
    container 'community.wave.seqera.io/library/multiqc:1.35--c17fb751507e9dfc'
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
