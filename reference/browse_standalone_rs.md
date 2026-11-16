# Search GitHub for standalone files, at most `limit` of them.

`per_page` is the page size of the underlying search (1 to 100), `limit`
the number of rows to return and `token` an empty string for an
unauthenticated client. Returns one named column per field of the search
hit.

## Usage

``` r
browse_standalone_rs(per_page, limit, token)
```
