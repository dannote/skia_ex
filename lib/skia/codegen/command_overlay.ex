defmodule Skia.Codegen.CommandOverlay do
  @moduledoc false

  alias RustQ.NativeRef
  alias Skia.Codegen.CommandOverlay.DSL
  alias Skia.Codegen.NativeSchema

  use DSL

  command(:clear, native: Canvas.clear())

  command(:rect,
    native: Canvas.draw_rect(),
    expand: :rect_paint,
    defaults: [radius: 0]
  )

  command(:oval, native: Canvas.draw_oval())

  command(:arc, native: Canvas.draw_arc())

  command(:circle, native: Canvas.draw_circle())

  command(:vertices, native: Canvas.draw_vertices())

  command(:line, native: Canvas.draw_line())

  command(:text_blob, native: Canvas.draw_text_blob())

  command(:picture, native: Canvas.draw_picture())

  command(:save, native: Canvas.save())

  command(:save_layer, native: Canvas.save_layer())

  command(:restore, native: Canvas.restore())

  command(:translate, native: Canvas.translate())

  command(:scale, native: Canvas.scale())

  command(:rotate, native: Canvas.rotate())

  command(:rotate_at, native: Canvas.rotate())

  command(:concat, native: Canvas.concat())

  command(:path,
    native: Canvas.draw_path(),
    expand: :path_paint
  )

  command(:clip_rect, native: Canvas.clip_rect())

  command(:clip_circle, expands_to: [Canvas.clip_path()])

  command(:clip_path,
    native: Canvas.clip_path(),
    expand: :clip_path,
    defaults: [antialias: true, fill_rule: :winding, clip_op: :intersect]
  )

  command(:image,
    native: Canvas.draw_image_with_sampling_options(),
    expand: :image_paint
  )

  @spec validate_native!() :: :ok
  def validate_native! do
    overlays()
    |> Enum.each(fn {_name, opts} ->
      opts
      |> Keyword.get(:native)
      |> validate_ref()

      opts
      |> Keyword.get(:expands_to, [])
      |> Enum.each(&validate_ref/1)
    end)

    :ok
  end

  defp validate_ref(nil), do: :ok
  defp validate_ref(%NativeRef{} = ref), do: NativeSchema.descriptor!(ref)
end
