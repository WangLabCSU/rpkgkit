# rpkgkit <a href="https://wanglabcsu.github.io/rpkgkit/"><img src="../../man/figures/logo.png" align="right" height="139" alt="sitio web de rpkgkit" /></a>

<!-- badges: start -->
[![Lifecycle:stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://lifecycle.r-lib.org/articles/stages.html#stable)
[![Project Status: Active - The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![CRAN-status](https://www.r-pkg.org/badges/version/rpkgkit)](https://CRAN.R-project.org/package=rpkgkit)
[![R-CMD-check](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/WangLabCSU/rpkgkit/actions/workflows/R-CMD-check.yaml)
[![Devel-version](https://img.shields.io/badge/devel%20version-0.1.16-blue.svg)](https://github.com/WangLabCSU/rpkgkit)
[![Codesize](https://img.shields.io/github/languages/code-size/WangLabCSU/rpkgkit.svg)](https://github.com/WangLabCSU/rpkgkit)
[![Codecov-testcoverage](https://codecov.io/gh/WangLabCSU/rpkgkit/graph/badge.svg)](https://app.codecov.io/gh/WangLabCSU/rpkgkit)
[![Ask-DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/WangLabCSU/rpkgkit)
[![Dependencies](https://tinyverse.netlify.app/badge/rpkgkit)](https://cran.r-project.org/package=rpkgkit)
[![English](https://img.shields.io/badge/README-English-blue)](../../README.md)
[![Español](https://img.shields.io/badge/README-Espa%C3%B1ol-blue)]()
[![简体中文](https://img.shields.io/badge/README-%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87-blue)](README.zh-cn.md)
[![Last-commit](https://img.shields.io/github/last-commit/WangLabCSU/rpkgkit.svg)](https://github.com/WangLabCSU/rpkgkit/commits/main)
<!-- badges: end -->

## Resumen

`rpkgkit` ofrece utilidades para crear y mantener paquetes de R. Sus funciones cubren tareas habituales, como gestionar scripts independientes, mantener `NEWS.md`, modernizar código R, configurar la infraestructura de un paquete y mantener archivos README.

Muchas funciones detectan el contexto del archivo activo en RStudio y Positron, por lo que a menudo se puede omitir la ruta del archivo.

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

O instálala desde GitHub:

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

## Agradecimientos

Agradecemos a las siguientes personas y proyectos:

- Los autores del paquete [pedant](https://github.com/wurli/pedant) — **Jacob Scott**, **Christopher T. Kenny** y **Sebastian Lammers** — cuyo código se incluye (con licencia MIT) en `R/vendor-pedant.R`.
- El autor del paquete [pkgdev](https://github.com/dieghernan/pkgdev) — **Diego Hernangómez** — cuyo código se incluye (con licencia MIT) en `R/vendor-pkgdev.R`.
- Todas las personas colaboradoras y usuarias que han informado de problemas, propuesto funcionalidades o contribuido a mejorar el paquete.
