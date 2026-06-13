defmodule Astro.NativeSchedulerTest do
  use ExUnit.Case, async: true

  @dirty_cpu "ERL_NIF_DIRTY_JOB_CPU_BOUND"
  @dirty_io "ERL_NIF_DIRTY_JOB_IO_BOUND"

  test "ephemeris state retrieval NIFs are dirty CPU jobs" do
    source = File.read!("c_src/ephemeris.c")

    assert_nif_flag(source, "spkezr", 5, @dirty_cpu)
    assert_nif_flag(source, "spkez", 5, @dirty_cpu)
    assert_nif_flag(source, "spkgeo", 4, @dirty_cpu)
    assert_normal_nif(source, "oscelt", 3)
    assert_normal_nif(source, "conics", 2)
  end

  test "direct SPK inspection is dirty IO and quick support lookups stay normal" do
    source = File.read!("c_src/support.c")

    assert_normal_nif(source, "bodc2n", 1)
    assert_normal_nif(source, "bodn2c", 1)
    assert_nif_flag(source, "spkobj", 1, @dirty_io)
    assert_normal_nif(source, "bodvcd", 2)
    assert_normal_nif(source, "bodvrd", 2)
  end

  test "CSPICE time parsers are dirty CPU and ERFA conversions stay normal" do
    source = File.read!("c_src/time.c")

    assert_normal_nif(source, "dtf2d", 6)
    assert_normal_nif(source, "utc2tai", 2)
    assert_normal_nif(source, "tai2tt", 2)
    assert_normal_nif(source, "tai2utc", 2)
    assert_normal_nif(source, "tt2tai", 2)
    assert_normal_nif(source, "tt2tcg", 2)
    assert_normal_nif(source, "tt2tdb", 6)
    assert_normal_nif(source, "tcg2tt", 2)
    assert_normal_nif(source, "tdb2tt", 6)
    assert_normal_nif(source, "tdb2tcb", 2)
    assert_normal_nif(source, "tcb2tdb", 2)
    assert_normal_nif(source, "jd2dt", 2)
    assert_nif_flag(source, "str2et", 1, @dirty_cpu)
    assert_nif_flag(source, "utc2et", 1, @dirty_cpu)
    assert_normal_nif(source, "unitim", 3)
    assert_normal_nif(source, "sec2day", 1)
    assert_normal_nif(source, "day2sec", 2)
  end

  defp assert_nif_flag(source, name, arity, flag) do
    assert source =~ ~r/\{"#{name}",\s*#{arity},\s*#{name},\s*#{flag}\}/
  end

  defp assert_normal_nif(source, name, arity) do
    assert source =~ ~r/\{"#{name}",\s*#{arity},\s*#{name}(?:,\s*0)?\}/
  end
end
