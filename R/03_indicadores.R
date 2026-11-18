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

# 1. Pesos estandar nacionales (proporcion de alumnos por estrato)
pesos <- function(var) {
  datos |>
    summarise(n_alumnos = sum(n_alumnos), .by = all_of(var)) |>
    mutate(peso = n_alumnos / total_alumnos) |>
    rename(estrato = all_of(var))
}
pesos3 <- pesos("estrato3")
pesos2 <- pesos("estrato2")

peso_de <- function(p, e) p$peso[p$estrato == e]
stopifnot(
  abs(peso_de(pesos3, "Estatal rural") - 0.0585) <= 0.001,
  abs(peso_de(pesos3, "Estatal urbano") - 0.6071) <= 0.001,
  abs(peso_de(pesos3, "Privado") - 0.3344) <= 0.001,
  abs(peso_de(pesos2, "Estatal") - 0.6656) <= 0.001,
  abs(peso_de(pesos2, "Privado") - 0.3344) <= 0.001,
  abs(sum(pesos3$peso) - 1) < 1e-9
)

pesos_estandar <- bind_rows(
  mutate(pesos3, estratificacion = "3 estratos"),
  mutate(pesos2, estratificacion = "2 estratos")
) |>
  select(estratificacion, estrato, n_alumnos, peso)
write_csv(pesos_estandar, "output/tablas/pesos_estandar.csv")

# 2. Agregaciones por jurisdiccion x estrato (se suman conteos, nunca se promedian porcentajes)
agregar <- function(df, var) {
  df |>
    summarise(n_alumnos = sum(n_alumnos), n_sat_av = sum(n_sat_av), .by = c(jurisdiccion, all_of(var))) |>
    mutate(pct_sat_av = 100 * n_sat_av / n_alumnos)
}
por_jur_e2 <- agregar(datos, "estrato2")

# complete() agrega los estratos que no tienen ninguna fila (por ejemplo, CABA sin estatal rural)
por_jur_e3 <- agregar(datos, "estrato3") |>
  complete(jurisdiccion, estrato3 = estratos3, fill = list(n_alumnos = 0, n_sat_av = 0))

por_jur <- datos |>
  summarise(n_alumnos = sum(n_alumnos), n_sat_av = sum(n_sat_av), .by = jurisdiccion) |>
  mutate(pct_sat_av = 100 * n_sat_av / n_alumnos)

stopifnot(nrow(por_jur) == 24, nrow(por_jur_e3) == 24 * 3)

# 3. Elegibilidad para 3 estratos: al menos 500 alumnos en cada estrato
elegibilidad <- por_jur_e3 |>
  summarise(min_alumnos_estrato = min(n_alumnos), .by = jurisdiccion) |>
  mutate(elegible_3_estratos = min_alumnos_estrato >= 500) |>
  arrange(jurisdiccion)

no_elegibles <- elegibilidad$jurisdiccion[!elegibilidad$elegible_3_estratos]
esperados <- c("Ciudad Autónoma de Buenos Aires", "La Pampa", "Neuquén", "Santa Cruz", "Tierra del Fuego, Antártida e Islas del Atlántico Sur")
stopifnot(identical(sort(no_elegibles), sort(esperados)), sum(elegibilidad$elegible_3_estratos) == 19)

minimos <- por_jur_e3 |>
  filter(jurisdiccion %in% esperados, estrato3 == "Estatal rural") |>
  select(jurisdiccion, n_alumnos)
write_csv(elegibilidad, "output/tablas/elegibilidad_3_estratos.csv")

# 4. Tablas descriptivas
brecha_sector <- por_jur_e2 |>
  select(jurisdiccion, estrato2, n_alumnos, pct_sat_av) |>
  pivot_wider(names_from = estrato2, values_from = c(n_alumnos, pct_sat_av)) |>
  mutate(brecha_privado_menos_estatal_pp = pct_sat_av_Privado - pct_sat_av_Estatal) |>
  arrange(desc(brecha_privado_menos_estatal_pp))
stopifnot(nrow(brecha_sector) == 24, !anyNA(brecha_sector))
write_csv(brecha_sector, "output/tablas/brecha_privado_estatal.csv")

brecha_ambito <- por_jur_e3 |>
  filter(estrato3 %in% c("Estatal rural", "Estatal urbano")) |>
  select(jurisdiccion, estrato3, n_alumnos, pct_sat_av) |>
  pivot_wider(names_from = estrato3, values_from = c(n_alumnos, pct_sat_av)) |>
  inner_join(filter(elegibilidad, elegible_3_estratos)["jurisdiccion"], by = "jurisdiccion") |>
  mutate(brecha_urbano_menos_rural_pp = `pct_sat_av_Estatal urbano` - `pct_sat_av_Estatal rural`) |>
  arrange(desc(brecha_urbano_menos_rural_pp))
