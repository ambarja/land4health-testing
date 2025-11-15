library(land4health)
library(sf)
library(reticulate)
use_python(Sys.getenv("RETICULATE_PYTHON"), required=TRUE)
info <- jsonlite::fromJSON(Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS"))
sa   <- info$client_email
py_run_string(paste(
  "import ee, os",
  sprintf("cred = ee.ServiceAccountCredentials(%s, os.getenv('GOOGLE_APPLICATION_CREDENTIALS'))", shQuote(sa)),
  "ee.Initialize(cred, project=os.getenv('GEE_PROJECT_ID'))",
  sep="\n"
))
