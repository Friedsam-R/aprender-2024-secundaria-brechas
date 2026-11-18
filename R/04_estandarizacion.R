library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)

stopifnot(l10n_info()$`UTF-8`)
source("R/00_helpers.R")

datos <- preparar_datos()$datos
dir.create("output/tablas", showWarnings = FALSE, recursive = TRUE)
dir.create("output/figuras", showWarnings = FALSE, recursive = TRUE)

estratos3 <- c("Estatal rural", "Estatal urbano", "Privado")
total_alumnos <- sum(datos$n_alumnos)

# --- Tasas por jurisdiccion x estrato (se suman conteos) ---
tasas <- function(var) {
  datos |>
    summarise(n_alumnos = sum(n_alumnos), n_sat_av = sum(n_sat_av), .by = c(jurisdiccion, all_of(var))) |>
    rename(estrato = all_of(var)) |>
    mutate(pct = 100 * n_sat_av / n_alumnos)
}
tasas2 <- tasas("estrato2")
tasas3 <- tasas("estrato3") |>
  complete(jurisdiccion, estrato = estratos3, fill = list(n_alumnos = 0, n_sat_av = 0, pct = NA_real_))

obs <- datos |>
  summarise(n_alumnos = sum(n_alumnos), n_sat_av = sum(n_sat_av), .by = jurisdiccion) |>
  mutate(p_obs = 100 * n_sat_av / n_alumnos)

# --- Pesos estandar (fijados en el diseno, seccion 2) ---
pesos_nac <- function(var) {
  datos |>
    summarise(n = sum(n_alumnos), .by = all_of(var)) |>
    rename(estrato = all_of(var)) |>
    mutate(peso = n / sum(n)) |>
    select(estrato, peso)
}
pesos2_nac <- pesos_nac("estrato2")
pesos3_nac <- pesos_nac("estrato3")
pesos2_igual <- tibble(estrato = c("Estatal", "Privado"), peso = 0.5)
# Jurisdiccion de referencia: la de mayor cantidad de alumnos (criterio fijado antes de calcular la estandarización)
jur_ref <- obs$jurisdiccion[which.max(obs$n_alumnos)]
pesos2_ref <- tasas2 |>
  filter(jurisdiccion == jur_ref) |>
  mutate(peso = n_alumnos / sum(n_alumnos)) |>
  select(estrato, peso)
stopifnot(all(abs(c(sum(pesos2_nac$peso), sum(pesos3_nac$peso), sum(pesos2_ref$peso)) - 1) < 1e-9))

# --- Estandarizacion directa: sum(peso_h * tasa_jh) ---
estandarizar <- function(t, pesos) {
  t |>
    inner_join(pesos, by = "estrato") |>
    summarise(p_std = sum(peso * pct), n_estratos = n(), .by = jurisdiccion)
}

# Prueba interna: con los pesos propios de cada jurisdiccion se recupera el valor observado
propios <- tasas2 |>
  mutate(peso = n_alumnos / sum(n_alumnos), .by = jurisdiccion) |>
  summarise(p = sum(peso * pct), .by = jurisdiccion) |>
  inner_join(obs, by = "jurisdiccion")
stopifnot(max(abs(propios$p - propios$p_obs)) < 1e-9)

std2 <- estandarizar(tasas2, pesos2_nac)
stopifnot(nrow(std2) == 24, all(std2$n_estratos == 2))

# --- Tabla principal (2 estratos, pesos nacionales) ---
participacion_privado <- tasas2 |>
  mutate(share_privado = 100 * n_alumnos / sum(n_alumnos), .by = jurisdiccion) |>
  filter(estrato == "Privado") |>
  select(jurisdiccion, share_privado)

rango <- function(x) rank(-x, ties.method = "min")

principal <- obs |>
  select(jurisdiccion, n_alumnos, p_obs) |>
  inner_join(select(std2, jurisdiccion, p_std2 = p_std), by = "jurisdiccion") |>
  inner_join(participacion_privado, by = "jurisdiccion") |>
  mutate(
    efecto_composicion_pp = p_obs - p_std2,
    pos_obs = rango(p_obs),
    pos_std2 = rango(p_std2),
    cambio_posiciones = pos_obs - pos_std2,
    nota = if_else(jurisdiccion == "Neuquén", "participacion baja", "")
  ) |>
  arrange(pos_std2) |>
  mutate(dif_con_siguiente_pp = p_std2 - lead(p_std2),
         menos_de_1pp_del_siguiente = dif_con_siguiente_pp < 1)
write_csv(principal, "output/tablas/estandarizacion_2_estratos.csv")

spearman <- function(a, b) cor(rango(a), rango(b), method = "spearman")

# --- Sensibilidad ---
sens <- list()
agregar_sens <- function(nombre, df, col_std, jurisdicciones = NULL) {
  d <- if (is.null(jurisdicciones)) df else filter(df, jurisdiccion %in% jurisdicciones)
  tibble(
    especificacion = nombre,
    n_jurisdicciones = nrow(d),
    spearman_con_observado = spearman(d$p_obs, d[[col_std]]),
    max_cambio_posiciones = max(abs(rango(d$p_obs) - rango(d[[col_std]])))
  )
}

