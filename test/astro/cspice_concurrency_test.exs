defmodule Astro.CSPICEConcurrencyTest do
  use ExUnit.Case, async: true

  @iterations 80

  test "concurrent SPICE-backed calls keep successful results and errors isolated" do
    orbit = %Astro.Orbit{
      rp: 7_000.0,
      ecc: 0.01,
      inc: 0.1,
      lnode: 0.2,
      argp: 0.3,
      m0: 0.4,
      t0: 0.0,
      mu: 398_600.435_436
    }

    success = fn ->
      assert {:ok, et} = Astro.Time.utc2et("2000-01-01T12:00:00")
      assert_in_delta et, 64.18392728473108, 1.0e-9
      assert {:ok, %Astro.State{}} = Astro.Orbit.state_at(orbit, 60.0)
    end

    failure = fn ->
      assert {:error, message} = Astro.Time.str2et("not a parseable spice time")
      assert is_binary(message)
      assert message != ""
    end

    jobs = Enum.flat_map(1..@iterations, fn _ -> [success, failure] end)

    results =
      jobs
      |> Task.async_stream(& &1.(),
        max_concurrency: System.schedulers_online() * 2,
        ordered: false,
        timeout: 15_000
      )
      |> Enum.to_list()

    assert Enum.all?(results, &match?({:ok, _}, &1))
  end
end
