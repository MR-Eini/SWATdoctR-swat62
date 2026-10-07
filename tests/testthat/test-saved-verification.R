test_that("saved annual verification is readable without executing or deleting", {
  folder <- tempfile(); dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE))
  file.copy(test_path("fixtures", "basin_wb_aa.txt"), folder)
  for (name in c("basin_wb_day.txt", "basin_pw_day.txt", "basin_aqu_aa.txt", "hru_wb_aa.txt")) {
    writeLines(c("fixture", "jday yr value", "units", "1 2023 2.5"), file.path(folder, name))
  }
  before <- tools::md5sum(list.files(folder, full.names = TRUE))
  x <- read_swat_verification(folder, outputs = "wb")
  expect_equal(names(x), c("basin_wb_day", "basin_pw_day", "basin_wb_aa", "basin_aqu_aa", "hru_wb_aa"))
  expect_equal(x$basin_wb_aa$precip, 792.783)
  expect_equal(x$hru_wb_aa$value, 2.5)
  expect_equal(tools::md5sum(list.files(folder, full.names = TRUE)), before)
  expect_error(read_swat_verification(folder, outputs = "invalid"))
  writeLines(c("fixture", "id value", "units", "1 2 3"),
             file.path(folder, "recall_yr.txt"))
  expect_error(read_swat_verification(folder, outputs = "wb"), "mismatch|Cannot safely parse")
})

test_that("non-output tables use explicit whitespace and preserve duplicate headers", {
  folder <- tempfile(); dir.create(folder)
  on.exit(unlink(folder, recursive = TRUE))
  writeLines(c("fixture", "id name name", '1 crop"name other', "2 second third"),
             file.path(folder, "input.txt"))
  x <- read_tbl("input.txt", folder, 2)
  expect_equal(names(x), c("id", "name1", "name2"))
  expect_equal(x$name1, c('crop"name', "second"))
})
