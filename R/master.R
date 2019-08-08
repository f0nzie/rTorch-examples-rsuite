# Detect proper script_path (you cannot use args yet as they are build with tools in set_env.r)
script_path <- (function() {
  args <- commandArgs(trailingOnly = FALSE)
  script_path <- dirname(sub("--file=", "", args[grep("--file=", args)]))
  if (!length(script_path)) {
    return("R")
  }
  if (grepl("darwin", R.version$os)) {
    script_path <- gsub("~\\+~", " ", script_path) # on MacOS ~+~ in path denotes whitespace
  }
  return(normalizePath(script_path))
})()

# Setting .libPaths() to point to libs folder
source(file.path(script_path, "set_env.R"), chdir = T)

config <- load_config()
args <- args_parser()

proj_root_path <- dirname(file.path(script_path))
loginfo(proj_root_path)
conda_path <- file.path(proj_root_path, "conda")

# Force using local Python environment
if (.Platform$OS.type == "unix") {
  reticulate::use_python(python = file.path(conda_path, "bin",
                                            "python3"), require = TRUE)
} else if (.Platform$OS.type == "windows") {
  reticulate::use_python(python = conda_path,
                         require = TRUE)
}
# Find the PyQt libraries under Library/plugins/platforms
qt_plugins <- file.path(conda_path,
                        "Library", "plugins", "platforms")
reticulate::py_run_string("
import os;
os.environ['QT_QPA_PLATFORM_PLUGIN_PATH'] = r.qt_plugins")

pkgdown::build_site(pkg = file.path(script_path, "..", "packages/rTorch.examples"))
