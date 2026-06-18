defmodule Skia.Codegen.Overlays do
  @moduledoc false

  use Skia.Codegen.Overlay

  command(:rect,
    native: {"Canvas", "draw_rect"},
    expand: :rect_paint,
    defaults: [radius: 0],
    native_shape: [
      args: [:self_ref, {:impl_trait, "AsRef", ["Rect"]}, {:ref, "Paint"}],
      returns: {:ref, "Self"}
    ]
  )

  command(:path,
    native: {"Canvas", "draw_path"},
    expand: :path_paint,
    native_shape: [
      args: [:self_ref, {:ref, "Path"}, {:ref, "Paint"}],
      returns: {:ref, "Self"}
    ]
  )

  command(:clip_path,
    native: {"Canvas", "clip_path"},
    expand: :clip_path,
    defaults: [antialias: true, fill_rule: :winding, clip_op: :intersect],
    native_shape: [
      args: [
        :self_ref,
        {:ref, "Path"},
        {:impl_trait, "Into", ["ClipOp"]},
        {:impl_trait, "Into", ["bool"]}
      ],
      returns: {:ref, "Self"}
    ]
  )

  command(:image,
    native: {"Canvas", "draw_image_with_sampling_options"},
    expand: :image_paint,
    native_shape: [
      args: [
        :self_ref,
        {:impl_trait, "AsRef", ["Image"]},
        {:impl_trait, "Into", ["Point"]},
        {:impl_trait, "Into", ["SamplingOptions"]},
        :any
      ],
      returns: {:ref, "Self"}
    ]
  )

  @spec validate_native!() :: :ok
  def validate_native! do
    overlays()
    |> Enum.each(fn {name, opts} ->
      {target, method} = Keyword.fetch!(opts, :native)
      shape = Keyword.fetch!(opts, :native_shape)

      Skia.Codegen.NativeSchema.assert_method_shape!(target, method, shape)

      name
    end)

    :ok
  end
end
