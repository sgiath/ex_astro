# Astro

Library to help working with [SPICE](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/index.html)
and [ERFA](https://github.com/liberfa/erfa) libraries

## Installation

It is a bit more complicated then normal lib so pay attention:

- instal ERFA library
  - <https://github.com/liberfa/erfa?tab=readme-ov-file#building-and-installing-erfa>
- add `ex_astro` to `mix.exs`

```elixir
  def deps do
    [
      ...
      {:ex_astro, "~> 0.2"},
      ...
    ]
  end
```

- download SPICE kernels and add them to the config

```bash
mix astro.kernels
```

## Time API

`Astro.Time` represents Julian Dates as two-part tuples `{jd1, jd2}` rather
than a single float. This follows ERFA/SOFA conventions and preserves much more
precision for time-scale conversions.

```elixir
iex> jd = Astro.Time.to_julian_date(~N[2000-01-01 12:00:00])
iex> jd
{2451544.5, 0.5}
iex> Astro.Time.day2sec(jd)
0.0
```
