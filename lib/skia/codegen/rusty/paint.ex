defmodule Skia.Codegen.Rusty.Paint do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.Rusty.Paint
    end
  end

  defmacro with_fill_paint(do: body) do
    quote do
      case unwrap!(opt_fill_paint(var!(raw_opts), Atoms.fill())) do
        {:some, var!(paint)} ->
          unwrap!(apply_blend_mode(mut_ref(var!(paint)), var!(raw_opts)))
          unquote(body)

        :none ->
          :ok
      end
    end
  end

  defmacro with_stroke_paint(width, do: body) do
    quote do
      case unwrap!(opt_color(var!(raw_opts), Atoms.stroke())) do
        {:some, var!(color)} ->
          var!(stroke_paint_value) =
            unwrap!(stroke_paint(var!(color), unquote(width), var!(raw_opts)))

          unquote(body)

        :none ->
          :ok
      end
    end
  end
end
