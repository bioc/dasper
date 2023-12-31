#' Processing coverage
#'
#' @description The set of functions prefixed with "coverage_" are used to
#'   process coverage data. They are designed to be run after you have processed
#'   your junctions in the order `coverage_norm`, `coverage_score`. Or,
#'   alternatively the wrapper function `coverage_process` can be used to run
#'   the 2 functions stated above in one go. For more details of the individual
#'   functions, see "Details".
#'
#' @details `coverage_process` wraps all "coverage_" prefixed functions in
#'   [dasper]. This is designed to simplify processing of the coverage data for
#'   those familiar or uninterested with the intermediates.
#'
#'   `coverage_norm` obtains regions of interest for each junction where
#'   coverage disruptions would be expected. These consist of the intron itself
#'   the overlapping exon definitions (if ends of junctions are annotated),
#'   picking the shortest exon when multiple overlap one end. If ends are
#'   unannotated, `coverage_norm` will use a user-defined width set by
#'   `unannot_width`. Then, coverage will be loaded using
#'   \href{https://github.com/ChristopherWilks/megadepth}{megadepth} and
#'   normalised to a set region per junction.  By default, the boundaries of
#'   each gene associated to a junction are used as the region to normalise to.
#'
#'   `coverage_score` will score disruptions in the coverage across the
#'   intronic/exonic regions associated with each junction. This abnormality
#'   score generated by `score_func` operates by calculating the deviation of
#'   the coverage in patients to a coverage across the same regions in controls.
#'   Then, for each junction it obtains the score of the region with the
#'   greatest disruption.
#'
#' @inheritParams junction_annot
#' @inheritParams junction_score
#'
#' @param unannot_width integer scalar determining the width of the region to
#'   obtain coverage from when the end of of a junction does not overlap an
#'   existing exon.
#' @param coverage_paths_case paths to the BigWig files containing the coverage
#'   of your case samples.
#' @param coverage_paths_control paths to the BigWig files for control samples.
#' @param coverage_chr_control either "chr" or "no_chr", indicating the
#'   chromosome format of control coverage data. Only required if the
#'   chromosome format of the control BigWig files is different to that of your
#'   cases.
#' @param load_func a function to use to load coverage. Currently only for
#'   internal use to increase testing speed.
#' @param bp_param a
#'   [BiocParallelParam-class][BiocParallel::BiocParallelParam-class] instance
#'   denoting whether to parallelise the loading of coverage across BigWig
#'   files.
#' @param norm_const numeric scaler to add to the normalisation coverage to
#'   avoid dividing by 0s and resulting NaN or Inf values.
#' @param coverage list containing normalised coverage data that is outputted
#'   from [coverage_norm].
#'
#' @return
#'   junctions as
#'   [SummarizedExperiment][SummarizedExperiment::SummarizedExperiment-class]
#'   object with additional `assays` named "coverage_region" and
#'   "coverage_score". "coverage_region" labels the region of greatest
#'   disruption (1 = exon_start, 2 = exon_end, 3 = intron) and "coverage_score"
#'   contains the abnormality scores of the region with the greatest disruption.
#'
#' @examples
#'
#' ##### Set up txdb #####
#'
#' # use GenomicState to load txdb (GENCODE v31)
#' ref <- GenomicState::GenomicStateHub(
#'     version = "31",
#'     genome = "hg38",
#'     filetype = "TxDb"
#' )[[1]]
#'
#' ##### Set up BigWig #####
#'
#' # obtain path to example bw on recount2
#' bw_path <- recount::download_study(
#'     project = "SRP012682",
#'     type = "samples",
#'     download = FALSE
#' )[[1]]
#' \dontshow{
#' # cache the bw for speed in later
#' # examples/testing during R CMD Check
#' bw_path <- dasper:::.file_cache(bw_path)
#' }
#'
#' ##### junction_process #####
#'
#' junctions_processed <- junction_process(
#'     junctions_example,
#'     ref,
#'     types = c("ambig_gene", "unannotated"),
#' )
#'
#' ##### install megadepth #####
#'
#' # required to load coverage in coverage_norm()
#' megadepth::install_megadepth(force = FALSE)
#'
#' ##### coverage_norm #####
#'
#' coverage_normed <- coverage_norm(
#'     junctions_processed,
#'     ref,
#'     unannot_width = 20,
#'     coverage_paths_case = rep(bw_path, 2),
#'     coverage_paths_control = rep(bw_path, 2)
#' )
#'
#' ##### coverage_score #####
#'
#' junctions <- coverage_score(junctions_processed, coverage_normed)
#'
#' ##### coverage_process #####
#'
#' # this wrapper will obtain coverage scores identical to those
#' # obtained through running the individual wrapped functions shown below
#' junctions_w_coverage <- coverage_process(
#'     junctions_processed,
#'     ref,
#'     coverage_paths_case = rep(bw_path, 2),
#'     coverage_paths_control = rep(bw_path, 3)
#' )
#'
#' # the two objects are equivalent
#' all.equal(junctions_w_coverage, junctions, check.attributes = FALSE)
#' @export
coverage_process <- function(junctions,
    ref,
    unannot_width = 20,
    coverage_paths_case,
    coverage_paths_control,
    coverage_chr_control = NULL,
    load_func = .coverage_load,
    bp_param = BiocParallel::SerialParam(),
    norm_const = 1,
    score_func = .zscore,
    ...) {
    print("# Loading and normalising coverage ---------------------------------------------")

    coverage <- coverage_norm(junctions,
        ref,
        unannot_width = 20,
        coverage_paths_case = coverage_paths_case,
        coverage_paths_control = coverage_paths_control,
        coverage_chr_control = NULL,
        load_func = load_func,
        bp_param = bp_param,
        norm_const = norm_const
    )

    print("# Scoring coverage ---------------------------------------------")

    junctions <- coverage_score(junctions, coverage, score_func, ...)

    return(junctions)
}
