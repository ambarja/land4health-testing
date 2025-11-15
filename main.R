library(land4health)
library(sf)
library(reticulate)
library(jsonlite)
library(geoidep)
library(ggplot2)
library(knitr)

# 1. Configurar Python / EE
use_python(Sys.getenv("RETICULATE_PYTHON"), required = TRUE)

info <- jsonlite::fromJSON(Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS"))
sa   <- info$client_email

py_run_string(paste(
  "import ee, os",
  sprintf("cred = ee.ServiceAccountCredentials(%s, os.getenv('GOOGLE_APPLICATION_CREDENTIALS'))", shQuote(sa)),
  "ee.Initialize(cred, project=os.getenv('GEE_PROJECT_ID'))",
  sep = "\n"
))

# 2. Cálculo
provinces_loreto <- get_provinces(show_progress = FALSE) |>
  subset(nombdep == "LORETO")

result <- provinces_loreto |>
  l4h_forest_loss(from = "2005-01-01", to = "2020-01-01", sf = TRUE)

# Limpiamos geometría para la tabla
result_df <- sf::st_drop_geometry(result)

# 3. Crear la figura (mapa) con ggplot2  <<< IMPORTANTE
p <- ggplot(data = result) +
  geom_sf(aes(fill = value), color = NA) +
  scale_fill_viridis_c(name = "Forest loss mean \n(km²)") +
  theme_minimal(base_size = 15) +
  facet_wrap(date ~ .)

# 4. Guardar la figura como PNG dentro del repo  <<< IMPORTANTE
plot_path <- "figures/forest_loss_loreto.png"  # ruta relativa para el README
dir.create(dirname(plot_path), showWarnings = FALSE, recursive = TRUE)

png(plot_path, width = 2000, height = 1500, res = 250)
print(p)
dev.off()

# 5. Preparar tabla markdown
tabla_md <- knitr::kable(
  head(result_df, 10),   # por ejemplo 10 filas
  format = "pipe"
)

# 6. Bloque markdown para insertar en README (imagen + tabla)
img_md <- sprintf("![Forest loss in Loreto](%s)", plot_path)

bloque_md <- paste(
  "<!-- START_AUTOGEN_RESULTS -->",
  "",
  "## Resultados automáticos (Loreto – pérdida de bosque)",
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

# 7. Reemplazar el bloque en README.md
readme_path <- "README.md"
readme <- readLines(readme_path, warn = FALSE)

start <- grep("<!-- START_AUTOGEN_RESULTS -->", readme, fixed = TRUE)
end   <- grep("<!-- END_AUTOGEN_RESULTS -->", readme, fixed = TRUE)

if (length(start) == 1 && length(end) == 1 && start < end) {
  nuevo_readme <- c(
    readme[1:(start - 1)],
    bloque_md,
    readme[(end + 1):length(readme)]
  )
} else {
  nuevo_readme <- c(readme, "", bloque_md)
}

writeLines(nuevo_readme, readme_path)
