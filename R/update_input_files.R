#' Generate folder structure for SWAT execution
#'
#' @param project_path Path to the SWAT project folder (i.e. TxtInOut)
#' @param folder_name Name of the folder in which simulations are performed
#'
#' @keywords internal
build_model_run <- function(project_path, folder_name) {
  base_path <- paste0(project_path, folder_name)
  dir.create(base_path, recursive = TRUE, showWarnings = FALSE)
  run_path <- tempfile("run-", tmpdir = base_path)
  dir.create(run_path)
  swat_files <- list.files(project_path, full.names = TRUE)
  swat_files <- swat_files[!dir.exists(swat_files)]
  # Preserve input files; generated output files are not reused.
  swat_files <- swat_files[!grepl("\\.(txt|csv|db|out)$", swat_files, ignore.case = TRUE)]
  if (!all(file.copy(swat_files, run_path))) stop("Could not copy verification inputs.")
  run_path
}

#' Read and set SWAT+ print.prt file
#'
#' Read the SWAT+ `print.prt` file, update it according to the requested
#' outputs, and write the updated file to `run_path`. The original file
#' is kept in the project directory (optionally the user may create a
#' backup as `print_backup.prt` beforehand).
#'
#' @param project_path Path to the SWAT project folder (i.e. TxtInOut)
#' @param run_path Path to the folder where simulations are performed
#' @param outputs Define the outputs that should be read after the
#'   simulation run. The outputs that are defined here depend on the
#'   verification steps that should be performed on the outputs.
#' @param years_skip (optional) Integer value to define the number of
#'   simulation years that are skipped before writing SWAT model outputs.
#'
#' @importFrom readr read_lines write_lines
#' @importFrom stringr str_replace str_sub
#'
#' @keywords internal
set_print_prt <- function(project_path, run_path, outputs, years_skip) {

  print_prt <- read_lines(paste0(project_path, "/print.prt"), lazy = FALSE)

  requested <- list()
  if ("wb" %in% outputs) {
    requested <- list(basin_wb = c("daily", "avann"), basin_pw = "daily",
      basin_aqu = "avann", basin_sd_cha = "avann", hru_wb = "avann",
      recall = c("yearly", "avann"))
  }
  if ("plt" %in% outputs) requested$hru_pw <- "daily"
  if ("wb_sft" %in% outputs) requested$basin_wb <- "avann"
  print_prt <- SWATreadR::swat_print_objects(print_prt, requested)
  print_prt <- SWATreadR::swat_print_options(print_prt,
    mgtout = if ("mgt" %in% outputs) "y" else "n")
  if (!is.null(years_skip)) {
    if (length(years_skip) != 1L || !is.finite(years_skip) ||
        years_skip < 0 || years_skip != trunc(years_skip)) {
      stop("years_skip must be one nonnegative integer.")
    }
    print_prt <- SWATreadR::swat_control_set(print_prt, c(nyskip = years_skip))
  }

  write_lines(print_prt, paste0(run_path, "/print.prt"))
}

#' Read and set SWAT+ time.sim file
#'
#' Read the SWAT+ `time.sim` file, update simulation start and end dates,
#' and write the updated file to `run_path`. The original file is kept
#' in the project directory (optionally the user may create a backup as
#' `time_backup.sim` beforehand).
#'
#' @param project_path Path to the SWAT project folder (i.e. TxtInOut)
#' @param run_path Path to the folder where simulations are performed
#' @param start_date (optional) Start date of the SWAT simulation.
#'   Provided as character string in any ymd format
#'   (e.g. 'yyyy-mm-dd'), numeric value in the form yyyymmdd,
#'   or in Date format.
#' @param end_date (optional) End date of the SWAT simulation.
#'   Provided as character string in any ymd format
#'   (e.g. 'yyyy-mm-dd'), numeric value in the form yyyymmdd,
#'   or in Date format.
#'
#' @importFrom lubridate interval int_end int_start yday year ymd
#' @importFrom readr read_lines write_lines
#' @importFrom stringr str_trim str_split
#'
#' @keywords internal
set_time_sim <- function(project_path, run_path, start_date, end_date) {

  time_sim <- read_lines(paste0(project_path, "/time.sim"), lazy = FALSE)

  if (xor(is.null(start_date), is.null(end_date))) {
    stop("'start_date' and 'end_date' must be provided together!")
  } else if (!is.null(start_date)) {
    # Determine required date indices for writing to time.sim
    start_date <- ymd(start_date)
    end_date   <- ymd(end_date)
    if (anyNA(c(start_date, end_date)) || start_date > end_date) {
      stop("Invalid or reversed simulation dates.")
    }

    time_interval <- interval(start_date, end_date)

    start_year <- year(int_start(time_interval))
    start_jdn  <- yday(int_start(time_interval))
    end_year   <- year(int_end(time_interval))
    end_jdn    <- yday(int_end(time_interval))

    time_sim[3] <-
      c(start_jdn, start_year, end_jdn, end_year, 0) %>%
      sprintf("%10d", .) %>%
      paste(., collapse = "")
  }

  write_lines(time_sim, paste0(run_path, "/time.sim"))
}

#' Set the `nostress` value in the codes.bsn file
#'
#' @param run_path Path to the folder where simulations are performed
#' @param nostress `nostress` parameter in the 'codes.bsn' file to
#'   activate/deactivate plant stresses for plant growth.
#'
#'   * `nostress = 0`: all plant stresses applied
#'   * `nostress = 1`: turn off all plant stresses
#'   * `nostress = 2`: turn off nutrient plant stress only
#'
#' @importFrom dplyr %>%
#' @importFrom readr read_lines write_lines
#' @importFrom stringr str_trim str_split
#'
#' @keywords internal
set_codes_bsn <- function(run_path, nostress) {

  bsn_path <- paste0(run_path, "/codes.bsn")
  bsn      <- read_lines(bsn_path)

  if (length(nostress) != 1L || is.na(nostress) || !nostress %in% 0:2) {
    stop("nostress must be 0, 1, or 2.")
  }
  bsn <- SWATreadR::swat_control_set(bsn, c(nostress = nostress))

  write_lines(bsn, bsn_path)
}