base <- obs |> select(jurisdiccion, p_obs)
s_igual <- estandarizar(tasas2, pesos2_igual) |> select(jurisdiccion, p_igual = p_std)
s_ref   <- estandarizar(tasas2, pesos2_ref)   |> select(jurisdiccion, p_ref = p_std)
elegibles <- tasas3 |>
  summarise(minimo = min(n_alumnos), .by = jurisdiccion) |>
  filter(minimo >= 500) |>
  pull(jurisdiccion)
stopifnot(length(elegibles) == 19)
s3 <- estandarizar(filter(tasas3, jurisdiccion %in% elegibles), pesos3_nac) |>
  select(jurisdiccion, p_std3 = p_std)
stopifnot(all(s3$jurisdiccion %in% elegibles))

comp <- base |>
  inner_join(select(std2, jurisdiccion, p_std2 = p_std), by = "jurisdiccion") |>
  left_join(s_igual, by = "jurisdiccion") |>
  left_join(s_ref, by = "jurisdiccion") |>
  left_join(s3, by = "jurisdiccion")

sens <- bind_rows(
  agregar_sens("Principal: 2 estratos, pesos nacionales (24)", comp, "p_std2"),
  agregar_sens("2 estratos, pesos iguales (24)", comp, "p_igual"),
  agregar_sens(paste0("2 estratos, composicion de ", jur_ref, " (24)"), comp, "p_ref"),
  agregar_sens("3 estratos, pesos nacionales (19 elegibles)", comp, "p_std3", elegibles),
  agregar_sens("2 estratos sin CABA (23)", comp, "p_std2",
               setdiff(comp$jurisdiccion, "Ciudad Autónoma de Buenos Aires")),
  agregar_sens("2 estratos sin Neuquén (23)", comp, "p_std2",
               setdiff(comp$jurisdiccion, "Neuquén"))
)
write_csv(sens, "output/tablas/sensibilidad_rankings.csv")

rangos_sens <- comp |>
  mutate(
    pos_obs = rango(p_obs), pos_std2 = rango(p_std2),
    pos_igual = rango(p_igual), pos_ref = rango(p_ref)
  ) |>
  select(jurisdiccion, pos_obs, pos_std2, pos_igual, pos_ref) |>
  arrange(pos_std2)
write_csv(rangos_sens, "output/tablas/posiciones_por_especificacion.csv")

# --- Casos puntuales (descriptivo, sin interpretar causas) ---
casos <- principal |>
  filter(jurisdiccion %in% c("Formosa", "Córdoba", "Ciudad Autónoma de Buenos Aires", "Neuquén")) |>
  select(jurisdiccion, p_obs, p_std2, efecto_composicion_pp, share_privado, pos_obs, pos_std2, cambio_posiciones)
write_csv(casos, "output/tablas/casos_formosa_cordoba_caba.csv")

# --- Figura ---
fuente <- "Fuente: Aprender 2024, 5°/6° año, Matemática. Elaboración propia.\n* Neuquén: participación baja (62,3% de las escuelas y 42,5% de los estudiantes)."
largo <- principal |>
  mutate(etiqueta = etiqueta_jur(jurisdiccion)) |>
  select(etiqueta, p_obs, p_std2) |>
  pivot_longer(c(p_obs, p_std2), names_to = "tipo", values_to = "valor") |>
  mutate(tipo = factor(tipo, c("p_obs", "p_std2"), c("Observado", "Estandarizado por sector")))
orden <- principal |> mutate(etiqueta = etiqueta_jur(jurisdiccion)) |> arrange(p_obs) |> pull(etiqueta)

fig3 <- ggplot(largo, aes(x = valor, y = factor(etiqueta, orden))) +
  geom_line(aes(group = etiqueta), color = paleta$gris_medio) +
  geom_point(aes(shape = tipo, fill = tipo), size = 2.8, color = paleta$azul) +
  scale_shape_manual(values = c("Observado" = 21, "Estandarizado por sector" = 24)) +
  scale_fill_manual(values = c("Observado" = "white", "Estandarizado por sector" = paleta$azul)) +
  labs(
    title = "Desempeño observado y estandarizado por sector, por jurisdicción",
    subtitle = "% de alumnos en nivel satisfactorio o avanzado. Matemática, 5°/6° año, 2024.\nEstandarizado: todas las jurisdicciones con la composición estatal/privada nacional.",
    x = "% de alumnos", y = NULL, shape = NULL, fill = NULL, caption = fuente
  ) +
  tema_informe() +
  theme(legend.position = "bottom")
ggsave("output/figuras/fig3_observado_vs_estandarizado.png", fig3, width = 8, height = 7.5, dpi = 150, bg = "white")

# --- Resumen ---
cat("Jurisdiccion de referencia (mas alumnos):", jur_ref, "\n\n")
cat("Pesos nacionales 2 estratos:\n"); print(as.data.frame(pesos2_nac), row.names = FALSE)
cat("\nPrincipal (ordenado por posicion estandarizada):\n")
print(as.data.frame(principal |> mutate(across(where(is.numeric), \(x) round(x, 2)))), row.names = FALSE)
cat("\nSensibilidad:\n"); print(as.data.frame(sens |> mutate(across(where(is.numeric), \(x) round(x, 3)))), row.names = FALSE)
cat("\nCasos:\n"); print(as.data.frame(casos |> mutate(across(where(is.numeric), \(x) round(x, 2)))), row.names = FALSE)

writeLines(capture.output(sessionInfo()), "output/sessioninfo_04.txt")
cat("\nFase 4 OK\n")
