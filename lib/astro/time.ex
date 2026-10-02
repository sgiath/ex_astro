defmodule Astro.Time do
  @moduledoc """
  Convert between calendar dates, split Julian Dates, astronomical time scales,
  and SPICE ephemeris time.

  This module uses ERFA's two-part Julian Date representation throughout the
  public Julian Date API. A Julian Date is therefore represented as
  `{jd1, jd2}` rather than a single float.

  Supported time scales include:

  - Coordinated Universal Time (`UTC`)
  - International Atomic Time (`TAI`)
  - Terrestrial Time (`TT`)
  - Geocentric Coordinate Time (`TCG`)
  - Barycentric Dynamical Time (`TDB`)
  - Barycentric Coordinate Time (`TCB`)
  - SPICE Ephemeris Time (`ET`, TDB seconds past J2000)

  ## Why Split Julian Dates?

  A single floating-point Julian Date loses precision near modern epochs.
  ERFA/SOFA avoid that by splitting the value into two parts whose sum is the
  full Julian Date. This representation preserves sub-microsecond detail for
  precision-sensitive conversions such as `TT <-> TDB`.

  The split itself is not canonical. Different functions may return equivalent
  pairs whose sums match the same physical Julian Date.

  ## Conventions

  - JD-based functions accept and return `{jd1, jd2}`.
  - `str2et/1` and `utc2et/1` return scalar ephemeris seconds.
  - `unitim/3` remains a low-level SPICE primitive and uses scalar numeric
    epochs because the accepted units are not all Julian Dates.
  - `jd_to_float/1` and `jd_from_float/1` are explicit interop helpers for code
    that still needs a single float.
  - Native string inputs must be non-empty binaries without embedded NUL bytes.
    `str2et/1` accepts up to 256 bytes, `utc2et/1` accepts up to 80 bytes, and
    `unitim/3` time-system names accept up to 5 bytes. Invalid native strings
    raise `ArgumentError`.

  ## Example

      iex> jd_utc = Astro.Time.dtf2d(2000, 1, 1, 12, 0, 0.0)
      iex> Astro.Time.jd_to_float(jd_utc)
      2451545.0
      iex> tai = Astro.Time.utc2tai(jd_utc)
      iex> tt = Astro.Time.tai2tt(tai)
      iex> Astro.Time.jd_to_float(tt) > Astro.Time.jd_to_float(tai)
      true

      iex> Astro.Time.str2et("2000 JAN 01 12:00:00 TDB")
      0.0
  """

  alias Astro.NIF

  @j2000 2_451_545.0

  @type jd_part :: float()
  @type julian_date :: {jd_part(), jd_part()}
  @type ephemeris_time :: float()
  @type radians :: float()
  @type kilometers :: float()
  @type gregorian_datetime_tuple ::
          {year :: integer(), month :: integer(), day :: integer(), hour :: integer(), minute :: integer(),
           second :: integer(), microsecond :: integer()}
  @type uniform_time_system :: String.t()

  defguard is_jd(jd)
           when is_tuple(jd) and tuple_size(jd) == 2 and
                  is_float(elem(jd, 0)) and is_float(elem(jd, 1))

  @doc """
  Convert a UTC split Julian Date to a `NaiveDateTime`.

  This is the inverse of `to_julian_date/1`. `NaiveDateTime` cannot represent
  a leap second, so a Julian Date inside second `60` of a leap-second day raises
  `ArgumentError`; use `jd2dt/1` to decode it.

  ## Example

      iex> Astro.Time.to_datetime({2451545.0, 0.0})
      ~N[2000-01-01 12:00:00.000000]
  """
  @spec to_datetime(julian_date()) :: NaiveDateTime.t()
  def to_datetime(julian_date) when is_jd(julian_date) do
    case NIF.jd2dt(elem(julian_date, 0), elem(julian_date, 1)) do
      {y, m, d, _h, _mn, 60, _us} ->
        raise ArgumentError,
              "UTC leap second on #{Date.new!(y, m, d)} cannot be represented by NaiveDateTime; use jd2dt/1"

      {y, m, d, h, mn, s, us} ->
        %NaiveDateTime{
          year: y,
          month: m,
          day: d,
          hour: h,
          minute: mn,
          second: s,
          microsecond: {us, 6},
          calendar: Calendar.ISO
        }
    end
  end

  @doc """
  Convert a `DateTime` or `NaiveDateTime` to a UTC split Julian Date.

  A `DateTime` is converted by its UTC instant: its `utc_offset` and
  `std_offset` are subtracted from the wall-clock fields. `NaiveDateTime`
  fields are interpreted as UTC.
  """
  @spec to_julian_date(DateTime.t() | NaiveDateTime.t()) :: julian_date()
  def to_julian_date(%DateTime{utc_offset: utc_offset, std_offset: std_offset} = dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.add(-(utc_offset + std_offset), :second)
    |> to_julian_date()
  end

  def to_julian_date(%NaiveDateTime{} = dt) do
    sec =
      case dt.microsecond do
        {_value, 0} -> dt.second * 1.0
        {value, _precision} -> dt.second + value / 1_000_000
      end

    NIF.dtf2d(dt.year, dt.month, dt.day, dt.hour, dt.minute, sec)
  end

  @doc """
  Collapse a split Julian Date to a single float.

  This is convenient for display or interop, but it discards the extra
  precision preserved by the split representation.
  """
  @spec jd_to_float(julian_date()) :: float()
  def jd_to_float(jd) when is_jd(jd) do
    elem(jd, 0) + elem(jd, 1)
  end

  @doc """
  Wrap a single float Julian Date as `{jd, 0.0}`.

  This helper is intended for interop with APIs that still expose Julian Dates
  as one float.
  """
  @spec jd_from_float(float()) :: julian_date()
  def jd_from_float(jd) when is_float(jd), do: {jd, 0.0}

  @doc """
  Convert a Gregorian UTC date and time to a split Julian Date.

  ## Example

      iex> Astro.Time.dtf2d(2000, 1, 1, 12, 0, 0.0)
      {2451544.5, 0.5}
  """
  @spec dtf2d(integer(), integer(), integer(), integer(), integer(), float()) :: julian_date()
  def dtf2d(year, month, day, hour, min, sec), do: NIF.dtf2d(year, month, day, hour, min, sec)

  @doc """
  Convert a UTC split Julian Date to Gregorian calendar components.

  This is the inverse of `dtf2d/6`. Days containing a leap second are decoded
  with their real length, and the leap second itself is returned as second
  `60`.

  ## Example

      iex> Astro.Time.jd2dt({2451545.0, 0.0})
      {2000, 1, 1, 12, 0, 0, 0}
  """
  @spec jd2dt(julian_date()) :: gregorian_datetime_tuple()
  def jd2dt(julian_date) when is_jd(julian_date) do
    NIF.jd2dt(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc """
  Convert a UTC split Julian Date to International Atomic Time (`TAI`).
  """
  @spec utc2tai(julian_date()) :: julian_date()
  def utc2tai(julian_date) when is_jd(julian_date) do
    NIF.utc2tai(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc """
  Convert a TAI split Julian Date to Terrestrial Time (`TT`).
  """
  @spec tai2tt(julian_date()) :: julian_date()
  def tai2tt(julian_date) when is_jd(julian_date) do
    NIF.tai2tt(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc """
  Convert a TAI split Julian Date to `UTC`.
  """
  @spec tai2utc(julian_date()) :: julian_date()
  def tai2utc(julian_date) when is_jd(julian_date) do
    NIF.tai2utc(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc """
  Convert a TT split Julian Date to `TAI`.
  """
  @spec tt2tai(julian_date()) :: julian_date()
  def tt2tai(julian_date) when is_jd(julian_date) do
    NIF.tt2tai(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc """
  Convert a TT split Julian Date to Geocentric Coordinate Time (`TCG`).
  """
  @spec tt2tcg(julian_date()) :: julian_date()
  def tt2tcg(julian_date) when is_jd(julian_date) do
    NIF.tt2tcg(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc """
  Convert a TT split Julian Date to Barycentric Dynamical Time (`TDB`) using
  geocentric observer terms.
  """
  @spec tt2tdb(julian_date()) :: julian_date()
  def tt2tdb(julian_date), do: tt2tdb(julian_date, 0.0, 0.0, 0.0, 0.0)

  @doc """
  Convert a TT split Julian Date to `TDB` using explicit observer terms for
  ERFA's `eraDtdb` model.

  Inputs:

  - `ut` - UT1 time of day in seconds (`0.0..86_400.0`)
  - `elong` - observer east longitude in radians
  - `u` - distance from Earth's spin axis in km
  - `v` - distance north of Earth's equatorial plane in km
  """
  @spec tt2tdb(julian_date(), float(), radians(), kilometers(), kilometers()) :: julian_date()
  def tt2tdb(julian_date, ut, elong, u, v) when is_jd(julian_date) do
    NIF.tt2tdb(elem(julian_date, 0), elem(julian_date, 1), ut, elong, u, v)
  end

  @doc """
  Convert a TCG split Julian Date to `TT`.
  """
  @spec tcg2tt(julian_date()) :: julian_date()
  def tcg2tt(julian_date) when is_jd(julian_date) do
    NIF.tcg2tt(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc """
  Convert a TDB split Julian Date to `TT` using geocentric observer terms.
  """
  @spec tdb2tt(julian_date()) :: julian_date()
  def tdb2tt(julian_date), do: tdb2tt(julian_date, 0.0, 0.0, 0.0, 0.0)

  @doc """
  Convert a TDB split Julian Date to `TT` using explicit observer terms for
  ERFA's `eraDtdb` model.

  Takes the same observer inputs as `tt2tdb/5`, with `ut` in seconds.
  """
  @spec tdb2tt(julian_date(), float(), radians(), kilometers(), kilometers()) :: julian_date()
  def tdb2tt(julian_date, ut, elong, u, v) when is_jd(julian_date) do
    NIF.tdb2tt(elem(julian_date, 0), elem(julian_date, 1), ut, elong, u, v)
  end

  @doc """
  Convert a TDB split Julian Date to Barycentric Coordinate Time (`TCB`).
  """
  @spec tdb2tcb(julian_date()) :: julian_date()
  def tdb2tcb(julian_date) when is_jd(julian_date) do
    NIF.tdb2tcb(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc """
  Convert a TCB split Julian Date to `TDB`.
  """
  @spec tcb2tdb(julian_date()) :: julian_date()
  def tcb2tdb(julian_date) when is_jd(julian_date) do
    NIF.tcb2tdb(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc """
  Parse a time string and convert it to SPICE Ephemeris Time (`ET`).

  Returns TDB seconds past J2000.
  """
  @spec str2et(String.t()) :: ephemeris_time()
  def str2et(time), do: NIF.str2et(time)

  @doc """
  Convert a UTC time string to SPICE Ephemeris Time (`ET`).

  Returns TDB seconds past J2000.
  """
  @spec utc2et(String.t()) :: ephemeris_time()
  def utc2et(time), do: NIF.utc2et(time)

  @doc """
  Convert a `DateTime` or `NaiveDateTime` to SPICE Ephemeris Time (`ET`).

  Offsets are applied as in `to_julian_date/1`. Returns TDB seconds past J2000,
  computed via ERFA (UTC -> TAI -> TT -> TDB), so no leap second kernel is
  required. Equivalent to `utc2et/1` for string inputs.
  """
  @spec to_et(DateTime.t() | NaiveDateTime.t()) :: ephemeris_time()
  def to_et(dt) when is_struct(dt, DateTime) or is_struct(dt, NaiveDateTime) do
    dt
    |> to_julian_date()
    |> utc2tai()
    |> tai2tt()
    |> tt2tdb()
    |> day2sec()
  end

  @doc """
  Convert SPICE Ephemeris Time (`ET`, TDB seconds past J2000) to a UTC
  `NaiveDateTime`.
  """
  @spec from_et(ephemeris_time()) :: NaiveDateTime.t()
  def from_et(et) when is_float(et) do
    et
    |> sec2day()
    |> tdb2tt()
    |> tt2tai()
    |> tai2utc()
    |> to_datetime()
  end

  @doc """
  Convert an epoch between SPICE uniform numeric time systems.

  This is the low-level SPICE interface and therefore uses scalar numeric
  epochs rather than split Julian Dates.
  """
  @spec unitim(float(), uniform_time_system(), uniform_time_system()) :: float()
  def unitim(epoch, insys, outsys), do: NIF.unitim(epoch, insys, outsys)

  @doc """
  Convert seconds past J2000 to a split Julian Date.

  ## Example

      iex> Astro.Time.sec2day(21600.0)
      {2451545.0, 0.25}
  """
  @spec sec2day(float()) :: julian_date()
  def sec2day(seconds), do: NIF.sec2day(seconds)

  @doc """
  Convert a split Julian Date to seconds past J2000.

  ## Example

      iex> Astro.Time.day2sec({2451545.0, 0.25})
      21600.0
  """
  @spec day2sec(julian_date()) :: float()
  def day2sec(julian_date) when is_jd(julian_date) do
    NIF.day2sec(elem(julian_date, 0), elem(julian_date, 1))
  end

  @doc false
  @spec j2000() :: julian_date()
  def j2000, do: {@j2000, 0.0}
end
