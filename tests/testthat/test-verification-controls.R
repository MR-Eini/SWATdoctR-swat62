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

test_that("annual water-balance metadata stays separate from crop labels", {
  result <- read_wb_aa(test_path("fixtures"))
  expect_equal(result$precip, 792.783)
  expect_equal(result$wet_stor, 0.390)
  expect_equal(result$description, "Original Simulation 0")
  expect_equal(result$cal_adj, 0)
  expect_true(is.na(result$plant_cov))
  expect_true(is.na(result$mgt_ops))
})

test_that("verification rejects unresolved revision 62 plant names", {
  path <- tempfile(); dir.create(path)
  writeLines(c(
    "DIAGNOSTICS.OUT FILE",
    "mgt schedule 1 op numb 9 rye not found in plants.plt database",
    "plant com 2 plant numb 1 fesc_mgt not found in plants.plt database"
  ), file.path(path, "diagnostics.out"))

  expect_error(assert_resolved_plants(path), "fesc_mgt, rye")
  writeLines("DIAGNOSTICS.OUT FILE", file.path(path, "diagnostics.out"))
  expect_true(assert_resolved_plants(path))
})

test_that("verification cleanup removes runs and only removes an empty parent", {
  parent <- tempfile(); run_path <- file.path(parent, "run-one")
  dir.create(run_path, recursive = TRUE)
  expect_true(cleanup_verification_run(run_path))
  expect_false(dir.exists(run_path))
  expect_false(dir.exists(parent))

  run_path <- file.path(parent, "run-one")
  sibling <- file.path(parent, "run-two")
  dir.create(run_path, recursive = TRUE)
  dir.create(sibling)
  expect_true(cleanup_verification_run(run_path))
  expect_true(dir.exists(parent))
  expect_true(dir.exists(sibling))
  unlink(parent, recursive = TRUE, force = TRUE)
})
