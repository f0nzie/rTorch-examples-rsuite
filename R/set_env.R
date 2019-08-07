lib_path <- file.path("..", "libs")
sbox_path <- file.path("..", "sbox")
if (!file.exists(lib_path)) {
  lib_path <- file.path("..", "deployment", "libs")
  sbox_path <- file.path("..", "deployment", "sbox")
}

if (!dir.exists(sbox_path)) {
  dir.create(sbox_path, recursive = T)
}

.libPaths(c(normalizePath(sbox_path), normalizePath(lib_path), .libPaths()))

library(logging)
logging::logReset()
logging::setLevel(level = "INFO")
logging::addHandler(logging::writeToConsole, level = "FINEST")

log_fpath <- (function() {
  log_file <- gsub("-", "_", sprintf("%s.log", Sys.Date()))
  log_dir <- normalizePath(file.path("..", "logs"))
  fpath <- file.path(log_dir, log_file)
  if (file.exists(fpath) && file.access(fpath, 2) == -1) {
    fpath <- paste0(fpath, ".", Sys.info()[["user"]])
  }
  if (!file.exists(fpath) && !suppressWarnings(file.create(fpath, showWarnings = FALSE))) {
    logging::logwarn("Could not create log file; Logging into file is not possible!")
    return(NULL)
  }
  return(fpath)
})()

log_dir <- normalizePath(file.path("..", "logs"))
if (!is.null(log_fpath) && dir.exists(log_dir)) {
  logging::addHandler(logging::writeToFile, level = "FINEST", file = log_fpath)
}

script_path <- getwd()

args_parser <- function() {
    args <- commandArgs(trailingOnly = FALSE)
    list(
        get = function(name, required = TRUE,  default = NULL) {
            prefix <- sprintf("--%s=", name)
            value <- sub(prefix, "", args[grep(prefix, args)])

            if (length(value) != 1 || is.null(value)) {
                if (required) {
                    logerror("--%s parameter is required", name)
                    stop(1)
                }
                return(default)
            }
            return(value)
        }
    )
}

load_config <- function() {
  config_file <- file.path(script_path, "..", "config.txt")
  templ_file <- file.path(script_path, "..", "config_templ.txt")
  if (!file.exists(config_file)) {
    if (!file.exists(templ_file)) {
      return(list())
    }
    success <- tryCatch(suppressWarnings({
        file.copy(templ_file, config_file) &&
          Sys.chmod(config_file, "0600", use_umask = FALSE)
      }),
      error = function(e) FALSE)
    if (!success) {
      logging::logwarn("Failed to create config.txt; Will try to use configuration from config_templ.txt file.")
    }
  }

  safe_read_conf <- function(fpath) {
    suppressWarnings({
      tryCatch(as.list(head(data.frame(read.dcf(fpath), stringsAsFactors = FALSE), 1)),
               error = function(e) NULL)
    })
  }
  config <- NULL
  if (file.exists(config_file)) {
    config <- safe_read_conf(config_file)
    if (is.null(config)) {
      logging::logwarn("Failed to load config.txt; Will use configuration from config_templ.txt file.")
    }
  }
  if (is.null(config) && file.exists(templ_file)) {
    config <- safe_read_conf(templ_file)
  }
  if (is.null(config)) {
    logging::logwarn("Failed to load configuration!")
    return(list())
  }

  if (file.exists(templ_file)) {
    templ_conf <- safe_read_conf(templ_file)
    if (!is.null(templ_conf) && !all(names(templ_conf) %in% names(config))) {
      new_ents <- setdiff(names(templ_conf), names(config))
      logging::loginfo("Detected new configuration entries in config_templ.txt not present in config.txt: %s",
                       paste(new_ents, collapse = ", "))
      config <- c(config, templ_conf[new_ents])

      tryCatch(suppressWarnings(write.dcf(config, config_file)),
               error = function(e) logging::logwarn("Failed to update config.txt to contain new entries."))
    }
  }

  if ("LogLevel" %in% names(config)) {
    logging::setLevel(config$LogLevel)
  }

  return(config)
}

assert <- function(cond, fail_msg = NULL, ...) {
  if (!cond) {
    if (is.null(fail_msg) || missing(fail_msg)) {
      fail_msg <- sprintf("Condition failed: %s", 
                          deparse(substitute(cond), width.cutoff = 30L))
    } else {
      fail_msg <- sprintf(fail_msg, ...)
    }
    stop(fail_msg, call. = FALSE)
  }
  invisible()
}
