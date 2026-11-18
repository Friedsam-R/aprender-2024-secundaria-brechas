# Diseño del proyecto 2

**Brechas por sector y ámbito en Matemática de 5°/6° año de secundaria (Aprender 2024): ¿cambia el ranking provincial si todas las provincias tuvieran la misma composición estatal y privada?**

Estado: v0.2 (15 de noviembre de 2026). Las fases 1 a 5 se ejecutaron en R 4.3.3 y las tablas se contrastaron con un cálculo independiente en Python. La fase 6 (publicación) no se ejecutó.

Convención: **[V]** verificado, **[S]** supuesto, **[P]** pendiente.

Este proyecto repite el método del proyecto 1 (Aprender 2025, primaria 6° grado) en otro nivel educativo. **No compara niveles de desempeño entre primaria y secundaria**: son grados, años y pruebas distintos.

---

## 1. Pregunta y alcance

**Pregunta.** ¿Cuánto del desempeño de cada jurisdicción en Matemática de 5°/6° año se relaciona con cuántos alumnos van a escuelas estatales o privadas? Si todas las jurisdicciones tuvieran la misma composición, ¿cambia el ranking?

**Es descriptivo.** Estandarizar por composición no identifica un efecto de gestión ni de política.

**Fuera de alcance:** el NSE como ajuste, series entre ediciones, el Relevamiento Anual, comparaciones de nivel con la primaria y cualquier juicio sobre la gestión o la calidad de los datos de una jurisdicción.

## 2. Reglas fijadas antes de calcular la estandarización

Cuando se fijaron, ya se conocían el desempeño observado por sector y ámbito (usado en la auditoría) y la estructura de los estratos. Lo que todavía no se había calculado era la estandarización ni sus sensibilidades.

1. **Método:** estandarización directa. El valor estandarizado de la jurisdicción j es la suma, sobre los estratos h, de w_h × p_jh, donde p_jh es el porcentaje de la jurisdicción en el estrato y w_h es la proporción nacional de alumnos en ese estrato.
2. **Estratificación principal: 2 estratos** (estatal y privado), para las 24 jurisdicciones. Pesos nacionales de esta edición: estatal 0,6656 y privado 0,3344 [V]. Mínimos por jurisdicción: 1.991 alumnos estatales y 674 privados (Tierra del Fuego en ambos casos) [V].
3. **Estratificación secundaria: 3 estratos** (estatal rural, estatal urbano, privado), solo para las jurisdicciones con al menos 500 alumnos en cada estrato. Quedan fuera cinco: CABA (0 en estatal rural), Tierra del Fuego (1), Santa Cruz (85), Neuquén (258) y La Pampa (421) [V]. Quedan 19. Pesos nacionales: estatal rural 0,0585, estatal urbano 0,6071, privado 0,3344 [V].
4. **Neuquén:** el informe oficial advierte que su dato tiene baja participación (62,3% de las escuelas y 42,5% de los estudiantes). Se mantiene en el análisis principal, se rotula con una marca en tablas y figuras, y se excluye en una de las sensibilidades.
5. **Sin intervalos de muestreo:** la base ya viene agregada y ponderada, por lo que no se interpretan diferencias de posición entre jurisdicciones separadas por menos de 1 punto porcentual. Es un criterio práctico fijado antes de calcular la estandarización, no un criterio estadístico.
6. **Todo lo corrido se reporta,** incluido lo que no cambia el ranking. Un resultado nulo se publica igual.
7. **El lenguaje** del informe es descriptivo ("el ranking cambia de la posición X a la Y"), nunca valorativo ni causal.
8. **Jurisdicción de referencia** para la sensibilidad de pesos alternativos: la de mayor cantidad de alumnos, definida con los datos de esta edición.

## 3. Datos

| Archivo | Nombre en el proyecto | Dimensión |
|---|---|---|
| `2024_Base_APRENDER_-_Censal_-_Secundaria_5-6_año_-_Agregada_-_Desempeños_de_Matematica_in_.csv` | `aprender_2024_sec_mat.csv` | 1.175 × 1.035 [V] |

