#-----------------------------------------------------------------------------
# DataStorageClass CLASS STRUCTURE:
#-----------------------------------------------------------------------------
# Creates and stores the combined summary measure matrix (sW,sA) in DataStorageClass class;
# Contains Methods for:
  # *) detecting sVar types (detect.col.types);
  # *) defining interval cuttoffs for continuous sVar (define.intervals)
  # *) turning continuous sVar into categorical (discretize.sVar)
  # *) creating binary indicator matrix for continous/categorical sVar (binirize.sVar, binirize.cat.sVar)
  # *) creating design matrix (Xmat) based on predvars and row subsets (evalsubst)

## ---------------------------------------------------------------------
# Detecting vector types: sVartypes <- list(bin = "binary", cat = "categor", cont = "contin")
## ---------------------------------------------------------------------
detect.col.types <- function(sVar_mat){
  detect_vec_type <- function(vec) {
    vec_nomiss <- vec[!gvars$misfun(vec)]
    nvals <- length(unique(vec_nomiss))
    if (nvals <= 2L) {
      sVartypes$bin
    } else if ((nvals <= maxncats) && (is.integerish(vec_nomiss))) {
      sVartypes$cat
    } else {
      sVartypes$cont
    }
  }
  assert_that(is.integerish(getopt("maxncats")) && getopt("maxncats") > 1)
  maxncats <- getopt("maxncats")
  sVartypes <- gvars$sVartypes

  if (is.matrix(sVar_mat)) { # for matrix:
    return(as.list(apply(sVar_mat, 2, detect_vec_type)))
  } else if (is.data.table(sVar_mat)) { # for data.table:
    return(as.list(sVar_mat[, lapply(.SD, detect_vec_type)]))
  } else {
    stop("unrecognized sVar_mat class: " %+% class(sVar_mat))
  }
}

## ---------------------------------------------------------------------
# Normalizing / Defining bin intervals / Converting contin. to ordinal / Converting ordinal to bin indicators
## ---------------------------------------------------------------------
normalize <- function(x) {
  if (abs(max(x) - min(x)) > gvars$tolerr) { # Normalize to 0-1 only when x is not constant
    return((x - min(x)) / (max(x) - min(x)))
  } else {  # What is the thing to do when x constant? Set to abs(x), abs(x)/x or 0???
    return(x)
  }
}
# Define bin cutt-offs for continuous x:
define.intervals <- function(x, nbins, bin_bymass, bin_bydhist, max_nperbin) {
  x <- x[!gvars$misfun(x)]  # remove missing vals
  nvals <- length(unique(x))
  if (is.na(nbins)) nbins <- as.integer(length(x) / max_nperbin)
  # if nbins is too high, for ordinal, set nbins to n unique obs and cancel quantile based interval defns
  if (nvals < nbins) {
    nbins <- nvals
    bin_bymass <- FALSE
  }
  if (abs(max(x) - min(x)) > gvars$tolerr) {  # when x is not constant
    if ((bin_bymass) & !is.null(max_nperbin)) {
      if ((length(x) / max_nperbin) > nbins) nbins <- as.integer(length(x) / max_nperbin)
    }
    intvec <- seq.int(from = min(x), to = max(x) + 1, length.out = (nbins + 1)) # interval type 1: bin x by equal length intervals of 0-1
  } else {  # when x is constant, force the smallest possible interval to be at least [0,1]
    intvec <- seq.int(from = min(0L, min(x)), to = max(1L, max(x)), length.out = (nbins + 1))
  }
  if (bin_bymass) {
    intvec <- quantile(x = x, probs = normalize(intvec)) # interval type 2: bin x by mass (quantiles of 0-1 intvec as probs)
    intvec[1] <- intvec[1] - 0.01
    intvec[length(intvec)] <- intvec[length(intvec)] + 0.01
  } else if (bin_bydhist) {
    intvec <- dhist(x, plot = FALSE, nbins = nbins)$xbr
    intvec[1] <- intvec[1] - 0.01
    intvec[length(intvec)] <- intvec[length(intvec)] + 0.01
  }
  # adding -Inf & +Inf as leftmost & rightmost cutoff points to make sure all future data points end up in one of the intervals:
  intvec <- c(min(intvec)-1000L, intvec, max(intvec)+1000L)
  return(intvec)
}
# Turn any x into ordinal (1, 2, 3, ..., nbins) for a given interval cutoffs (length(intervals)=nbins+1)
make.ordinal <- function(x, intervals) findInterval(x = x, vec = intervals, rightmost.closed = TRUE)
# Make dummy indicators for ordinal x (sA[j]) Approach used: creates B_j that jumps to 1 only once and stays 1 (degenerate) excludes reference category (last)
make.bins_mtx_1 <- function(x.ordinal, nbins, bin.nms, levels = 1:nbins) {
  n <- length(x.ordinal)
  new.cats <- 1:nbins
  dummies_mat <- matrix(1L, nrow = n, ncol = length(new.cats))
  for(cat in new.cats[-length(new.cats)]) {
    subset_Bj0 <- x.ordinal > levels[cat]
    dummies_mat[subset_Bj0, cat] <- 0L
    subset_Bjmiss <- x.ordinal < levels[cat]
    dummies_mat[subset_Bjmiss, cat] <- gvars$misval
  }
  dummies_mat[, new.cats[length(new.cats)]] <- gvars$misval
  colnames(dummies_mat) <- bin.nms
  dummies_mat
}

