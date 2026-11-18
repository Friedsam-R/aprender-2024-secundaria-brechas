library(dplyr)
library(readr)

stopifnot(l10n_info()$`UTF-8`)
source("R/00_helpers.R")

prep <- preparar_datos()
datos <- prep$datos
cols_des <- prep$cols_des
na_por_col <- prep$na_por_col
filas_con_na <- prep$filas_con_na

# Columnas de los cuatro niveles, identificadas por su nombre (sin depender de tildes)
col_deb <- grep("Por_debajo", cols_des, value = TRUE)
col_bas <- grep("^mdesemp_B", cols_des, value = TRUE)
col_sat <- prep$col_sat
col_avz <- prep$col_avz
niveles <- c(col_deb, col_bas, col_sat, col_avz)
stopifnot(length(niveles) == 4, !anyDuplicated(niveles))
nombres_niveles <- c("Por debajo del básico", "Básico", "Satisfactorio", "Avanzado")

pct_niveles <- function(df) 100 * colSums(df[niveles]) / sum(df$n_alumnos)

# Valores oficiales: Síntesis de resultados Aprender 2024, nivel secundario,
# informe actualizado a noviembre de 2025. Orden: debajo, básico, satisfactorio, avanzado.
oficial <- list(
  "Nacional"       = c(54.3, 28.0, 17.5, 0.1),
  "Sector estatal"  = c(62.2, 25.8, 11.9, 0.1),
  "Sector privado"  = c(38.7, 32.4, 28.7, 0.3),
  "Ámbito rural"    = c(65.8, 24.2, 9.9, 0.0),
  "Ámbito urbano"   = c(53.5, 28.3, 18.0, 0.1)
)
subconjunto <- list(
  "Nacional"       = datos,
  "Sector estatal"  = filter(datos, sector == "Estatal"),
  "Sector privado"  = filter(datos, sector == "Privado"),
  "Ámbito rural"    = filter(datos, ambito == "Rural"),
  "Ámbito urbano"   = filter(datos, ambito == "Urbano")
)
stopifnot(identical(names(oficial), names(subconjunto)))

control <- function(id, descripcion, esperado, obtenido, tol) {
  tibble(
    control = id, descripcion = descripcion, esperado = esperado,
    obtenido = round(obtenido, 3), diferencia = round(obtenido - esperado, 3),
    tolerancia = tol,
    resultado = if_else(abs(obtenido - esperado) <= tol, "OK", "FALLA")
  )
}

controles_a <- bind_rows(lapply(seq_along(oficial), \(i) {
  g <- names(oficial)[i]
  obt <- pct_niveles(subconjunto[[g]])
  bind_rows(lapply(1:4, \(k) control(
    paste0("A", i, c("a", "b", "c", "d")[k]),
    paste0(g, ": ", nombres_niveles[k]), oficial[[g]][k], unname(obt[k]), 0.1
  )))
}))

total_alumnos <- sum(datos$n_alumnos)

# B2: la suma de los tres estratos de cada jurisdiccion debe igualar su total
suma_estratos <- datos |>
  summarise(n_estratos = sum(n_alumnos), .by = c(jurisdiccion, estrato3)) |>
  summarise(n_estratos = sum(n_estratos), .by = jurisdiccion)
total_jur <- datos |> summarise(n_total = sum(n_alumnos), .by = jurisdiccion)
dif_b2 <- left_join(suma_estratos, total_jur, by = "jurisdiccion") |>
  summarise(max_dif = max(abs(n_estratos - n_total))) |>
  pull(max_dif)

duplicados <- sum(duplicated(datos[c("jurisdiccion", "departamento", "sector", "ambito")]))

controles_b <- bind_rows(
  control("B1", "Total de alumnos ponderados", 540038, total_alumnos, 1),
  control("B2", "Suma de estratos igual al total de cada jurisdiccion (max dif.)", 0, dif_b2, 1e-6),
  control("B3", "Filas duplicadas en la clave jurisdiccion-departamento-sector-ambito", 0, duplicados, 0)
)
tabla <- bind_rows(controles_a, controles_b)

informativos <- tibble(
  control = c("I1", "I2", "I3", "I4"),
  descripcion = c(
    "Filas con departamento Enmascarado",
    "Celdas con n_alumnos < 30",
    "Celdas con n_alumnos = 0",
    "Filas con algun vacio en las columnas mdesemp_*"
  ),
  esperado = c(63, 126, 1, NA),
  obtenido = c(
    sum(datos$departamento == "Enmascarado"),
    sum(datos$n_alumnos < 30),
    sum(datos$n_alumnos == 0),
    filas_con_na
  ),
  diferencia = NA_real_, tolerancia = NA_real_, resultado = "INFO"
)

auditoria <- bind_rows(tabla, informativos)

dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
write_csv(auditoria, "output/tablas/auditoria.csv")
print(as.data.frame(auditoria), row.names = FALSE)
cat("\nVacios por columna de desempeno:\n")
print(na_por_col)

writeLines(capture.output(sessionInfo()), "output/sessioninfo_02.txt")

fallas <- filter(tabla, resultado == "FALLA")
if (nrow(fallas) > 0) {
  print(as.data.frame(fallas), row.names = FALSE)
  stop("Hay controles que fallan: no continuar a la fase 3.")
}
cat("\nFase 2: todos los controles A y B en OK\n")
