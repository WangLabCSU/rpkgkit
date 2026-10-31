# How many formals a pipe claims before the written arguments

Returns `1L` when the call is the right-hand side of a pipe that injects
its left-hand side as the first argument, and `0L` otherwise. A
placeholder anywhere in the call cancels the leading injection: the
piped value is substituted at the placeholder instead, so the written
arguments keep their natural positions.

## Usage

``` r
.mfae_pipe_shift(pd, id)
```
