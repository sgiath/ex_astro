defmodule Astro.Time.NIF do
  @moduledoc false

  use Astro.NIF, "time"

  @spec dtf2d(integer(), integer(), integer(), integer(), integer(), float()) ::
          {float(), float()}
  def dtf2d(_year, _month, _day, _hour, _min, _sec),
    do: :erlang.nif_error({:error, :not_loaded})

  @spec jd2dt(float(), float()) ::
          {integer(), integer(), integer(), integer(), integer(), integer(), integer()}
  def jd2dt(_jd1, _jd2), do: :erlang.nif_error({:error, :not_loaded})

  @spec utc2tai(float(), float()) :: {float(), float()}
  def utc2tai(_utc1, _utc2), do: :erlang.nif_error({:error, :not_loaded})

  @spec tai2tt(float(), float()) :: {float(), float()}
  def tai2tt(_tai1, _tai2), do: :erlang.nif_error({:error, :not_loaded})

  @spec tai2utc(float(), float()) :: {float(), float()}
  def tai2utc(_tai1, _tai2), do: :erlang.nif_error({:error, :not_loaded})

  @spec tt2tai(float(), float()) :: {float(), float()}
  def tt2tai(_tt1, _tt2), do: :erlang.nif_error({:error, :not_loaded})

  @spec tt2tcg(float(), float()) :: {float(), float()}
  def tt2tcg(_tt1, _tt2), do: :erlang.nif_error({:error, :not_loaded})

  @spec tt2tdb(float(), float(), float(), float(), float(), float()) :: {float(), float()}
  def tt2tdb(_tt1, _tt2, _ut, _elong, _u, _v), do: :erlang.nif_error({:error, :not_loaded})

  @spec tcg2tt(float(), float()) :: {float(), float()}
  def tcg2tt(_tcg1, _tcg2), do: :erlang.nif_error({:error, :not_loaded})

  @spec tdb2tt(float(), float(), float(), float(), float(), float()) :: {float(), float()}
  def tdb2tt(_tdb1, _tdb2, _ut, _elong, _u, _v), do: :erlang.nif_error({:error, :not_loaded})

  @spec tdb2tcb(float(), float()) :: {float(), float()}
  def tdb2tcb(_tdb1, _tdb2), do: :erlang.nif_error({:error, :not_loaded})

  @spec tcb2tdb(float(), float()) :: {float(), float()}
  def tcb2tdb(_tcb1, _tcb2), do: :erlang.nif_error({:error, :not_loaded})

  @spec str2et(String.t()) :: float()
  def str2et(_time), do: :erlang.nif_error({:error, :not_loaded})

  @spec utc2et(String.t()) :: float()
  def utc2et(_time), do: :erlang.nif_error({:error, :not_loaded})

  @spec unitim(float(), String.t(), String.t()) :: float()
  def unitim(_epoch, _insys, _outsys), do: :erlang.nif_error({:error, :not_loaded})

  @spec sec2day(float()) :: {float(), float()}
  def sec2day(_seconds), do: :erlang.nif_error({:error, :not_loaded})

  @spec day2sec(float(), float()) :: float()
  def day2sec(_jd1, _jd2), do: :erlang.nif_error({:error, :not_loaded})
end