## ---------------------------------------------------------------------
#' R6 class for storing, managing, subsetting and manipulating the input data.
#'
#'  The class \code{DataStorageClass} is the only way the package uses to access the input data.
#'  The evaluated summary measures from sVar.object are stored as a matrix (private$.mat.sVar).
#'  Contains methods for replacing missing values with default in gvars$misXreplace.
#'  Also contains method for detecting / setting sVar variable type (binary, categor, contin).
#'  Contains methods for combining, subsetting, discretizing & binirizing summary measures \code{(sW,sA)}.
#'  For continous sVar this class provides methods for detecting / setting bin intervals,
#'  normalization, disretization and construction of bin indicators.
#'  The pointers to this class get passed on to \code{SummariesModel} functions: \code{$fit()},
#'  \code{$predict()} and \code{$predictAeqa()}.
#'
#' @docType class
#' @format An \code{\link{R6Class}} generator object
#' @keywords R6 class
#' @details
#' #' \itemize{
#'    \item{\code{YnodeVals}}
#'    \item{\code{det.Y}}
#' }
#' @section Methods:
#' \describe{
#'   \item{\code{new(Odata, nodes, YnodeVals, det.Y, ...)}}{...}
#'   \item{\code{def.types.sVar(type.sVar = NULL)}}{...}
#'   \item{\code{fixmiss_sVar()}}{...}
#'   \item{\code{set.sVar(name.sVar, new.type)}}{...}
#'   \item{\code{set.sVar.type(name.sVar, new.type)}}{...}
#'   \item{\code{get.sVar(name.sVar, new.sVarVal)}}{...}
#'   \item{\code{replaceOneAnode(AnodeName, newAnodeVal)}}{...}
#'   \item{\code{replaceManyAnodes(Anodes, newAnodesMat)}}{...}
#'   \item{\code{addYnode(YnodeVals, det.Y)}}{...}
#'   \item{\code{evalsubst(subsetexpr, subsetvars)}}{...}
#'   \item{\code{get.dat.sVar(rowsubset = TRUE, covars)}}{...}
#'   \item{\code{get.outvar(rowsubset = TRUE, var)}}{...}
#'   \item{\code{bin.nms.sVar(name.sVar, nbins)}}{...}
#'   \item{\code{pooled.bin.nm.sVar(name.sVar)}}{...}
#'   \item{\code{detect.sVar.intrvls(name.sVar, nbins, bin_bymass, bin_bydhist, max_nperbin)}}{...}
#'   \item{\code{detect.cat.sVar.levels(name.sVar)}}{...}
#'   \item{\code{binirize.sVar(name.sVar, ...)}}{...}
#'   \item{\code{get.sVar.bw(name.sVar, intervals)}}{...}
#'   \item{\code{get.sVar.bwdiff(name.sVar, intervals)}}{...}
#' }
#' @section Active Bindings:
#' \describe{
#'    \item{\code{nobs}}{...}
#'    \item{\code{ncols.sVar}}{...}
#'    \item{\code{names.sVar}}{...}
#'    \item{\code{type.sVar}} - Named list of length \code{ncol(private$.mat.sVar)} with \code{sVar} variable types: "binary"/"categor"/"contin".
#'    \item{\code{dat.sVar}}{...}
#'    \item{\code{ord.sVar}} - Ordinal (categorical) transformation of a continous covariate \code{sVar}.
#'    \item{\code{active.bin.sVar}} - Name of active binarized cont sVar, changes as fit/predict is called (bin indicators are temp. stored in private$.mat.bin.sVar)
#'    \item{\code{dat.bin.sVar}}{...}
#'    \item{\code{emptydat.sVar}}{...}
#'    \item{\code{emptydat.bin.sVar}}{...}
#'    \item{\code{noNA.Ynodevals}}{...}
#'    \item{\code{nodes}}{...}
#' }
#' @importFrom assertthat assert_that is.count is.flag
#' @export
DataStorageClass <- R6Class(classname = "DataStorageClass",
  portable = TRUE,
  class = TRUE,
  public = list(
    noCENS.cat = 0L,        # The level (integer) that indicates CONTINUATION OF FOLLOW-UP for ALL censoring variables
    YnodeVals = NULL,       # Values of the binary outcome (Ynode) in observed data where det.Y = TRUE obs are set to NA
    det.Y = NULL,           # Logical vector, where YnodeVals[det.Y==TRUE] are deterministic (0 or 1)
    curr_data_A_g0 = TRUE,  # is the current data in OdataDT generated under observed (g0)? If FALSE, current data is under g.star (intervention)

    initialize = function(Odata, nodes, YnodeVals, det.Y, noCENS.cat,...) {
      assert_that(is.data.frame(Odata) | is.data.table(Odata))
      self$curr_data_A_g0 <- TRUE

      self$dat.sVar <- data.table(Odata) # makes a copy of the input data (shallow)
      # alternative is to set it without copying Odata
      # setDT(Odata); self$dat.sVar <- Odata

      if (!missing(noCENS.cat)) self$noCENS.cat <- noCENS.cat

      if (!missing(nodes)) self$nodes <- nodes

      if (!missing(YnodeVals)) self$addYnode(YnodeVals = YnodeVals, det.Y = det.Y)

      self$def.types.sVar() # Define the type of each sVar[i]: bin, cat or cont

      invisible(self)
    },

    # add protected Y nodes to private field and set to NA all determinisitc Y values for public field YnodeVals
    addYnode = function(YnodeVals, det.Y) {
        if (missing(det.Y)) det.Y <- rep.int(FALSE, length(YnodeVals))
        self$noNA.Ynodevals <- YnodeVals  # Adding actual observed Y as protected (without NAs)
        self$YnodeVals <- YnodeVals
        self$YnodeVals[det.Y] <- NA       # Adding public YnodeVals & setting det.Y values to NA
        self$det.Y <- det.Y
    },

    # ---------------------------------------------------------------------
    # Eval the subsetting expression (in the environment of the data.table "data" + global constants "gvars"):
    # ---------------------------------------------------------------------
    # Could also do evaluation in a special env with a custom subsetting fun '[' that will dynamically find the correct dataset that contains
    # sVar.name (dat.sVar or dat.bin.sVar) and will return sVar vector
    evalsubst = function(subsetexpr, subsetvars) {
      if (missing(subsetexpr)) {
        assert_that(!missing(subsetvars))
        res <- rep.int(TRUE, self$nobs)
        for (subsetvar in subsetvars) {
          # *) find the var of interest (in self$dat.sVar or self$dat.bin.sVar), give error if not found
          sVar.vec <- self$get.outvar(var = subsetvar)
          assert_that(!is.null(sVar.vec))
          # *) reconstruct correct expression that tests for missing values
          res <- res & (!gvars$misfun(sVar.vec))
        }
        return(res)
      # ******************************************************
      # NOTE: Below is currently not being used, all subsetting now is done with subsetvars above, for speed & memory efficiency
      # ******************************************************
      } else {
        if (is.logical(subsetexpr)) {
          return(subsetexpr)
        } else {
          res <- self$dat.sVar[, eval(parse(text = subsetexpr)), by = get(self$nodes$ID)][["V1"]]
          assert_that(is.logical(res))
          browser()

          # ******************************************************
          # THIS WAS A BOTTLENECK: for 500K w/ 1000 bins: 4-5sec
          # REPLACING WITH env that is made of data.frames instead of matrices
          # ******************************************************
          # eval.env <- c(data.frame(self$dat.sVar), data.frame(self$dat.bin.sVar), as.list(gvars))
          # res <- try(eval(subsetexpr, envir = eval.env, enclos = baseenv())) # to evaluate vars not found in data in baseenv()
          # self$dat.sVar[eval(),]
          # stop("disabled for memory/speed efficiency")
          return(res)
        }
      }
    },

    # ---------------------------------------------------------------------
    # Functions for subsetting/returning covariate design mat for BinOutModelClass or outcome variable
    # ---------------------------------------------------------------------
    get.dat.sVar = function(rowsubset = TRUE, covars) {
      if (!missing(covars)) {
        if (length(unique(colnames(self$dat.sVar))) < length(colnames(self$dat.sVar))) {
          warning("repeating column names in the final data set; please check for duplicate summary measure / node names")
        }
        # columns to select from main design matrix (in the same order as listed in covars):
        sel.sWsA <- intersect(covars, colnames(self$dat.sVar))
        if (is.matrix(self$dat.sVar)) {
          dfsel <- self$dat.sVar[rowsubset, sel.sWsA, drop = FALSE] # data stored as matrix
        } else if (is.data.table(self$dat.sVar)) {
          dfsel <- self$dat.sVar[rowsubset, sel.sWsA, drop = FALSE, with = FALSE] # data stored as data.table
        } else {
          stop("self$dat.sVar is of unrecognized class: " %+% class(self$dat.sVar))
        }
        # columns to select from binned continuous/cat var matrix (if it was previously constructed):
        if (!is.null(self$dat.bin.sVar)) {
          sel.binsA <- intersect(covars, colnames(self$dat.bin.sVar))
        } else {
          sel.binsA <- NULL
        }
        if (length(sel.binsA)>0) {
          dfsel <- cbind(dfsel, self$dat.bin.sVar[rowsubset, sel.binsA, drop = FALSE])
        }
        found_vars <- covars %in% colnames(dfsel)
        if (!all(found_vars)) stop("some covariates can't be found (perhaps not declared as summary measures (def_sW(...) or def_sW(...))): "%+%
                                    paste(covars[!found_vars], collapse=","))
        return(dfsel)
      } else {
        return(self$dat.sVar[rowsubset, , drop = FALSE])
      }
    },
    get.outvar = function(rowsubset = TRUE, var) {
      if (length(self$nodes) < 1) stop("DataStorageClass$nodes list is empty!")
      if (var %in% self$names.sVar) {
        out <- self$dat.sVar[rowsubset, var, with = FALSE]
      } else if (var %in% colnames(self$dat.bin.sVar)) {
        out <- self$dat.bin.sVar[rowsubset, var]
      } else if ((var %in% self$nodes$Ynode) && !is.null(self$YnodeVals)) {
        out <- self$YnodeVals[rowsubset]
      } else {
        stop("requested variable " %+% var %+% " does not exist in DataStorageClass!")
      }
      if ((is.list(out) || is.data.table(out)) && (length(out)>1)) {
        stop("selecting regression outcome covariate resulted in more than one column: " %+% var)
      } else if (is.list(out) || is.data.table(out)) {
        return(out[[1]])
      } else {
        return(out)
      }
    },

    # --------------------------------------------------
    # Create a matrix of dummy bin indicators for categorical/continuous sVar
    # --------------------------------------------------
    binirize.sVar = function(name.sVar, ...) {
      private$.active.bin.sVar <- name.sVar
      if (self$is.sVar.cont(name.sVar)) {
        private$binirize.cont.sVar(name.sVar, ...)
      } else if (self$is.sVar.cat(name.sVar)) {
        private$binirize.cat.sVar(name.sVar, ...)
      } else {
        stop("...can only call $binirize.sVar for continuous or categorical sVars...")
      }
    },

    # ------------------------------------------------------------------------------------------------------------
    # Binning methods for categorical/continuous sVar
    # ------------------------------------------------------------------------------------------------------------
    bin.nms.sVar = function(name.sVar, nbins) { name.sVar%+%"_"%+%"B."%+%(1L:nbins) }, # Return names of bin indicators for sVar:
    pooled.bin.nm.sVar = function(name.sVar) { name.sVar %+% "_allB.j" },
    detect.sVar.intrvls = function(name.sVar, nbins, bin_bymass, bin_bydhist, max_nperbin) {
      tol.int <- 0.001
      int <- define.intervals(x = self$get.sVar(name.sVar), nbins = nbins, bin_bymass = bin_bymass, bin_bydhist = bin_bydhist, max_nperbin = max_nperbin)
      diffvec <- diff(int)
      if (sum(abs(diffvec) < tol.int) > 0) {
        if (gvars$verbose) {
          message("No. of categories for " %+% name.sVar %+% " was collapsed from " %+%
                  (length(int)-1) %+% " to " %+% (length(int[diffvec >= tol.int])-1) %+% " due to too few obs.")
          print("old intervals: "); print(as.numeric(int))
        }
        # Just taking unique interval values is insufficient
        # Instead need to drop all intervals that are "too close" to each other based on some tol value
        # remove all intervals (a,b) where |b-a| < tol.int, but always keep the very first interval (int[1])
        int <- c(int[1], int[2:length(int)][abs(diffvec) >= tol.int])
        if (gvars$verbose) print("new intervals: "); print(as.numeric(int))
      }
      return(int)
    },
    detect.cat.sVar.levels = function(name.sVar) {
      levels <- sort(unique(self$get.sVar(name.sVar)))
      return(levels)
    },
    # return the bin widths vector for the discretized continuous sVar (private$.ord.sVar):
    get.sVar.bw = function(name.sVar, intervals) {
      if (!(self$active.bin.sVar %in% name.sVar)) stop("current discretized sVar name doesn't match name.sVar in get.sVar.bin.widths()")
      if (is.null(self$ord.sVar)) stop("sVar hasn't been discretized yet")
      intrvls.width <- diff(intervals)
      intrvls.width[intrvls.width <= gvars$tolerr] <- 1
      ord.sVar_bw <- intrvls.width[self$ord.sVar]
      return(ord.sVar_bw)
    },
   # return the bin widths vector for the discretized continuous sVar (self$ord.sVar):
    get.sVar.bwdiff = function(name.sVar, intervals) {
      if (!(self$active.bin.sVar %in% name.sVar)) stop("current discretized sVar name doesn't match name.sVar in get.sVar.bin.widths()")
      if (is.null(self$ord.sVar)) stop("sVar hasn't been discretized yet")
      ord.sVar_leftint <- intervals[self$ord.sVar]
      diff_bw <- self$get.sVar(name.sVar) - ord.sVar_leftint
      return(diff_bw)
    },

    # --------------------------------------------------
    # Replace all missing (NA) values with a default integer (0)
    # --------------------------------------------------
    fixmiss_sVar = function() {
      if (is.matrix(self$dat.sVar)) {
        private$fixmiss_sVar_mat()
      } else if (is.data.table(self$dat.sVar)) {
        private$fixmiss_sVar_DT()
      } else {
        stop("self$dat.sVar is of unrecognized class")
      }
    },

    # --------------------------------------------------
    # Methods for sVar types. Define the type (class) of each variable (sVar) in input data: gvars$sVartypes$bin,  gvars$sVartypes$cat or gvars$sVartypes$cont
    # --------------------------------------------------
    # type.sVar acts as a flag: only detect types when !is.null(type.sVar), otherwise can pass type.sVar = list(sVar = NA, ...) or a value type.sVar = NA/gvars$sVartypes$bin/etc
    def.types.sVar = function(type.sVar = NULL) {
      if (is.null(type.sVar)) {
        private$.type.sVar <- detect.col.types(self$dat.sVar)
      } else {
        n.sVar <- length(self$names.sVar)
        len <- length(type.sVar)
        assert_that((len == n.sVar) || (len == 1L))
        if (len == n.sVar) { # set types for each variable
          assert_that(is.list(type.sVar))
          assert_that(all(names(type.sVar) %in% self$names.sVar))
        } else { # set one type for all vars
          assert_that(is.string(type.sVar))
          type.sVar <- as.list(rep(type.sVar, n.sVar))
          names(type.sVar) <- self$names.sVar
        }
        private$.type.sVar <- type.sVar
      }
      invisible(self)
    },
    set.sVar.type = function(name.sVar, new.type) { private$.type.sVar[[name.sVar]] <- new.type },
    get.sVar.type = function(name.sVar) { if (missing(name.sVar)) { private$.type.sVar } else { private$.type.sVar[[name.sVar]] } },
    is.sVar.bin = function(name.sVar) { self$get.sVar.type(name.sVar) %in% gvars$sVartypes$bin },
    is.sVar.cat = function(name.sVar) { self$get.sVar.type(name.sVar) %in% gvars$sVartypes$cat },
    is.sVar.cont = function(name.sVar) { self$get.sVar.type(name.sVar) %in% gvars$sVartypes$cont },

    # ---------------------------------------------------------------------
    # Directly replace variable(s) in the storage data.table (by reference)
    # ---------------------------------------------------------------------
    get.sVar = function(name.sVar) {
      x <- self$dat.sVar[, name.sVar, with=FALSE]
      if (is.list(x) || is.data.table(x) || is.data.frame(x)) x <- x[[1]]
      return(x)
    },
    set.sVar = function(name.sVar, new.sVarVal) {
      assert_that(is.integer(new.sVarVal) | is.numeric(new.sVarVal))
      assert_that(length(new.sVarVal)==self$nobs | length(new.sVarVal)==1)
      assert_that(name.sVar %in% colnames(self$dat.sVar))
      self$dat.sVar[, (name.sVar) := new.sVarVal]
      invisible(self)
    },
    replaceOneAnode = function(AnodeName, newAnodeVal) {
      self$set.sVar(AnodeName, newAnodeVal)
      invisible(self)
    },
    replaceManyAnodes = function(Anodes, newAnodesMat) {
      assert_that(is.matrix(newAnodesMat))
      assert_that(ncol(newAnodesMat) == length(Anodes))
      for (col in Anodes) {
        idx <- which(Anodes %in% col)
        assert_that(col %in% colnames(newAnodesMat))
        assert_that(col %in% colnames(self$dat.sVar))
        self$dat.sVar[, (col) := newAnodesMat[, idx]]
      }
      invisible(self)
    },
    # ---------------------------------------------------------------------------
    # Cast long format data into wide format:
    # bslcovars - names of covariates that shouldn't be cast (remain invariant with t)
    # ---------------------------------------------------------------------------
    convert.to.wide = function(bslcovars) {
      # dt = rbind(data.table(ID=1, x=sample(5,20,TRUE), y = sample(5,20,TRUE), t=1:20), data.table(ID=2, x=sample(5,15,TRUE), y = sample(5,15,TRUE), t=1:15))
      # dcast(dt, formula="ID ~ t", value.var=c("x", "y"), sep="_")
      nodes <- self$nodes
      cast.vars <- c(nodes$Lnodes,nodes$Cnodes, nodes$Anodes, nodes$Nnodes, nodes$Ynode)
      if (!missing(bslcovars)) cast.vars <- setdiff(cast.vars, bslcovars)
      odata_wide <- dcast(self$dat.sVar, formula = nodes$ID %+% " ~ " %+% nodes$tnode, value.var = cast.vars)
    return(odata_wide)
    }

  ),
  active = list(
    nobs = function() { nrow(self$dat.sVar) },
    names.sVar = function() { colnames(self$dat.sVar) },
    ncols.sVar = function() { length(self$names.sVar) },

    dat.sVar = function(dat.sVar) {
      if (missing(dat.sVar)) {
        return(private$.mat.sVar)
      } else {
        assert_that(is.matrix(dat.sVar) | is.data.table(dat.sVar))
        private$.mat.sVar <- dat.sVar
      }
    },

    dat.bin.sVar = function(dat.bin.sVar) {
      if (missing(dat.bin.sVar)) {
        return(private$.mat.bin.sVar)
      } else {
        assert_that(is.matrix(dat.bin.sVar))
        private$.mat.bin.sVar <- dat.bin.sVar
      }
    },

    emptydat.sVar = function() { private$.mat.sVar <- NULL },         # wipe out mat.sVar
    # wipe out binirized .mat.sVar:
    emptydat.bin.sVar = function() {
      private$.mat.bin.sVar <- NULL
      private$.active.bin.sVar <- NULL
    },

    noNA.Ynodevals = function(noNA.Yvals) {
      if (missing(noNA.Yvals)) return(private$.protected.YnodeVals)
      else private$.protected.YnodeVals <- noNA.Yvals
    },

    nodes = function(nodes) {
      if (missing(nodes)) {
        return(private$.nodes)
      } else {
        assert_that(is.list(nodes))
        private$.nodes <- nodes
      }
    },

    active.bin.sVar = function() { private$.active.bin.sVar },
    ord.sVar = function() { private$.ord.sVar },
    type.sVar = function() { private$.type.sVar }

  ),
  private = list(
    .nodes = list(),              # names of the nodes in the data (Anode, Ynode, etc..)
    .protected.YnodeVals = NULL,  # Actual observed values of the binary outcome (Ynode), along with deterministic vals
    .mat.sVar = NULL,             # Data.table storing all evaluated sVars, with named columns
    .active.bin.sVar = NULL,      # Name of active binarized cont sVar, changes as fit/predict is called (bin indicators are temp. stored in mat.bin.sVar)
    .mat.bin.sVar = NULL,         # Temporary storage mat for bin indicators on currently binarized continous sVar (from private$.active.bin.sVar)
    .ord.sVar = NULL,             # Ordinal (cat) transform for continous sVar
    # sVar.object = NULL,         # DefineSummariesClass object that contains / evaluates sVar expressions
    .type.sVar = NULL,            # Named list with sVar types: list(names.sVar[i] = "binary"/"categor"/"contin"), can be overridden
    # Replace all missing (NA) values with a default integer (0) for matrix
    fixmiss_sVar_mat = function() {
      self$dat.sVar[gvars$misfun(self$dat.sVar)] <- gvars$misXreplace
      invisible(self)
    },
    # Replace all missing (NA) values with a default integer (0) for data.table
    fixmiss_sVar_DT = function() {
      # see http://stackoverflow.com/questions/7235657/fastest-way-to-replace-nas-in-a-large-data-table
      dat.sVar <- self$dat.sVar
      for (j in names(dat.sVar))
        set(dat.sVar, which(gvars$misfun(dat.sVar[[j]])), j , gvars$misXreplace)
      invisible(self)
    },
    # create a vector of ordinal (categorical) vars out of cont. sVar vector:
    discretize.sVar = function(name.sVar, intervals) {
      private$.ord.sVar <- make.ordinal(x = self$get.sVar(name.sVar), intervals = intervals)
      invisible(private$.ord.sVar)
    },
    # Create a matrix of bin indicators for continuous sVar:
    binirize.cont.sVar = function(name.sVar, intervals, nbins, bin.nms) {
      self$dat.bin.sVar <- make.bins_mtx_1(x.ordinal = private$discretize.sVar(name.sVar, intervals), nbins = nbins, bin.nms = bin.nms)
      invisible(self$dat.bin.sVar)
    },
    # Create a matrix of bin indicators for ordinal sVar:
    binirize.cat.sVar = function(name.sVar, levels) {
      nbins <- length(levels)
      bin.nms <- self$bin.nms.sVar(name.sVar, nbins)
      self$dat.bin.sVar <- make.bins_mtx_1(x.ordinal = self$get.sVar(name.sVar), nbins = nbins, bin.nms = bin.nms, levels = levels)
      invisible(self$dat.bin.sVar)
    }
  )
)

