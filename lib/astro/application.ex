defmodule Astro.Application do
  @moduledoc false
  use Application

  require Logger

  @impl Application
  def start(_type, _args) do
    :ex_astro
    |> Application.get_env(:spice_kernels, [])
    |> Enum.each(&load_kernel/1)

    Supervisor.start_link([], strategy: :one_for_one, name: Astro.Supervisor)
  end

  defp load_kernel(path) do
    case Astro.Kernel.load(path) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "SPICE kernel '#{path}' not loaded: #{reason}. " <>
            "Retry with Astro.Kernel.load/1 once the file exists."
        )
    end
  end
end
