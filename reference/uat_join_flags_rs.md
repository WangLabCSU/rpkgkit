# Flag the line breaks that disappear when the rows are collapsed.

A line ending in a comment is never joined with the next one: the joined
element would be swallowed by the comment.

## Usage

``` r
uat_join_flags_rs(join, elements, ncol, lines)
```
