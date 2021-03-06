# is_tibble ---------------------------------------------------------------

test_that("is_tibble", {
  expect_false(is_tibble(iris))
  expect_true(is_tibble(as_tibble(iris)))
  expect_false(is_tibble(NULL))
  expect_false(is_tibble(0))
})

test_that("is_tibble", {
  scoped_lifecycle_silence()
  expect_identical(is.tibble(iris), is_tibble(iris))
})

# new_tibble --------------------------------------------------------------

test_that("new_tibble() with deprecated subclass argument", {
  tbl <- new_tibble(
    data.frame(a = 1:3),
    names = "b",
    attr1 = "value1",
    attr2 = 2,
    nrow = 3,
    subclass = "nt"
  )

  # Can't compare directly due to dplyr:::all.equal.tbl_df()
  expect_identical(class(tbl), c("nt", "tbl_df", "tbl", "data.frame"))
  expect_equal(
    unclass(tbl),
    structure(
      list(b = 1:3),
      attr1 = "value1",
      attr2 = 2,
      .Names = "b",
      row.names = .set_row_names(3L)
    )
  )
})

test_that("new_tibble() with new class argument", {
  tbl <- new_tibble(
    data.frame(a = 1:3),
    names = "b",
    attr1 = "value1",
    attr2 = 2,
    nrow = 3,
    class = "nt"
  )

  # Can't compare directly due to dplyr:::all.equal.tbl_df()
  expect_identical(class(tbl), c("nt", "tbl_df", "tbl", "data.frame"))
  expect_equal(
    unclass(tbl),
    structure(
      list(b = 1:3),
      attr1 = "value1",
      attr2 = 2,
      .Names = "b",
      row.names = .set_row_names(3L)
    )
  )
})

test_that("new_tibble checks", {
  scoped_lifecycle_errors()

  expect_identical(new_tibble(list(), nrow = 0), tibble())
  expect_identical(new_tibble(list(), nrow = 5), tibble(.rows = 5))
  expect_identical(new_tibble(list(a = 1:3, b = 4:6), nrow = 3), tibble(a = 1:3, b = 4:6))
  expect_error(
    new_tibble(1:3, nrow = 1),
    error_new_tibble_must_be_list(),
    fixed = TRUE
  )
  expect_error_cnd(
    new_tibble(list(a = 1)),
    class = get_defunct_error_class(),
    error_new_tibble_needs_nrow()
  )
  expect_error(
    new_tibble(list(1), nrow = NULL),
    error_new_tibble_needs_nrow(),
    fixed = TRUE
  )
  expect_error(
    new_tibble(list(1), nrow = 1),
    error_names_must_be_non_null(repair = FALSE),
    fixed = TRUE
  )
  expect_error(
    new_tibble(set_names(list(1), NA_character_), nrow = 1),
    NA
  )
  expect_error(
    new_tibble(set_names(list(1), ""), nrow = 1),
    NA
  )
  expect_error(
    new_tibble(list(a = 1, b = 2:3), nrow = 1),
    NA
  )
  expect_error(
    new_tibble(
      structure(list(a = 1, b = 2), row.names = .set_row_names(2)),
      nrow = 1
    ),
    NA
  )
})


test_that("validate_tibble() checks", {
  expect_error(
    validate_tibble(new_tibble(list(a = 1, b = 2:3), nrow = 1)),
    error_inconsistent_cols(1, c("a", "b"), 1:2, "Requested with `nrow` argument"),
    fixed = TRUE
  )
})
