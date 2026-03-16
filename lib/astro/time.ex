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

  alias Astro.Time.NIF

  @j2000 2_451_545.0

  @type jd_part :: float()
  @type julian_date :: {jd_part(), jd_part()}
  @type ephemeris_time :: float()
  @type radians :: float()
  @type kilometers :: float()
  @type gregorian_datetime_tuple ::
          {year :: integer(), month :: integer(), day :: integer(), hour :: integer(),
           minute :: integer(), second :: integer(), microsecond :: integer()}
  @type uniform_time_system :: String.t()

  defguard is_jd(jd)
           when is_tuple(jd) and tuple_size(jd) == 2 and
                  is_float(elem(jd, 0)) and is_float(elem(jd, 1))

  @doc """
  Convert a split Julian Date to a `NaiveDateTime`.

  ## Example

      iex> Astro.Time.to_datetime({2451545.0, 0.0})
      ~N[2000-01-01 12:00:00.000000]
  """
  @spec to_datetime(julian_date()) :: NaiveDateTime.t()
  def to_datetime(julian_date) when is_jd(julian_date) do
    {y, m, d, h, mn, s, us} = NIF.jd2dt(elem(julian_date, 0), elem(julian_date, 1))

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

  @doc """
  Convert a `DateTime` or `NaiveDateTime` to a split Julian Date.

  Calendar fields are interpreted as `UTC`.
  """
  @spec to_julian_date(DateTime.t() | NaiveDateTime.t()) :: julian_date()
  def to_julian_date(dt) when is_struct(dt, DateTime) or is_struct(dt, NaiveDateTime) do
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
  Convert a split Julian Date to Gregorian calendar components.

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

  - `ut` - universal time of day in seconds
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
