defmodule Skia.PackageTest do
  use ExUnit.Case, async: true

  test "ships runtime metadata without development generators" do
    files = Mix.Project.config() |> Keyword.fetch!(:package) |> Keyword.fetch!(:files)

    assert "lib/skia/command/registry.ex" in files
    refute Enum.any?(files, &String.starts_with?(&1, "lib/skia/codegen/"))
    refute Enum.any?(files, &String.starts_with?(&1, "lib/mix/"))
  end

  test "runtime command metadata contains portable type descriptors" do
    types =
      Skia.Command.Registry.all()
      |> Enum.flat_map(fn {_name, spec} ->
        Enum.map(spec[:args], &elem(&1, 1)) ++ Enum.map(spec[:opts], &Keyword.fetch!(&1, :type))
      end)

    assert Enum.all?(types, &portable_type?/1)
    refute Enum.any?(types, &is_struct/1)
  end

  defp portable_type?({:tuple, types}), do: Enum.all?(types, &portable_type?/1)

  defp portable_type?({:external, module, name}),
    do: is_atom(module) and is_atom(name)

  defp portable_type?(category), do: is_atom(category)
end
