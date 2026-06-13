defmodule Astro.SupportTest do
  use ExUnit.Case, async: true

  test "dirty scheduled SPK inspection preserves public return shape" do
    assert {:ok, ids} = Astro.Support.spkobj("priv/kernels/spk/planets/de440.bsp")

    assert 399 in ids
  end
end