stopifnot(nrow(brecha_ambito) == 19, !anyNA(brecha_ambito))
write_csv(brecha_ambito, "output/tablas/brecha_urbano_rural_estatal.csv")

composicion <- por_jur_e3 |>
  mutate(proporcion = n_alumnos / sum(n_alumnos), .by = jurisdiccion) |>
  select(jurisdiccion, estrato3, n_alumnos, proporcion) |>
  arrange(jurisdiccion, estrato3)
stopifnot(all(abs(tapply(composicion$proporcion, composicion$jurisdiccion, sum) - 1) < 1e-9))
write_csv(composicion, "output/tablas/composicion_por_jurisdiccion.csv")
write_csv(por_jur, "output/tablas/pct_sat_av_por_jurisdiccion.csv")

# 5. Figuras
lim1 <- ceiling(max(por_jur$pct_sat_av) / 10) * 10 + 5
lim2 <- ceiling(max(brecha_sector$brecha_privado_menos_estatal_pp) / 5) * 5 + 5
fuente <- "Fuente: Aprender 2024, 5°/6° año, Matemática. Elaboración propia.\n* Neuquén: participación baja (62,3% de las escuelas y 42,5% de los estudiantes)."
pct_nacional <- 100 * sum(datos$n_sat_av) / total_alumnos

fig1 <- por_jur |>
  mutate(etiqueta = etiqueta_jur(jurisdiccion)) |>
  ggplot(aes(x = reorder(etiqueta, pct_sat_av), y = pct_sat_av)) +
  geom_col(fill = paleta$azul, width = 0.7) +
  geom_hline(yintercept = pct_nacional, linetype = "dashed", color = paleta$gris_oscuro) +
  geom_text(aes(y = lim1, label = sprintf("%.1f", pct_sat_av)), hjust = 1, size = 3) +
  scale_y_continuous(limits = c(0, lim1), expand = c(0, 0)) +
  coord_flip() +
  labs(
    title = "Alumnos en nivel satisfactorio o avanzado, por jurisdicción",
    subtitle = sprintf("Matemática, 5°/6° año, 2024. Línea punteada: total nacional (%.1f%%).", pct_nacional),
    x = NULL, y = "% de alumnos", caption = fuente
  ) +
  tema_informe()
ggsave("output/figuras/fig1_pct_sat_av_por_jurisdiccion.png", fig1, width = 8, height = 7, dpi = 150, bg = "white")

fig2 <- brecha_sector |>
  mutate(etiqueta = etiqueta_jur(jurisdiccion)) |>
  ggplot(aes(x = reorder(etiqueta, brecha_privado_menos_estatal_pp), y = brecha_privado_menos_estatal_pp)) +
  geom_col(fill = paleta$azul, width = 0.7) +
  geom_text(aes(y = lim2, label = sprintf("%.1f", brecha_privado_menos_estatal_pp)), hjust = 1, size = 3) +
  scale_y_continuous(limits = c(0, lim2), expand = c(0, 0)) +
  coord_flip() +
  labs(
    title = "Brecha entre escuelas privadas y estatales, por jurisdicción",
    subtitle = "Diferencia en puntos porcentuales de alumnos en nivel satisfactorio o avanzado.\nMatemática, 5°/6° año, 2024.",
    x = NULL, y = "Puntos porcentuales (privado menos estatal)", caption = fuente
  ) +
  tema_informe()
ggsave("output/figuras/fig2_brecha_privado_estatal.png", fig2, width = 8, height = 7, dpi = 150, bg = "white")

# 6. Resumen por consola
cat("Pesos estandar (3 estratos):\n"); print(as.data.frame(pesos3), row.names = FALSE)
cat("\nPesos estandar (2 estratos):\n"); print(as.data.frame(pesos2), row.names = FALSE)
cat("\nNo elegibles para 3 estratos (alumnos en estatal rural):\n"); print(as.data.frame(minimos), row.names = FALSE)
cat("\nMinimos nacionales por estrato2 entre jurisdicciones:\n")
print(por_jur_e2 |> summarise(min_alumnos = min(n_alumnos), .by = estrato2) |> as.data.frame(), row.names = FALSE)
cat("\nBrecha privado-estatal: min/max pp:", round(range(brecha_sector$brecha_privado_menos_estatal_pp), 1), "\n")
cat("Brecha urbano-rural estatal: min/max pp:", round(range(brecha_ambito$brecha_urbano_menos_rural_pp), 1), "\n")

writeLines(capture.output(sessionInfo()), "output/sessioninfo_03.txt")
cat("\nFase 3 OK\n")
