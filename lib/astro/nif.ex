defmodule Astro.NIF do
  @moduledoc false

  defmacro __using__(name) do
    quote do
      @on_load :load_nifs

      defp load_nifs do
        :ex_astro
        |> Application.app_dir("priv/#{unquote(name)}")
        |> String.to_charlist()
        |> :erlang.load_nif(0)
      end

      @doc false
      def kernel_furnsh(_path), do: :erlang.nif_error({:error, :not_loaded})
      @doc false
      def kernel_unload(_path), do: :erlang.nif_error({:error, :not_loaded})
      @doc false
      def kernel_clear, do: :erlang.nif_error({:error, :not_loaded})
      @doc false
      def kernel_list, do: :erlang.nif_error({:error, :not_loaded})
      @doc false
      def kernel_loaded_direct(_path), do: :erlang.nif_error({:error, :not_loaded})
    end
  end
end
