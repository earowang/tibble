#' Subsetting tibbles
#'
#' @description
#' Accessing columns, rows, or cells via `$`, `[[`, or `[` is mostly similar to
#' [regular data frames][base::Extract.data.frame]. However, the
#' behavior is different for tibbles and data frames in some cases:
#' * `[` always returns a tibble by default, even if
#'   only one column is accessed.
#' * Partial matching of column names with `$` and `[[` is not supported, a
#'   warning is given and `NULL` is returned.
#' * Only scalars (vectors of length one) or vectors with the
#'   same length as the number of rows can be used for assignment.
#'
#' Unstable return type and implicit partial matching can lead to surprises and
#' bugs that are hard to catch. If you rely on code that requires the original
#' data frame behavior, coerce to a data frame via [as.data.frame()].
#'
#' @details
#' For better compatibility with older code written for regular data frames,
#' `[` supports a `drop` argument which defaults to `FALSE`.
#' New code should use `[[` to turn a column into a vector.
#'
#' @name subsetting
#' @examples
#' df <- data.frame(a = 1:3, bc = 4:6)
#' tbl <- tibble(a = 1:3, bc = 4:6)
#'
#' # Subsetting single columns:
#' df[, "a"]
#' tbl[, "a"]
#' tbl[, "a", drop = TRUE]
#' as.data.frame(tbl)[, "a"]
#'
#' # Subsetting single rows with the drop argument:
#' df[1, , drop = TRUE]
#' tbl[1, , drop = TRUE]
#' as.list(tbl[1, ])
#'
#' # Accessing non-existent columns:
#' df$b
#' tbl$b
#'
#' df[["b", exact = FALSE]]
#' tbl[["b", exact = FALSE]]
#'
#' df$bd <- c("n", "e", "w")
#' tbl$bd <- c("n", "e", "w")
#' df$b
#' tbl$b
#'
#' df$b <- 7:9
#' tbl$b <- 7:9
#' df$b
#' tbl$b
#'
#' # Identical behavior:
#' tbl[1, ]
#' tbl[1, c("bc", "a")]
#' tbl[, c("bc", "a")]
#' tbl[c("bc", "a")]
#' tbl["a"]
#' tbl$a
#' tbl[["a"]]
NULL

#' @rdname subsetting
#' @param i,j Row and column indices. If `j` is omitted, `i` is used as column index.
#' @param ... Ignored.
#' @param exact Ignored, with a warning.
#' @export
`[[.tbl_df` <- function(x, i, j, ..., exact = TRUE) {
  if (!exact) {
    warningc("exact ignored")
  }
  if (missing(j)) {
    return(.subset2(x, i))
  }

  NextMethod()
}

#' @rdname subsetting
#' @inheritParams base::`[.data.frame`
#' @export
`$.tbl_df` <- function(x, name) {
  if (is.character(name)) {
    ret <- .subset2(x, name)
    if (is.null(ret)) warningc("Unknown or uninitialised column: '", name, "'.")
    return(ret)
  }
  .subset2(x, name)
}

#' @rdname subsetting
#' @param drop Coerce to a vector if fetching one column via `tbl[, j]` .
#'   Default `FALSE`, ignored when accessing a column via `tbl[j]` .
#' @export
`[.tbl_df` <- function(x, i = NULL, j = NULL, drop = FALSE) {
  # Ignore drop as an argument
  n_real_args <- nargs() - !missing(drop)

  # Column subsetting if nargs() == 2L
  if (n_real_args <= 2L) {
    if (!missing(drop)) {
      warningc("drop ignored")
    }

    if (missing(i)) {
      return(x)
    }

    slice_df(x, i = NULL, j = i, drop = FALSE)
  } else {
    slice_df(x, i, j, drop = drop)
  }
}

slice_df <- function(x, i, j, drop) {
  # First, subset columns
  if (is.null(j)) {
    result <- x
  } else {
    j <- check_names_df(j, x)
    result <- new_data_frame(.subset(x, j), n = fast_nrow(x))
  }

  # Next, subset rows
  if (is.null(i)) {
    if (has_length(result)) {
      i <- NULL
    } else {
      i <- seq_len(fast_nrow(x))
    }
  } else {
    nr <- fast_nrow(x)

    if (is.character(i)) {
      is_na_orig <- is.na(i)

      if (has_rownames(x)) {
        i <- match(i, rownames(x))
      } else {
        i <- string_to_indices(i)
        i <- fix_oob(i, nr, warn = FALSE)
      }

      oob <- which(is.na(i) & !is_na_orig)

      if (has_length(oob)) {
        warn_deprecated("Only valid row names can be used for indexing. Use `NA` as row index to obtain a row full of `NA` values.")
        i[oob] <- NA_integer_
      }

      i <- vec_as_index(i, nr)
    } else {
      if (is.numeric(i)) {
        i <- fix_oob(i, nr)
        i <- vec_as_index(i, nr)
      } else if (is.logical(i)) {
        if (length(i) != 1L && length(i) != nr) {
          warn_deprecated(paste0(
            "Length of logical index must be 1",
            if (nr != 1) paste0(" or ", nr),
            ", not ", length(i)
          ))
          i <- seq_len(nr)[i]
        } else {
          i <- vec_as_index(i, nr)
        }
      }
    }

    result <- vec_slice(result, i)
  }

  if (drop) {
    if (length(result) == 1L) {
      return(result[[1L]])
    }
  }

  vec_restore_tbl_df_with_i(result, x, i)
}

fast_nrow <- function(x) {
  .row_names_info(x, 2L)
}

fix_oob <- function(i, n, warn = TRUE) {
  if (all(i >= 0, na.rm = TRUE)) {
    fix_oob_positive(i, n, warn)
  } else if (all(i <= 0, na.rm = TRUE)) {
    fix_oob_negative(i, n, warn)
  } else {
    # Will throw error in vec_as_index()
    i
  }
}

fix_oob_positive <- function(i, n, warn = TRUE) {
  oob <- which(i > n)
  if (warn) {
    warn_oob(oob)
  }

  i[oob] <- NA_integer_
  i
}

fix_oob_negative <- function(i, n, warn = TRUE) {
  oob <- which(i < -n)
  if (warn) {
    warn_oob(oob)
  }

  i[oob] <- 0L
  i
}

warn_oob <- function(oob) {
  if (has_length(oob)) {
    warn_deprecated("Row indexes must be between 0 and the number of rows. Use `NA` as row index to obtain a row full of `NA` values.")
  }
}

vec_restore_tbl_df_with_i <- function(x, to, i = NULL) {
  if (is.null(i)) {
    n <- nrow(x)
  } else {
    n <- length(i)
  }
  vec_restore(x, to, n = n)
}

#' @export
`$<-.tbl_df` <- function(x, name, value) {
  tryCatch(
    value <- vec_recycle_common(value, x)[[1]],
    vctrs_error_incompatible_size = function(e) {
      abort(error_inconsistent_cols(nrow(x), name, vec_size(value), "Existing data"))
    }
  )

  NextMethod()
}
