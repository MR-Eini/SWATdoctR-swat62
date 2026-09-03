test_that("verification edits named controls and uses fresh run directories", {
  path <- tempfile(); dir.create(path)
  writeLines(c("fixture", "newflag nostress carbon", "9 0 0"), file.path(path, "codes.bsn"))
  set_codes_bsn(path, 2)
  expect_equal(readLines(file.path(path, "codes.bsn"))[3], "9 2 0")
  expect_error(set_codes_bsn(path, 3), "nostress")
  first <- build_model_run(path, "/.run_verify")
  writeLines("stale", file.path(first, "basin_wb_day.txt"))
  second <- build_model_run(path, "/.run_verify")
  expect_false(identical(first, second))
  expect_false(file.exists(file.path(second, "basin_wb_day.txt")))
  expect_true(file.exists(file.path(first, "basin_wb_day.txt")))
})

test_that("verification selects outputs despite new print sections", {
  path <- tempfile(); dir.create(path)
  x <- c("fixture", "nyskip day_start yrc_start day_end yrc_end interval", "0 0 0 0 0 1",
    "csvout dbout cdfout future_flag", "y y y y",
    "soilout mgtout hydcon fdcout", "n n n n", "gwflow_out", "y",
    "objects daily monthly yearly avann", "hru_pw n n n n")
  writeLines(x, file.path(path, "print.prt"))
  set_print_prt(path, path, c("mgt", "plt"), 3)
  result <- readLines(file.path(path, "print.prt"))
  expect_equal(result[11], "hru_pw y n n n")
  expect_equal(SWATreadR::swat_control_get(result, "mgtout"), c(mgtout = "y"))
  expect_equal(SWATreadR::swat_control_get(result, "nyskip"), c(nyskip = "3"))
  expect_equal(SWATreadR::swat_control_get(result, "future_flag"), c(future_flag = "y"))
})
