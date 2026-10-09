# Flatten parse data into the lookup structure used by the edit planner

The planner reads the same handful of parse-data fields over and over,
so they are extracted once into plain vectors — indexing a data.frame
costs a dispatch per column. Children are reached through a hashed
environment keyed by parent id and return row indices into those
vectors. A list or data.frame keyed by name would not do: `[[` by name
scans linearly, which turns planning a single large file quadratic.

## Usage

``` r
.mfae_parse_data(parse_data)
```

## Details

Rows are reordered into source order first, because that order is what
maps a call's child tokens onto its arguments.