- Fuente: datos abiertos de la Subsecretaría de Información y Evaluación Educativa (Secretaría de Educación de la Nación).
- Formato: `;` como separador, `,` como decimal, UTF-8 con BOM; cada fila es una combinación de jurisdicción, departamento, sector y ámbito, con conteos ya ponderados [V].
- 24 jurisdicciones; 63 filas con departamento "Enmascarado"; 126 celdas con menos de 30 alumnos y una con cero [V].
- Total ponderado: 540.038 alumnos [V]. El informe oficial registra 379.079 estudiantes participantes, el 70,2% de la matrícula del marco; 379.079 / 0,702 ≈ 540.000, lo que es consistente con que los ponderadores expandan a la matrícula del marco [S].
- Las columnas de desempeño tienen los mismos nombres que en la primaria (`mdesemp_*`) y el NSE viene en quintiles (`NSE_nivel_Q1` a `Q5`) [V].
- **Avanzado casi no existe:** el nivel avanzado representa 0,14% de los alumnos y tiene 968 casilleros vacíos sobre 1.175. El indicador "satisfactorio o avanzado" es, en la práctica, "satisfactorio" [V].

## 4. Variables

| Variable | Fórmula | Estado |
|---|---|---|
| `n_alumnos` | suma de las cuatro columnas `mdesemp_*` | [V] |
| `pct_sat_av` | (satisfactorio + avanzado) / `n_alumnos` | [V] |
| `estrato2` | Estatal o Privado | [V] |
| `estrato3` | Estatal rural, Estatal urbano o Privado | [V] |

Un casillero vacío en `mdesemp_*` se interpreta como cero: los totales reproducen la síntesis oficial en 20 de 20 cifras (sección 5).

## 5. Auditoría previa

**Fuente de los valores esperados:** Síntesis de resultados Aprender 2024, nivel secundario, **informe actualizado a noviembre de 2025** (Secretaría de Educación). Tolerancia: 0,1 punto porcentual.

| # | Control | Por debajo del básico | Básico | Satisfactorio | Avanzado |
|---|---|---|---|---|---|
| A1 | Nacional | 54,3 | 28,0 | 17,5 | 0,1 |
| A2 | Sector estatal | 62,2 | 25,8 | 11,9 | 0,1 |
| A3 | Sector privado | 38,7 | 32,4 | 28,7 | 0,3 |
| A4 | Ámbito rural | 65,8 | 24,2 | 9,9 | 0,0 |
| A5 | Ámbito urbano | 53,5 | 28,3 | 18,0 | 0,1 |

| # | Control | Criterio |
|---|---|---|
| B1 | Total ponderado | 540.038 (tolerancia 1) |
| B2 | Suma de estratos por jurisdicción igual al total | diferencia menor a 0,000001 |
| B3 | Duplicados de la clave (jurisdicción, departamento, sector, ámbito) | 0 |
| B4 | Pesos estándar | estatal 0,6656 y privado 0,3344; con 3 estratos, 0,0585 / 0,6071 / 0,3344 (tolerancia 0,001) |
| B5 | Elegibilidad para 3 estratos | 19 jurisdicciones; no elegibles las cinco de la regla 3 |

Estado: A1 a A5 coinciden con la síntesis actualizada en las 20 cifras, al décimo [V]. B1, B4 y B5 coinciden en las pruebas de Python [V]. B2 y B3 se verifican en R durante la fase 2.

**Dos versiones oficiales.** La comunicación de junio de 2025, que reprodujo la prensa, informó 14,2% satisfactorio, 31,2% básico y 54,6% por debajo del básico. La síntesis actualizada a noviembre de 2025 informa 17,5%, 28,0% y 54,3%. Los datos de este proyecto coinciden con la actualizada. No se verificó el motivo de la diferencia entre ambas versiones [P].