## ---------------------------------------------------------------------
## For networks can just expand on the basic DataStorage class and add appropriate network-related fields:
## ---------------------------------------------------------------------
#' R6 class for storing, managing, subsetting and manipulating the input data for networks.
#'
#' @docType class
#' @format An \code{\link{R6Class}} generator object
#' @keywords R6 class
#' @details
#' #' \itemize{
#' \item{\code{sW}} - Baseline summaries
#' \item{\code{sA}} - Exposure summaries
#' \item{\code{intervene1.sA}} - Intervention object 1
#' \item{\code{intervene2.sA}} - Intervention object 2
#' }
#' @section Methods:
#' \describe{
#'   \item{\code{new(Odata, nodes, YnodeVals, det.Y, ...)}}{...}
#'   \item{\code{make.sVar(type.sVar = NULL)}}{...}
#' }
#' @section Active Bindings:
#' \describe{
#'    \item{\code{save_sA_Vars}}{...}
#'    \item{\code{restored_sA_Vars}}{...}
#' }
DatNetStorageClass <- R6Class(classname = "DatNetStorageClass",
  inherit = DataStorageClass,
  portable = TRUE,
  class = TRUE,
  public = list(
    Kmax = integer(),          # max n of Friends in the network
    nFnode = "nF",
    netind_cl = NULL,          # class NetIndClass object holding $NetInd_k network matrix
    sW = NULL,
    sA = NULL,
    intervene1.sA = NULL,
    intervene2.sA = NULL,
    sVar.object = NULL,        # DefineSummariesClass object that contains / evaluates sVar expressions

    initialize = function(Odata, nodes, YnodeVals, det.Y, netind_cl, nFnode, ...) {
      self$netind_cl <- netind_cl
      self$Kmax <- netind_cl$Kmax
      if (!missing(nFnode)) self$nFnode <- nFnode
      super$initialize(Odata, nodes, YnodeVals, det.Y, ...)
      invisible(self)
    },

    ## ---------------------------------------------------------------------
    # Define and evalute summary measure (sVar) data; Save it (and over-write prev. values) as self$dat.sVar
    ## ---------------------------------------------------------------------
    make.sVar = function(Odata, sVar.object = NULL, type.sVar = NULL) {
      if (missing(Odata)) {
        assert_that(!is.null(self$Odata))
      } else {
        self$Odata <- Odata
      }
      if (is.null(sVar.object)) {
        stop("Not Implemented. To Be replaced with netVar construction when sVar.object is null...")
      }
      self$sVar.object <- sVar.object
      self$dat.sVar <- sVar.object$eval.nodeforms(data.df = self$Odata$dat.sVar)
      self$def.types.sVar(type.sVar) # Define the type of each sVar[i]: bin, cat or cont
      invisible(self)
    },

    ## ---------------------------------------------------------------------
    # Save Anodes and summaries sA from main data.table into separate fields
    ## ---------------------------------------------------------------------
    backupAnodes = function(Anodes, sA) {
      if (missing(Anodes)) Anodes <- self$nodes$Anodes
      private$.A_g0_DT <- self$dat.sVar[, Anodes, with = FALSE]
      # Back-up the summary measures as well (to not have to reconstruct them):
      if (!missing(sA)) {
        sA.Vars <- unlist(sA$sVar.names.map)
        private$.save_sA_Vars <- sA.Vars[!sA.Vars%in%Anodes]
        private$.sA_g0_DT <- self$dat.sVar[, private$.save_sA_Vars, with = FALSE]
      }
      invisible(self)
    },

    ## ---------------------------------------------------------------------
    # Put saved Anodes and summaries sA back into main data.table
    ## ---------------------------------------------------------------------
    restoreAnodes = function(Anodes) {
      if (missing(Anodes)) Anodes <- self$nodes$Anodes
      if (is.null(private$.A_g0_DT)) stop("Anodes in dat.sVar cannot be restored, private$.A_g0_DT is null!")
      self$dat.sVar[, (Anodes) := private$.A_g0_DT, with=FALSE]
      if (!is.null(private$.sA_g0_DT) && !is.null(self$save_sA_Vars)) {
        self$dat.sVar[, (self$save_sA_Vars) := private$.sA_g0_DT, with = FALSE]
        private$.restored_sA_Vars <- TRUE
      } else {
        private$.restored_sA_Vars <- FALSE
      }
      invisible(self)
    },

    ## ---------------------------------------------------------------------
    # Swap re-saved Anodes and summaries sA with those in main data.table
    ## ---------------------------------------------------------------------
    swapAnodes = function(Anodes) {
      if (missing(Anodes)) Anodes <- self$nodes$Anodes
      # 1) Save the current values of Anodes and sA in the data:
      temp.Anodes <- self$dat.sVar[, Anodes, with = FALSE]
      if (!is.null(private$.sA_g0_DT) && !is.null(self$save_sA_Vars)) {
        temp.sA <- self$dat.sVar[, self$save_sA_Vars, with = FALSE]
      } else {
        temp.sA <- NULL
      }
      # 2) Restore previously saved Anodes / sA into the data:
      self$restoreAnodes()
      # 3) Over-write the back-up values with new ones:
      private$.A_g0_DT <- temp.Anodes
      private$.sA_g0_DT <- temp.sA
      # 4) Reverse the indicator of current data Anodes:
      self$curr_data_A_g0 <- !self$curr_data_A_g0
      invisible(self)
    }
  ),
  active = list(
    save_sA_Vars = function() { private$.save_sA_Vars },
    restored_sA_Vars = function() { private$.restored_sA_Vars }
  ),

  private = list(
    .A_g0_DT = NULL,              # Backed-up versions of the Anodes vars that come from the observed data
    .sA_g0_DT = NULL,             # Backed-up versions of the summaries in sA (but not Anodes) that come from the observed data
    .save_sA_Vars = NULL,         # Summary measure variables that were pre-saved (backed-up) and were not part of new.sA (Anodes)
    .restored_sA_Vars = FALSE     # Were the summary measures (not Anodes) restored as well? If not, they need to be reconstructed
  )
)