#' Apply a function (or functions) across multiple columns
#'
#' @description
#' `across()` makes it easy to apply the same transformation to multiple columns, allowing you to use [select()]
#' semantics inside in "data-masking" functions like [summarise()] and [mutate()].
#'
#' `across()` supersedes the family of {dplyr} "scoped variants" like `summarise_at()`, `summarise_if()`, and
#' `summarise_all()` and therefore these functions will not be implemented in {poorman}.
#'
#' @param cols,.cols <[`poor-select`][select_helpers]> Columns to transform. Because `across()` is used within functions
#' like `summarise()` and `mutate()`, you can't select or compute upon grouping variables.
#' @param .fns Functions to apply to each of the selected columns.
#'   Possible values are:
#'
#'   - `NULL`, to returns the columns untransformed.
#'   - A function, e.g. `mean`.
#'   - A list of functions, e.g. `list(mean = mean, sum = sum)`
#'
#'   Within these functions you can use [cur_group()] to access the current grouping keys.
#' @param ... Additional arguments for the function calls in `.fns`.
#' @param .names `character(n)`. Currently limited to specifying a vector of names to use for the outputs.
#'
#' @return
#' A `data.frame` with one column for each column in `.cols` and each function in `.fns`.
#'
#' @examples
#' # across() -----------------------------------------------------------------
#' iris %>%
#'   group_by(Species) %>%
#'   summarise(across(starts_with("Sepal"), mean))
#' iris %>%
#'   mutate(across(where(is.factor), as.character))
#'
#' # Additional parameters can be passed to functions
#' iris %>%
#'   group_by(Species) %>%
#'   summarise(across(starts_with("Sepal"), mean, na.rm = TRUE))
#'
#' # A named list of functions
#' iris %>%
#'   group_by(Species) %>%
#'   summarise(across(starts_with("Sepal"), list(mean = mean, sd = sd)))
#'
#' # Use the .names argument to control the output names
#' iris %>%
#'   group_by(Species) %>%
#'   summarise(
#'     across(starts_with("Sepal"),
#'     mean,
#'     .names = c("mean_sepal_length", "mean_sepal_width"))
#'   )
#'
#' @export
across <- function(.cols = everything(), .fns = NULL, ..., .names = NULL) {
  setup <- setup_across(substitute(.cols), .fns, .names)
  cols <- setup$cols
  n_cols <- length(cols)
  if (n_cols == 0L) return(data.frame())
  funs <- setup$funs
  data <- context$get_columns(cols)
  names <- setup$names
  if (is.null(funs)) {
    data <- data.frame(data)
    if (is.null(names)) {
      return(data)
    } else {
      return(setNames(data, names))
    }
  }
  n_fns <- length(funs)
  res <- vector(mode = "list", length = n_fns * n_cols)
  k <- 1L
  for (i in seq_len(n_cols)) {
    col <- data[[i]]
    for (j in seq_len(n_fns)) {
      res[[k]] <- funs[[j]](col, ...)
      k <- k + 1L
    }
  }
  if (is.null(names(res))) names(res) <- names
  as.data.frame(res)
}

# -- helpers -----------------------------------------------------------------------------------------------------------

setup_across <- function(.cols, .fns, .names) {
  cols <- eval_select_pos(.data = context$.data, .cols, .group_pos = FALSE)
  cols <- context$get_colnames()[cols]
  if (context$is_grouped()) cols <- setdiff(cols, get_groups(context$.data))

  funs <- if (is.null(.fns)) NULL else if (!is.list(.fns)) list(.fns) else .fns
  f_nms <- names(funs)
  if (is.null(f_nms) && !is.null(.fns)) names(funs) <- seq_along(funs)
  if (any(nchar(f_nms) == 0L)) {
    miss <- which(nchar(f_nms) == 0L)
    names(funs)[miss] <- miss
    f_nms <- names(funs)
  }

  names <- if (!is.null(.names)) {
    .names
  } else {
    if (length(funs) == 1L && is.null(f_nms)) {
      cols
    } else {
      nms <- do.call(paste, c(rev(expand.grid(names(funs), cols)), sep = "_"))
      if (length(nms) == 0L) nms <- NULL
      nms
    }
  }

  list(cols = cols, funs = funs, names = names)
}