# Insert the directive and re-flow the elements of the targets.

Rust rewrite of `rpkgkit:::.at_collapse()`: a multi-line definition gets
the directive on its own line and the line breaks inside a row removed;
a single-line definition is split into rows instead.

## Usage

``` r
uat_collapse_rs(lines, targets, ncol, marker)
```
