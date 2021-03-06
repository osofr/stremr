% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/helper_routines.R
\name{get_wtsummary}
\alias{get_wtsummary}
\title{IP-Weights Summary Tables}
\usage{
get_wtsummary(
  wts_data,
  cutoffs = c(0, 0.5, 1, 10, 20, 30, 40, 50, 100, 150),
  varname = "Stabilized IPAW",
  by.rule = FALSE,
  stabilize = FALSE
)
}
\arguments{
\item{wts_data}{Either a list of data.table containing weights (one for each separate regimen/intervention) or a single data.table with
weights for one regimen / intervention.}

\item{cutoffs}{Weight cut off points for summary tables.}

\item{varname}{Character string describing the type of the weights}

\item{by.rule}{Can optionally evaluate the same summary tables separately for each regimen / rule.}

\item{stabilize}{Set to \code{TRUE} to return stabilized weights summary, otherwise unstabilized weights are used (default).}
}
\value{
A list with various IP-weights summary tables.
}
\description{
Produces various table summaries of IP-Weights.
}
\seealso{
\code{\link{getIPWeights}} for evaluation of IP-weights.
}
