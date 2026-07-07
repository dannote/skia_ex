defmodule Skia.Codegen.Rusty.Support.PaintMacros do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.Rusty.Support.PaintMacros
    end
  end

  defmacro with_fill_paint(do: body) do
    quote do
      case opt_fill_paint(var!(raw_opts), Atoms.fill()) do
        {:some, var!(paint)} ->
          apply_blend_mode(var!(paint), var!(raw_opts))
          unquote(body)

        :none ->
          :ok
      end
    end
  end

  defmacro with_stroke_paint(width, do: body) do
    quote do
      case opt_color(var!(raw_opts), Atoms.stroke()) do
        {:some, var!(color)} ->
          var!(stroke_paint_value) = stroke_paint(var!(color), unquote(width), var!(raw_opts))

          unquote(body)

        :none ->
          :ok
      end
    end
  end
end
