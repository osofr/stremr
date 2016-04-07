#' Estimate the Survival of Intervention on Exposures and MONITORing Process for Right Censored Longitudinal Data.
#'
#' The \pkg{estimtr} R package is a tool for estimation of causal survival curve under various user-specified interventions
#' (e.g., static, dynamic, deterministic, or stochastic).
#' In particular, the interventions may represent exposures to treatment regimens, the occurrence or non-occurrence of right-censoring
#' events, or of clinical monitoring events. \pkg{estimtr} enables estimation of a selected set of the user-specified causal quantities of interest,
#' such as, treatment-specific survival curves and the average risk difference over time.
#'
#' @section Documentation:
#' \itemize{
#' \item To see the package vignette use: \code{vignette("estimtr_vignette", package="estimtr")}
#' \item To see all available package documentation use: \code{help(package = 'estimtr')}
#' }
#'
#' @section Routines:
#' The following routines will be generally invoked by a user, in the same order as presented below.
#' \describe{
#' \item{\code{\link{estimtr}}}{One function for performing estimation}
#' }
#'
#' @section Data structures:
#' The following most common types of output are produced by the package:
#' \itemize{
#' \item \emph{observed data} - input data.frame in long format (repeated measures over time).
#' }
#'
#' @section Updates:
#' Check for updates and report bugs at \url{http://github.com/osofr/estimtr}.
#'
#' @docType package
#' @name estimtr-package
#'
NULL

#' An example of a dataset in long format with categorical censoring variable.
#'
#' Simulated dataset containing 50,000 i.i.d. observations organized in long format as person-time row data.
#' The binary exposure is \code{TI} and binary outcome is \code{Y}. See /tests/RUnit_tests_02_categCENS.R
#' function \code{notrun.save.example.data} for R code that generated this data.
#'
#' @format A data frame with 50,000 observations and variables:
#' \describe{
#'   \item{IDs}{Unique subject identifier}
#'   \item{CVD}{Baseline confounder (time invariant)}
#'   \item{t}{Interger for current time period, range 0-16}
#'   \item{Y}{Binary outcome}
#'   \item{lastNat1}{Time since last monitoring event, set to 0 when N[t-1]=0 and then added one for each new period where N[t] is 0.}
#'   \item{highA1c}{Time-varying confounder}
#'   \item{TI}{Binary exposure variable}
#'   \item{CatC}{Categorical censoring variable, range 0-2. The value of 0 indicates no censoring 1 or 2 indicates censoring (possibly for different reasons)}
#'   \item{C}{Binary censoring indicator derived from CatC. 0 if CatC is 0 and 1 if CatC is 1 or 2.}
#'   \item{N}{The indicator of being monitored (having a visit)}
#' }
#' @docType data
#' @keywords datasets
#' @name OdataCatCENS
#' @usage data(OdataCatCENS)
NULL







