library(dplyr)

preparar_datos <- function(ruta = "data/processed/aprender_2024_sec_mat.rds") {
  datos <- readRDS(ruta)

  cols_des <- grep("^mdesemp_", names(datos), value = TRUE)
  stopifnot(length(cols_des) == 4)
  col_sat <- grep("Satisfactorio", cols_des, value = TRUE)
  col_avz <- grep("Avanzado", cols_des, value = TRUE)

  # Vacios en las cuatro columnas de desempeno, antes de pasarlos a cero
  na_por_col <- vapply(cols_des, \(c) sum(is.na(datos[[c]])), numeric(1))
  filas_con_na <- sum(Reduce(`|`, lapply(cols_des, \(c) is.na(datos[[c]]))))

  # Un casillero vacio en mdesemp_* se interpreta como cero (validado contra cifras oficiales)
  datos <- datos |>
    mutate(across(all_of(cols_des), \(x) coalesce(x, 0))) |>
    mutate(
      n_alumnos = rowSums(pick(all_of(cols_des))),
      n_sat_av = .data[[col_sat]] + .data[[col_avz]],
      estrato2 = if_else(sector == "Privado", "Privado", "Estatal"),
      estrato3 = case_when(
        sector == "Privado" ~ "Privado",
        sector == "Estatal" & ambito == "Rural" ~ "Estatal rural",
        sector == "Estatal" & ambito == "Urbano" ~ "Estatal urbano"
      )
    )

  stopifnot(!anyNA(datos$estrato3), !anyNA(datos$estrato2))

  list(
    datos = datos, cols_des = cols_des, col_sat = col_sat, col_avz = col_avz,
    na_por_col = na_por_col, filas_con_na = filas_con_na
  )
}

etiqueta_jur <- function(x) {
  x <- sub("^Ciudad Autónoma de Buenos Aires$", "CABA", x)
  # Neuquén tiene participación baja en esta edición: se marca con asterisco
  x <- sub("^Neuquén$", "Neuquén*", x)
  sub("^Tierra del Fuego.*$", "Tierra del Fuego", x)
}

# Paleta de este proyecto: azul oscuro y grises, tomados de tableros publicos de datos
# educativos. Es una inspiracion de color: no incluye logos ni escudos y no es una pieza oficial.
paleta <- list(
  azul = "#242C4F",
  gris_oscuro = "#333333",
  gris_medio = "#9EA1B1",
  gris_claro = "#E7E7E7"
)

tema_informe <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", color = paleta$azul),
      plot.subtitle = ggplot2::element_text(color = paleta$gris_oscuro),
      plot.caption = ggplot2::element_text(color = paleta$gris_oscuro),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(color = paleta$gris_claro)
    )
}
