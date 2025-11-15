#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(land4health)
  library(sf)
  library(reticulate)
  library(jsonlite)
  library(geoidep)
  library(ggplot2)
  library(knitr)
})

## 1. Configurar Python / EE -------------------------------------------------

use_python(Sys.getenv("RETICULATE_PYTHON"), required = TRUE)

info <- jsonlite::fromJSON(Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS"))
sa   <- info$client_email

py_run_string(paste(
  "import ee, os",
  sprintf(
    "cred = ee.ServiceAccountCredentials(%s, os.getenv('GOOGLE_APPLICATION_CREDENTIALS'))",
    shQuote(sa)
  ),
  "ee.Initialize(cred, project=os.getenv('GEE_PROJECT_ID'))",
  sep = "\n"
))

## 2. Cálculo: distritos de Loreto (ccdd == '16') ----------------------------

districts_loreto <- get_districts(show_progress = FALSE) |>
  subset(ccdd == "16")

result <- districts_loreto |>
  l4h_forest_loss(from = "2005-01-01", to = "2020-01-01", sf = TRUE)

result_df <- sf::st_drop_geometry(result)

## 3. Crear la figura (mapa) con ggplot2 -------------------------------------

p <- ggplot(data = result) +
  geom_sf(aes(fill = value), color = NA) +
  scale_fill_viridis_c(name = "Forest loss mean \n(km²)") +
  theme_minimal(base_size = 15) +
  facet_wrap(date ~ .)

plot_path <- "figures/forest_loss_loreto.png"  # ruta relativa para el README
dir.create(dirname(plot_path), showWarnings = FALSE, recursive = TRUE)

png(plot_path, width = 2000, height = 1500, res = 250)
print(p)
dev.off()

## 4. Preparar tabla markdown -------------------------------------------------

tabla_md <- knitr::kable(
  head(result_df, 10),   # primeras 10 filas
  format = "pipe"
)

## 5. Bloque markdown para insertar en README (imagen + tabla) --------------

img_md <- sprintf("![Forest loss in Loreto](%s)", plot_path)

bloque_md <- paste(
  "<!-- START_AUTOGEN_RESULTS -->",
  "",
  "## Resultados automáticos (Loreto – pérdida de bosque)",
  "",
  "Cobertura: distritos del departamento de Loreto (ccdd = '16')",
  "",
  "Período: 2005-01-01 a 2020-01-01",
  "",
  img_md,
  "",
  "Tabla resumen (primeras 10 filas):",
  "",
  tabla_md,
  "",
  sprintf("_Actualizado automáticamente: %s_", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "<!-- END_AUTOGEN_RESULTS -->",
  sep = "\n"
)

# 6. Reemplazar (siempre un único bloque) en README.md -----------------------

readme_path <- "README.md"
if (!file.exists(readme_path)) {
  writeLines(c(
    "# land4health-testing",
    "",
    "Pipeline de prueba para `land4health`.",
    "",
    "<!-- START_AUTOGEN_RESULTS -->",
    "<!-- END_AUTOGEN_RESULTS -->"
  ), readme_path)
}