## 6. Análisis

Idéntico al proyecto 1: brechas descriptivas (privado menos estatal en las 24 jurisdicciones; urbano menos rural dentro del sector estatal en las 19 elegibles); estandarización con 2 estratos; ranking observado frente a estandarizado con correlación de Spearman.

**Sensibilidad (todas se reportan):**

1. Estandarización con 3 estratos en las 19 elegibles.
2. Pesos iguales para los estratos.
3. Composición de la jurisdicción de referencia.
4. Sin CABA.
5. Sin Neuquén (regla 4).

## 7. Limitaciones

1. Estandarización por sector y ámbito, no por NSE.
2. Sin intervalos de muestreo; los rankings cercanos no son distinguibles.
3. Los pesos estándar son de esta edición y dependen de la composición nacional de 2024.
4. Participación de 70,2% de los estudiantes; hay jurisdicciones con participación mucho menor (Neuquén, 42,5%). No se evalúa el sesgo por no respuesta [P].
5. Los ponderadores ya vienen aplicados; no se leyó el documento que explica qué representan [P].
6. Es una foto de 2024. No se comparan niveles de desempeño con la primaria.
7. El nivel avanzado prácticamente no existe, así que el indicador es casi idéntico a "satisfactorio".

## 8. Registro de supuestos

| ID | Supuesto | Test | Si falla | Carga | Estado |
|---|---|---|---|---|---|
| S1 | Vacío = 0 en Aprender | Totales contra la síntesis oficial | n/a | Alta | Confirmado en 20 de 20 cifras |
| S2 | Los ponderadores expanden a la matrícula del marco | Documento metodológico | Declararlo | Media | Pendiente |
| S3 | La síntesis actualizada de noviembre de 2025 es la versión vigente | Consultar a la Secretaría | Revisar las cifras de control | Media | Pendiente |

## 9. Estructura del repositorio y hoja de ruta

Repositorio propuesto: `aprender-2024-secundaria-brechas`, con la misma estructura del proyecto 1 (`R/00_helpers.R` a `04_estandarizacion.R`, `reports/informe.qmd`, `docs/`, `data/README.md`).

| Fase | Contenido | Terminada cuando |
|---|---|---|
| 0 | Repo, `.gitignore`, README, este documento | Primer commit sin datos |
| 1 | Carga | 1.175 × 1.035 |
| 2 | Auditoría | Controles A y B resueltos |
| 3 | Indicadores y descriptivo | Tablas y figuras guardadas |
| 4 | Estandarización y sensibilidad | Todo lo de la sección 6 reportado |
| 5 | Informe Quarto | Renderiza sin errores y declara limitaciones |
| 6 | Publicación | Repo público y enlace del informe |

## 10. Estado de ejecución (fases 1 a 5)

- **Carga:** 1.175 × 1.035, cero problemas de parseo [V].
- **Auditoría:** las 20 cifras oficiales (A1 a A5) y los controles B1 a B3 dan OK; las diferencias en porcentajes son menores a 0,05 puntos [V].
- **Pesos estándar:** 2 estratos, estatal 0,6656 y privado 0,3344; 3 estratos, 0,0585 / 0,6071 / 0,3344 [V]. Elegibles para 3 estratos: 19; no elegibles CABA, La Pampa, Neuquén, Santa Cruz y Tierra del Fuego [V].
- **Brecha privado menos estatal:** entre 4,5 y 24,8 puntos según la jurisdicción [V].
- **Brecha urbano menos rural dentro del sector estatal (19 jurisdicciones):** en 6 de las 19 las escuelas estatales rurales tienen un porcentaje mayor que las urbanas. No se interpreta [V].
- **Estandarización (2 estratos):** correlación de Spearman entre el ranking observado y el estandarizado de 0,957; en las cinco sensibilidades va de 0,949 a 0,961, con cambios máximos de 3 a 5 puestos. Los valores estandarizados y las posiciones coinciden con un cálculo independiente en Python [V].
