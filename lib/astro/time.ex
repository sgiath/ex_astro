defmodule Astro.Time do
  @moduledoc """
  Module contains functions for manipulating time. It supports following time definitions:

    - UTC
    - International Atomic Time (TAI)
    - Terrestrial Time (TT)
    - Geocentric Coordinate Time (TCG)
    - Barycentric Dynamic Time (TDB)
    - Barycentric Coordinate Time (TCB)

  Unless specified differently all functions returns Julian Date as float number
  """
  use Astro.NIF, "time"

  require Logger

  def to_datetime(julian_date) when is_float(julian_date) do
    {y, m, d, h, mn, s, us} = jd2dt(julian_date)

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

  def to_julian_date(dt) when is_struct(dt, DateTime) or is_struct(dt, NaiveDateTime) do
    sec =
      case dt.microsecond do
        {_value, 0} -> dt.second * 1.0
        {value, _precision} -> dt.second + value / 1_000_000
      end

    dtf2d(dt.year, dt.month, dt.day, dt.hour, dt.minute, sec)
  end

  # NIF API

  @doc """
  Convert Gregorian date tuple to Julian Date
  """
  def dtf2d(_year, _month, _day, _hour, _min, _sec), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert Julian Date to Gregorian date tuple
  """
  def jd2dt(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert UTC to International Atomic Time (Julian Dates)
  """
  def utc2tai(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert International Atomic Time to Terrestrial Time (Julian Dates)
  """
  def tai2tt(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert International Atomic Time to UTC (Julian Dates)
  """
  def tai2utc(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert Terrestrial Time to International Atomic Time (Julian Dates)
  """
  def tt2tai(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert Terrestrial Time to Geocentric Coordinate Time (Julian Dates)
  """
  def tt2tcg(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert Terrestrial Time to Barycentric Dynamic Time (Julian Dates)
  """
  def tt2tdb(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert Geocentric Coordinate Time to Terrestrial Time (Julian Dates)
  """
  def tcg2tt(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert Barycentric Dynamic Time to Terrestrial Time (Julian Dates)
  """
  def tdb2tt(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert Barycentric Dynamic Time to Barycentric Coordinate Time (Julian Dates)
  """
  def tdb2tcb(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert Barycentric Coordinate Time to Barycentric Dynamic Time (Julian Dates)
  """
  def tcb2tdb(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert any datetime string to Ephemeris Time (ET) represented as number of seconds past J2000
  """
  def str2et(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert UTC datetime string to Ephemeris Time (ET) represented as number of seconds past J2000
  """
  def utc2et(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert epoch in one system to an another
  """
  def unitim(_epoch, _insys, _outsys), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert number of seconds past J2000 to Julian Date
  """
  def sec2day(_time), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Convert Julian Date to number of seconds past J2000
  """
  def day2sec(_time), do: :erlang.nif_error({:error, :not_loaded})
end
