// MULTIQC: Aggregate QC reports from all samples into one MultiQC report

process MULTIQC {
    label 'process_low'
    // Singularity/Apptainer: pre-built Singularity image; Docker: the matching Docker image (same build, as in nf-core modules)
    container "${ workflow.containerEngine in ['singularity', 'apptainer']
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c8/c8e346f4f6080eadf1253505e6ff09ef004454fc18e8d672006fd7b222cc412e/data'
        : 'community.wave.seqera.io/library/multiqc:1.35--c17fb751507e9dfc' }"
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
