library(readr)
library(dplyr)

ruta <- "data/raw/aprender_2024_sec_mat.csv"

crudo <- read_delim(
  ruta,
  delim = ";",
  col_types = cols(.default = col_character()),
  locale = locale(decimal_mark = ",", encoding = "UTF-8")
)

claves <- c("jurisdiccion", "departamento", "sector", "ambito")
stopifnot(identical(names(crudo)[1:4], claves))

# Todo lo que no es clave son conteos ponderados con coma decimal.
# parse_double es estricto: si algo no es un numero, lo registra en problems().
numericas <- setdiff(names(crudo), claves)
datos <- crudo |>
  mutate(across(all_of(numericas), \(x) parse_double(x, locale = locale(decimal_mark = ","))))

cat("Dimension:", nrow(datos), "x", ncol(datos), "\n")
cat("Problemas de parseo:", nrow(problems(datos)), "\n")
cat("Celdas vacias (NA) en columnas numericas:", sum(vapply(datos[numericas], \(x) sum(is.na(x)), numeric(1))), "\n")

stopifnot(nrow(datos) == 1175, ncol(datos) == 1035)
stopifnot(nrow(problems(datos)) == 0)

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
saveRDS(datos, "data/processed/aprender_2024_sec_mat.rds")

dir.create("output", showWarnings = FALSE)
writeLines(capture.output(sessionInfo()), "output/sessioninfo_01.txt")
cat("Fase 1 OK\n")
