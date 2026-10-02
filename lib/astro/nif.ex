defmodule Astro.NIF do
  @moduledoc false
  @on_load :load_nifs

  defp load_nifs do
    :ex_astro
    |> Application.app_dir("priv/ex_astro_nif")
    |> String.to_charlist()
    |> :erlang.load_nif(0)
  end

  @type result(value) :: {:ok, value} | {:error, String.t()}
  @type state_result :: {:ok, [float()], float()} | {:error, String.t()}
  @type star_entry :: {float(), float(), float(), float(), float(), float()}

  @spec kernel_furnsh(String.t()) :: :ok | {:error, String.t()}
  def kernel_furnsh(_path), do: :erlang.nif_error({:error, :not_loaded})

  @spec kernel_unload(String.t()) :: :ok | {:error, String.t()}
  def kernel_unload(_path), do: :erlang.nif_error({:error, :not_loaded})

  @spec kernel_clear() :: :ok | {:error, String.t()}
  def kernel_clear, do: :erlang.nif_error({:error, :not_loaded})

  @spec kernel_list() :: result([String.t()])
  def kernel_list, do: :erlang.nif_error({:error, :not_loaded})

  @spec dtf2d(integer(), integer(), integer(), integer(), integer(), float()) ::
          {float(), float()}
  def dtf2d(_year, _month, _day, _hour, _min, _sec), do: :erlang.nif_error({:error, :not_loaded})

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

  @spec str2et(String.t()) :: {:ok, float()} | {:error, String.t()}
  def str2et(_time), do: :erlang.nif_error({:error, :not_loaded})

  @spec utc2et(String.t()) :: {:ok, float()} | {:error, String.t()}
  def utc2et(_time), do: :erlang.nif_error({:error, :not_loaded})

  @spec unitim(float(), String.t(), String.t()) :: {:ok, float()} | {:error, String.t()}
  def unitim(_epoch, _insys, _outsys), do: :erlang.nif_error({:error, :not_loaded})

  @spec sec2day(float()) :: {float(), float()}
  def sec2day(_seconds), do: :erlang.nif_error({:error, :not_loaded})

  @spec day2sec(float(), float()) :: float()
  def day2sec(_jd1, _jd2), do: :erlang.nif_error({:error, :not_loaded})

  @spec spkezr(String.t(), float(), String.t(), String.t(), String.t()) :: state_result()
  def spkezr(_target, _et, _reference_frame, _abcorr, _observer), do: :erlang.nif_error({:error, :not_loaded})

  @spec spkez(integer(), float(), String.t(), String.t(), integer()) :: state_result()
  def spkez(_target, _et, _reference_frame, _abcorr, _observer), do: :erlang.nif_error({:error, :not_loaded})

  @spec spkgeo(integer(), float(), String.t(), integer()) :: state_result()
  def spkgeo(_target, _et, _reference_frame, _observer), do: :erlang.nif_error({:error, :not_loaded})

  @spec oscelt([float()], float(), float()) :: result([float()])
  def oscelt(_state, _et, _mu), do: :erlang.nif_error({:error, :not_loaded})

  @spec conics([float()], float()) :: result([float()])
  def conics(_elements, _et), do: :erlang.nif_error({:error, :not_loaded})

  @spec bodc2n(integer()) :: result(String.t())
  def bodc2n(_code), do: :erlang.nif_error({:error, :not_loaded})

  @spec bodn2c(String.t()) :: result(integer())
  def bodn2c(_name), do: :erlang.nif_error({:error, :not_loaded})

  @spec spkobj(String.t()) :: result([integer()])
  def spkobj(_path), do: :erlang.nif_error({:error, :not_loaded})

  @spec bodvcd(integer(), String.t()) :: result([float()])
  def bodvcd(_code, _item), do: :erlang.nif_error({:error, :not_loaded})

  @spec bodvrd(String.t(), String.t()) :: result([float()])
  def bodvrd(_name, _item), do: :erlang.nif_error({:error, :not_loaded})

  @spec pmsafe(float(), float(), float(), float(), float(), float(), {float(), float()}, {float(), float()}) ::
          {:ok, star_entry(), integer()}
  def pmsafe(_ra, _dec, _pmr, _pmd, _px, _rv, _epoch1, _epoch2), do: :erlang.nif_error({:error, :not_loaded})

  @spec starpv(float(), float(), float(), float(), float(), float()) :: {:ok, [float()], integer()}
  def starpv(_ra, _dec, _pmr, _pmd, _px, _rv), do: :erlang.nif_error({:error, :not_loaded})

  @spec pvstar([float()]) :: {:ok, star_entry(), integer()}
  def pvstar(_pv), do: :erlang.nif_error({:error, :not_loaded})
end
