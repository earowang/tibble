#' Row-wise tibble creation
#'
#' @description
#' \Sexpr[results=rd, stage=render]{tibble:::lifecycle("maturing")}
#'
#' Create [tibble]s using an easier to read row-by-row layout.
#' This is useful for small tables of data where readability is
#' important.  Please see \link{tibble-package} for a general introduction.
#'
#' @param ... Arguments specifying the structure of a `tibble`.
#'   Variable names should be formulas, and may only appear before the
#'   data. These arguments support [tidy dots][rlang::tidy-dots].
#' @return A [tibble].
#' @export
#' @examples
#' tribble(
#'   ~colA, ~colB,
#'   "a",   1,
#'   "b",   2,
#'   "c",   3
#' )
#'
#' # tribble will create a list column if the value in any cell is
#' # not a scalar
#' tribble(
#'   ~x,  ~y,
#'   "a", 1:3,
#'   "b", 4:6
#' )
tribble <- function(...) {
  data <- extract_frame_data_from_dots(...)
  turn_frame_data_into_tibble(data$frame_names, data$frame_rest)
}

#' Row-wise matrix creation
#'
#' @description
#' \Sexpr[results=rd, stage=render]{tibble:::lifecycle("maturing")}
#'
#' Create matrices laying out the data in rows, similar to
#' `matrix(..., byrow = TRUE)`, with a nicer-to-read syntax.
#' This is useful for small matrices, e.g. covariance matrices, where readability
#' is important. The syntax is inspired by [tribble()].
#'
#' @param ... Arguments specifying the structure of a `frame_matrix`.
#'   Column names should be formulas, and may only appear before the
#'   data. These arguments support [tidy dots][rlang::tidy-dots].
#' @return A [matrix].
#' @export
#' @examples
#' frame_matrix(
#'   ~col1, ~col2,
#'   1,     3,
#'   5,     2
#' )
frame_matrix <- function(...) {
  data <- extract_frame_data_from_dots(...)
  turn_frame_data_into_frame_matrix(data$frame_names, data$frame_rest)
}

extract_frame_data_from_dots <- function(...) {
  dots <- list2(...)

  # Extract the names.
  frame_names <- extract_frame_names_from_dots(dots)

  # Extract the data
  if (length(frame_names) == 0 && length(dots) != 0) {
    abort(error_tribble_needs_columns())
  }
  frame_rest <- dots[-seq_along(frame_names)]
  if (length(frame_rest) == 0L) {
    # Can't decide on type in absence of data -- use logical which is
    # coercible to all types
    frame_rest <- logical()
  }

  validate_rectangular_shape(frame_names, frame_rest)

  list(frame_names = frame_names, frame_rest = frame_rest)
}

extract_frame_names_from_dots <- function(dots) {
  frame_names <- character()

  for (i in seq_along(dots)) {
    el <- dots[[i]]
    if (!is.call(el)) {
      break
    }

    if (!identical(el[[1]], as.name("~"))) {
      break
    }

    if (length(el) != 2) {
      abort(error_tribble_lhs_column_syntax(el[[2]]))
    }

    candidate <- el[[2]]
    if (!(is.symbol(candidate) || is.character(candidate))) {
      abort(error_tribble_rhs_column_syntax(candidate))
    }

    frame_names <- c(frame_names, as.character(candidate))
  }

  frame_names
}

validate_rectangular_shape <- function(frame_names, frame_rest) {
  if (length(frame_names) == 0 && length(frame_rest) == 0) return()

  # Figure out the associated number of rows and number of columns,
  # and validate that the supplied formula produces a rectangular
  # structure.
  if (length(frame_rest) %% length(frame_names) != 0) {
    abort(error_tribble_non_rectangular(
      length(frame_names),
      length(frame_rest)
    ))
  }
}

turn_frame_data_into_tibble <- function(names, rest) {
  frame_mat <- matrix(rest, ncol = length(names), byrow = TRUE)
  frame_col <- turn_matrix_into_column_list(frame_mat)

  if (length(frame_col) == 0) {
    return(new_tibble(list(), nrow = 0))
  }

  # Create a tbl_df and return it
  names(frame_col) <- names
  new_tibble(frame_col, nrow = NROW(frame_col[[1]]))
}

turn_matrix_into_column_list <- function(frame_mat) {
  frame_col <- vector("list", length = ncol(frame_mat))
  # if a frame_mat's col is a list column, keep it unchanged (does not unlist)
  for (i in seq_len(ncol(frame_mat))) {
    col <- frame_mat[, i]
    if (some(col, needs_list_col) || !inherits(col, "list")) {
      frame_col[[i]] <- col
    } else {
      frame_col[[i]] <- exec(c, !!!col)
    }
  }
  return(frame_col)
}

turn_frame_data_into_frame_matrix <- function(names, rest) {
  list_cols <- which(map_lgl(rest, needs_list_col))
  if (has_length(list_cols)) {
    abort(error_frame_matrix_list(list_cols))
  }

  frame_ncol <- length(names)
  frame_mat <- matrix(unlist(rest), ncol = frame_ncol, byrow = TRUE)

  colnames(frame_mat) <- names
  frame_mat
}
