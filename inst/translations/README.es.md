# rpkgkit <a href="https://wanglabcsu.github.io/rpkgkit/"><img src="../../man/figures/logo.png" align="right" height="139" alt="sitio web de rpkgkit" /></a>

<!-- badges: start -->
[![CRAN-status](https://www.r-pkg.org/badges/version/rpkgkit)](https://CRAN.R-project.org/package=rpkgkit)
[![R-universe-version](https://wanglabcsu.r-universe.dev/rpkgkit/badges/version)](https://wanglabcsu.r-universe.dev/rpkgkit)
[![R-CMD-check](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml)
[![Codesize](https://img.shields.io/github/languages/code-size/WangLabCSU/rpkgkit.svg)](https://github.com/WangLabCSU/rpkgkit)
[![Codecov-testcoverage](https://codecov.io/gh/WangLabCSU/rpkgkit/graph/badge.svg)](https://app.codecov.io/gh/WangLabCSU/rpkgkit)
[![Ask-DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/WangLabCSU/rpkgkit)
[![Dependencies](https://tinyverse.netlify.app/badge/rpkgkit)](https://cran.r-project.org/package=rpkgkit)
[![English](https://img.shields.io/badge/README-English-blue)](../../README.md)
[![Español](https://img.shields.io/badge/README-Espa%C3%B1ol-blue)]()
[![简体中文](https://img.shields.io/badge/README-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-blue)](README.zh-cn.md)
<!-- badges: end -->

## Resumen

`rpkgkit` ofrece utilidades para crear y mantener paquetes de R. Sus funciones cubren tareas habituales, como gestionar scripts independientes, mantener `NEWS.md`, modernizar código R, configurar la infraestructura de un paquete y mantener archivos README.

Muchas funciones detectan el contexto del archivo activo en RStudio y Positron (2026.10.1 o posterior), por lo que a menudo se puede omitir la ruta del archivo.

## Instalación

Instala la versión publicada desde CRAN:

```r
install.packages("rpkgkit")
```

Instala la versión de desarrollo desde r-universe:

```r
install.packages(
  "rpkgkit",
  repos = c("https://wanglabcsu.r-universe.dev", "https://cloud.r-project.org")
)
```

O instálala desde GitHub (recomendado):

```r
pak::pak("WangLabCSU/rpkgkit")
```

## Guías

El sitio web del paquete organiza ejemplos detallados y listos para usar por tarea:

- [Scripts independientes de rpkgkit](https://wanglabcsu.github.io/rpkgkit/articles/standalone_tools.html): importa ayudantes independientes, gestiona sus metadatos y busca o crea archivos independientes.
- [Conversión de código](https://wanglabcsu.github.io/rpkgkit/articles/code_convertion.html): califica llamadas de paquetes, revisa código fuente, moderniza sintaxis y convierte literales enteros o no ASCII.
- [Editar NEWS](https://wanglabcsu.github.io/rpkgkit/articles/news.html): crea, actualiza, muestra y valida entradas de `NEWS.md`.
- [Configuración y mantenimiento de paquetes](https://wanglabcsu.github.io/rpkgkit/articles/pkg_maintain.html): configura la infraestructura del paquete, incorpora código con licencias permisivas y gestiona archivos de exclusión.
- [Herramientas para README y documentación](https://wanglabcsu.github.io/rpkgkit/articles/readme_and_doc.html): crea traducciones de README e inserta o genera insignias.

Se recomienda usar los siguientes paquetes junto con `rpkgkit`:

- [`pkgdown`](https://pkgdown.r-lib.org/) / [`pkgdown.offline`](https://nanx.me/pkgdown.offline/): genera el sitio web del paquete.
- [`pkgload`](https://pkgload.r-lib.org/): carga el código fuente del paquete.
- [`flir`](https://flir.etiennebacher.com/) / [`jarl`](https://jarl.etiennebacher.com/) / [`lintr`](https://lintr.r-lib.org/): analiza y corrige el código fuente.
- [`air`](https://posit-dev.github.io/air/): formatea el código fuente.
- [`usethis`](https://usethis.r-lib.org/): gestiona los metadatos del paquete.
- [`devtools`](https://devtools.r-lib.org/): construye y comprueba el paquete.

## Hoja de referencia

Todas las funciones exportadas con una llamada mínima. La mayoría acepta `path = NULL`, que significa «usar el archivo activo o el directorio del paquete actual».

### Conversión y revisión de código

| Función | Uso rápido | Propósito |
|:---|:---|:---|
| `add_double_colons()` | `add_double_colons(code)` | Añadir `pkg::` a las llamadas de una cadena de código |
| `make_func_call_explicit()` | `make_func_call_explicit("R/foo.R")` | Añadir `pkg::` a todas las llamadas de un archivo |
| `package_func_call_explicit()` | `package_func_call_explicit()` | Lo mismo, en todos los archivos de `R/` |
| `make_func_arg_explicit()` | `make_func_arg_explicit("R/foo.R")` | Añadir nombres de argumento a las llamadas de un archivo |
| `package_func_arg_explicit()` | `package_func_arg_explicit()` | Lo mismo, en todos los archivos de `R/` |
| `rename_func()` | `rename_func("R/foo.R", style = "snake_case")` | Renombrar las definiciones de función según un estilo |
| `convert_func_syntax()` | `convert_func_syntax("R/foo.R", direction = "to_lambda")` | Alternar entre la sintaxis `function()` y `\()` |
| `convert_pipe()` | `convert_pipe("R/foo.R", direction = "to_base")` | Alternar entre las tuberías de magrittr y la nativa en un archivo |
| `package_convert_pipe()` | `package_convert_pipe(direction = "to_base")` | Lo mismo, en todos los archivos de `R/` |
| `convert_int_literals()` | `convert_int_literals("R/foo.R")` | Añadir el sufijo entero `L` en un archivo |
| `package_convert_int_literals()` | `package_convert_int_literals()` | Lo mismo, en todos los archivos de `R/` |
| `convert_nonascii_code()` | `convert_nonascii_code(code, reverse = FALSE)` | Escapar los caracteres no ASCII (o restaurarlos) |
| `convert_knitr_chunk_header()` | `convert_knitr_chunk_header()` | Modernizar las cabeceras de chunk de knitr en archivos `.Rmd` |
| `optimize_rmd_yaml()` | `optimize_rmd_yaml("README.Rmd")` | Completar una cabecera YAML con el `DESCRIPTION` del paquete |
| `package_optimize_rmd_yaml()` | `package_optimize_rmd_yaml()` | Lo mismo, para `README.Rmd` y todas las viñetas |
| `detect_print_and_cat()` | `detect_print_and_cat("R/foo.R", fix = TRUE)` | Buscar (y corregir) llamadas a `print()` y `cat()` no aptas para CRAN |
| `package_print_and_cat()` | `package_print_and_cat(fix = TRUE)` | Lo mismo, en `R/` y `tests/testthat/` |
| `detect_lost_glue_brace()` | `detect_lost_glue_brace("R/foo.R")` | Buscar llaves perdidas en cadenas de `glue` y `cli` |
| `package_lost_glue_brace()` | `package_lost_glue_brace()` | Lo mismo, en `R/` y `tests/testthat/` |
| `detect_unmatched_nocov_marker()` | `detect_unmatched_nocov_marker("R/foo.R")` | Buscar marcadores `# nocov` sin pareja en un archivo |
| `package_unmatched_nocov_marker()` | `package_unmatched_nocov_marker()` | Lo mismo, en `R/` |
| `detect_fn_arg_path()` | `detect_fn_arg_path("R/foo.R")` | Buscar argumentos `path` o `file` con valor por defecto en funciones exportadas |
| `package_fn_arg_path()` | `package_fn_arg_path()` | Lo mismo, en las funciones exportadas del paquete |
| `check_pkgdown_reference()` | `check_pkgdown_reference()` | Comprobar que cada función exportada aparece en `_pkgdown.yml` |
| `check_sysdeps()` | `check_sysdeps(c("libpng-dev"))` | Comprobar si las librerías del sistema están instaladas |
| `check_air_installed()` | `check_air_installed()` | Comprobar que el formateador `air` está en el `PATH` |
| `flir_fix()` | `flir_fix("R/foo.R")` | Corregir código R con `flir` |
| `use_air_table()` | `use_air_table("R/foo.R", ncol = 3)` | Maquetar llamadas largas a `c()` y `list()` como tablas alineadas con `air` |
| `air_format()` | `air_format("R/foo.R")` | Obsoleta; formatear código R con `air` |

### Gestionar `NEWS.md`

| Función | Uso rápido | Propósito |
|:---|:---|:---|
| `news_md_add_entry()` | `news_md_add_entry("Added a new feature.", category = "NEW FEATURES")` | Añadir una entrada, creando la sección de versión si hace falta |
| `news_md_show()` | `news_md_show(version = "latest")` | Mostrar `NEWS.md`, opcionalmente filtrado a una versión |
| `news_md_check()` | `news_md_check()` | Obsoleta; validar el formato de `NEWS.md` |

### Configuración y mantenimiento del paquete

| Función | Uso rápido | Propósito |
|:---|:---|:---|
| `use_zzz()` | `use_zzz()` | Crear `R/<pkg>-package.R` a partir de una plantilla |
| `use_r_v4.1.0()` | `use_r_v4.1.0()` | Añadir `R (>= 4.1.0)` a `Depends` |
| `use_url()` | `use_url()` | Definir `URL` desde el remoto de git, con una URL de pkgdown opcional |
| `use_bugreports()` | `use_bugreports()` | Definir `BugReports` desde el remoto de git |
| `use_vendor()` | `use_vendor("wurli/pedant", "R/utils.R")` | Incorporar código con licencia permisiva desde GitHub |
| `add_global_rbuildignore()` | `add_global_rbuildignore()` | Añadir los patrones globales de `.Rbuildignore` |
| `add_global_gitgnore()` | `add_global_gitgnore()` | Añadir un `.gitignore` global al estilo de GitHub |
| `use_jarl()` | `use_jarl()` | Crear un archivo de configuración `jarl.toml` |
| `use_clangd()` | `use_clangd()` | Crear un archivo `.clangd` con las rutas de inclusión de Rcpp |
| `use_tidy_addin()` | `use_tidy_addin("my_addin", "Open my gadget")` | Registrar una función exportada en el menú Addins de RStudio |
| `use_workflow_version_update()` | `use_workflow_version_update()` | Añadir el flujo de GitHub Actions que actualiza la versión |
| `use_workflow_test_branch()` | `use_workflow_test_branch()` | Añadir un flujo que sincroniza `main` con la rama `test` |
| `use_workflow_rust_compatible_check()` | `use_workflow_rust_compatible_check()` | Añadir un flujo de R-CMD-check compatible con Rust |
| `open_cffinit()` | `open_cffinit()` | Abrir en el navegador el generador `CITATION.cff` de `cffinit` |

### README y documentación

| Función | Uso rápido | Propósito |
|:---|:---|:---|
| `badge_to_readme()` | `badge_to_readme(badge)` | Insertar una insignia en el bloque de insignias del README |
| `badge_translated_by_ai()` | `badge_translated_by_ai(lang = "zh-cn")` | Generar una insignia de aviso de traducción por IA |
| `use_multilanguage_readme()` | `use_multilanguage_readme("zh-cn")` | Crear archivos README traducidos y sus insignias |
| `render_rmd()` | `render_rmd("README.Rmd")` | Renderizar un archivo `.Rmd` o `.R` a Markdown |
| `use_hexsticker()` | `use_hexsticker("man/figures/logo.png")` | Obsoleta; añadir un hex sticker al título del README |

### Archivos independientes

| Función | Uso rápido | Propósito |
|:---|:---|:---|
| `create_standalone()` | `create_standalone("my_utils")` | Crear un archivo independiente con cabecera YAML |
| `check_standalone()` | `check_standalone("R/standalone-my_utils.R")` | Comprobar el formato de un archivo independiente |
| `update_time_in_standalone()` | `update_time_in_standalone()` | Actualizar el campo de última modificación |
| `add_changelog_in_standalone()` | `add_changelog_in_standalone("R/standalone-my_utils.R", "Fix a bug")` | Añadir o actualizar una entrada del registro de cambios |
| `inquire_standalone()` | `inquire_standalone("r-lib", "rlang")` | Listar los archivos independientes de un repositorio de GitHub |
| `browse_standalone()` | `browse_standalone()` | Buscar en GitHub archivos independientes publicados por paquetes R |

### Utilidades

| Función | Uso rápido | Propósito |
|:---|:---|:---|
| `current_packages()` | `current_packages()` | Paquetes cuyas llamadas conviene calificar |
| `imported_functions()` | `imported_functions()` | Nombres de funciones importadas en `NAMESPACE` |
| `is_dev_context()` | `is_dev_context()` | Si el directorio actual es un entorno de desarrollo de paquetes |
| `get_positron_version()` | `get_positron_version()` | Versión del IDE Positron en ejecución |

## Addin

A partir de la v0.1.23, `rpkgkit` incluye un addin que se puede usar en RStudio. Está disponible en el menú `Addins` y también se puede abrir con `Ctrl+Shift+P` (Windows/Linux) o `Cmd+Shift+P` (macOS).

Si quieres usar addins en Positron, puedes usar la extensión [Positron R Wizard](https://github.com/ntluong95/positron-r-wizard.git).

## Habilidades de IA

`rpkgkit` incluye una skill para agentes que indica a los agentes de programación cuándo deben usar `rpkgkit` y cómo llamarlo. Sigue el formato [Agent Skills](https://skills.sh), por lo que funciona con Claude Code, Codex, Cursor, Positron y otros agentes compatibles:

```bash
npx skills add WangLabCSU/rpkgkit --skill rpkgkit
```

Añade `-g` para instalarla en todos los proyectos y `-a <agente>` para omitir la pregunta del agente. El código fuente de la skill está en [`skills/rpkgkit/`](https://github.com/WangLabCSU/rpkgkit/tree/main/skills/rpkgkit).

## Agradecimientos

Agradecemos a las siguientes personas y proyectos:

- Los autores del paquete [pedant](https://github.com/wurli/pedant) — **Jacob Scott**, **Christopher T. Kenny** y **Sebastian Lammers** — cuyo código se incluye (con licencia MIT) en `R/vendor-pedant.R`.
- El autor del paquete [pkgdev](https://github.com/dieghernan/pkgdev) — **Diego Hernangómez** — cuyo código se incluye (con licencia MIT) en `R/vendor-pkgdev.R`.
- Todas las personas colaboradoras y usuarias que han informado de problemas, propuesto funcionalidades o contribuido a mejorar el paquete.
