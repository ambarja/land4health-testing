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

# Guardar figura en el repo
plot_path <- "figures/forest_loss_loreto.png"
dir.create(dirname(plot_path), showWarnings = FALSE, recursive = TRUE)

png(plot_path, width = 2000, height = 1500, res = 250)
print(p)
dev.off()

## 4. Tabla resumen en Markdown ----------------------------------------------

tabla_md <- knitr::kable(
  head(result_df, 10),
  format = "pipe"
)

## 5. Bloque markdown para README (imagen + tabla) ---------------------------

# URL absoluta para que SIEMPRE se renderice en GitHub
img_url <- "https://github.com/ambarja/land4health-testing/raw/main/figures/forest_loss_loreto.png"
img_md  <- sprintf("![Forest loss in Loreto](%s)", img_url)

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

## 6. Reemplazar SIEMPRE un único bloque en README --------------------------

readme_path <- "README.md"

if (!file.exists(readme_path)) {
  writeLines(c(
    "# land4health-testing",
    "",
    "Repo de prueba para el pipeline de `land4health`.",
    ""
  ), readme_path)
}

readme <- readLines(readme_path, warn = FALSE)

# 6.1. Borrar cualquier bloque autogenerado anterior
start_idxs <- grep("<!-- START_AUTOGEN_RESULTS -->", readme, fixed = TRUE)
end_idxs   <- grep("<!-- END_AUTOGEN_RESULTS -->",   readme, fixed = TRUE)

if (length(start_idxs) > 0 && length(end_idxs) > 0) {
  first_start <- start_idxs[1]
  last_end    <- end_idxs[length(end_idxs)]

  keep_before <- if (first_start > 1) readme[1:(first_start - 1)] else character(0)
  keep_after  <- if (last_end < length(readme)) readme[(last_end + 1):length(readme)] else character(0)

  readme <- c(keep_before, keep_after)
}

# 6.2. Añadir al final el nuevo bloque (único)
nuevo_readme <- c(
  readme,
  "",
  bloque_md
)

writeLines(nuevo_readme, readme_path)
