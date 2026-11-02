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
