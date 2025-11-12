library(land4health)
library(sf)
library(reticulate)
library(geoidep)
use_python(Sys.getenv("RETICULATE_PYTHON"), required=TRUE)
info <- jsonlite::fromJSON(Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS"))
sa   <- info$client_email
py_run_string(paste(
  "import ee, os",
  sprintf("cred = ee.ServiceAccountCredentials(%s, os.getenv('GOOGLE_APPLICATION_CREDENTIALS'))", shQuote(sa)),
  "ee.Initialize(cred, project=os.getenv('GEE_PROJECT_ID'))",
  sep="\n"
))
rgee::ee_Initialize()


# Downloading the adminstration limits of Loreto provinces
provinces_loreto <- get_provinces(show_progress = FALSE) |>
  subset(nombdep == "LORETO")

# Run forest loss calculation
result <- provinces_loreto |>
  l4h_forest_loss(from = '2005-01-01', to = '2020-01-01', sf = TRUE)
head(result)
