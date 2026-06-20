defmodule Skia.Codegen.NativeDriftTest do
  use ExUnit.Case, async: true

  test "direct native command refs are visible as generated Canvas method calls" do
    generated_calls = generated_method_calls()

    missing =
      Skia.Codegen.Commands.all()
      |> Enum.flat_map(fn {name, spec} ->
        case Keyword.fetch(spec, :native) do
          {:ok,
           %RustQ.Native.Descriptor{ref: %RustQ.Native.Ref{target: "Canvas", member: member}}} ->
            if canvas_call?(generated_calls, member), do: [], else: [{name, member}]

          :error ->
            []
        end
      end)

    assert missing == []
  end

  test "composite command refs are visible as generated Canvas method calls" do
    generated_calls = generated_method_calls()

    missing =
      Skia.Codegen.Commands.all()
      |> Enum.flat_map(fn {name, spec} ->
        spec
        |> Keyword.get(:expands_to, [])
        |> Enum.reject(fn %RustQ.Native.Descriptor{
                            ref: %RustQ.Native.Ref{target: "Canvas", member: member}
                          } ->
          canvas_call?(generated_calls, member)
        end)
        |> Enum.map(fn %RustQ.Native.Descriptor{ref: %RustQ.Native.Ref{member: member}} ->
          {name, member}
        end)
      end)

    assert missing == []
  end

  defp generated_method_calls do
    "native/skia_native/src/generated_*.rs"
    |> Path.wildcard()
    |> Enum.flat_map(fn path -> path |> File.read!() |> RustQ.Syn.method_calls!() end)
    |> Enum.uniq()
  end

  defp canvas_call?(calls, member) do
    Enum.any?(calls, &match?(%RustQ.Syn.MethodCall{receiver: "canvas", method: ^member}, &1))
  end
end
