defmodule Skia.Command do
  import Inspect.Algebra

  @moduledoc """
  Normalized drawing command.

  Commands are intentionally small, explicit data structures. They are easy to
  inspect in tests and can later be encoded into a compact binary protocol for a
  Rustler NIF.
  """

  alias RustQ.Meta.Type
  alias Skia.Codegen.Command.Registry, as: Commands
  alias Skia.{ColorFilter, Command, Font, Image, ImageFilter, MaskFilter, Paint, Path, PathEffect}
  alias Skia.{Picture, SamplingOptions, TextBlob, Vertices}

  @type color ::
          {:rgba, non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  @type t :: %__MODULE__{op: atom(), args: [term()], opts: keyword()}

  defstruct [:op, args: [], opts: []]

  @spec build!(atom(), [term()], keyword()) :: t()
  def build!(name, args, opts) when is_atom(name) and is_list(args) and is_list(opts) do
    spec = Commands.fetch!(name)
    args = normalize_args!(name, args, Keyword.get(spec, :args, []))

    opts =
      normalize_opts!(
        name,
        Keyword.merge(Keyword.get(spec, :defaults, []), opts),
        Keyword.get(spec, :opts, [])
      )

    %__MODULE__{op: Keyword.get(spec, :op, name), args: args, opts: opts}
  end

  defp normalize_args!(name, args, arg_specs) when length(args) == length(arg_specs) do
    arg_specs
    |> Enum.zip(args)
    |> Enum.map(fn {{arg_name, type}, value} -> normalize_value!(name, arg_name, type, value) end)
  end

  defp normalize_args!(name, args, arg_specs) do
    raise ArgumentError,
          "invalid argument count for #{name}: expected #{length(arg_specs)}, got #{length(args)}"
  end

  defp normalize_opts!(name, opts, option_specs) do
    opts = expand_paint_opts(opts)

    Enum.map(option_specs, fn option_spec ->
      key = Keyword.fetch!(option_spec, :name)
      type = Keyword.fetch!(option_spec, :type)
      required? = Keyword.get(option_spec, :required, false)

      case Keyword.fetch(opts, key) do
        {:ok, value} ->
          {key, normalize_value!(name, key, type, value)}

        :error when required? ->
          raise ArgumentError, "missing required option #{inspect(key)} for #{name}"

        :error ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_meta_value!(name, key, type, value) do
    type
    |> Type.category()
    |> normalize_category_value(name, key, type, value)
  end

  defp normalize_category_value(:number, _name, _key, _type, value)
       when is_integer(value) or is_float(value),
       do: value * 1.0

  defp normalize_category_value(:integer, _name, _key, _type, value) when is_integer(value),
    do: value

  defp normalize_category_value(:boolean, _name, _key, _type, value) when is_boolean(value),
    do: value

  defp normalize_category_value(category, _name, _key, _type, value)
       when category in [:atom, :enum] and is_atom(value),
       do: value

  defp normalize_category_value(:string, _name, _key, _type, value) when is_binary(value),
    do: value

  defp normalize_category_value(:term, _name, :spans, _type, value), do: normalize_spans!(value)
  defp normalize_category_value(:term, _name, _key, _type, value), do: value

  defp normalize_category_value({:tuple, types}, _name, _key, _type, value) when is_tuple(value),
    do: normalize_tuple!(types, value)

  defp normalize_category_value(_category, name, key, type, value),
    do: normalize_external_value!(name, key, type, value)

  defp normalize_external_value!(name, key, type, value) do
    with :error <- normalize_external_struct(type, value),
         :error <- normalize_external_filter(type, value),
         :error <- normalize_external_special(type, value) do
      raise ArgumentError,
            "invalid #{inspect(key)} for #{name}: expected #{inspect(type)}, got #{inspect(value)}"
    end
  end

  defp normalize_external_struct(type, value) do
    cond do
      external_struct?(type, value, Paint) -> value
      external_struct?(type, value, Path) -> value
      external_struct?(type, value, Image) -> value
      external_struct?(type, value, Picture) -> value
      external_struct?(type, value, TextBlob) -> value
      external_struct?(type, value, Font) -> value
      true -> :error
    end
  end

  defp normalize_external_filter(type, value) do
    cond do
      Type.external?(type, ImageFilter, :t) -> normalize_image_filter!(value)
      Type.external?(type, ColorFilter, :t) -> normalize_color_filter!(value)
      Type.external?(type, MaskFilter, :t) -> normalize_mask_filter!(value)
      Type.external?(type, PathEffect, :t) -> normalize_path_effect!(value)
      Type.external?(type, SamplingOptions, :t) -> normalize_sampling_options!(value)
      true -> :error
    end
  end

  defp normalize_external_special(type, value) do
    cond do
      Type.external?(type, Command, :color) -> normalize_color!(value)
      external_struct?(type, value, Vertices) -> normalize_vertices!(value)
      true -> :error
    end
  end

  defp external_struct?(type, value, module) do
    Type.external?(type, module, :t) and is_struct(value, module)
  end

  defp normalize_value!(name, key, %Type{} = type, value) do
    normalize_meta_value!(name, key, type, value)
  end

  defp normalize_value!(name, key, type, value) do
    raise ArgumentError,
          "invalid #{inspect(key)} for #{name}: expected #{inspect(type)}, got #{inspect(value)}"
  end

  defp expand_paint_opts(opts) do
    case Keyword.pop(opts, :paint) do
      {nil, opts} -> opts
      {%Paint{} = paint, opts} -> Keyword.merge(Paint.to_opts(paint), opts)
      {paint, _opts} -> raise ArgumentError, "invalid paint #{inspect(paint)}"
    end
  end

  defp normalize_tuple!(types, value) when tuple_size(value) == length(types) do
    values = Tuple.to_list(value)

    types
    |> Enum.zip(values)
    |> Enum.map(fn {type, item} -> normalize_value!(:tuple, :item, type, item) end)
    |> List.to_tuple()
  end

  defp normalize_tuple!(types, value) do
    raise ArgumentError, "expected #{length(types)}-tuple, got #{inspect(value)}"
  end

  defp normalize_image_filter!(%Skia.ImageFilter.Blur{
         sigma_x: sigma_x,
         sigma_y: sigma_y,
         tile_mode: tile_mode
       })
       when is_atom(tile_mode) do
    {:blur_filter, normalize_number!(sigma_x), normalize_number!(sigma_y), tile_mode}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.Compose{outer: outer, inner: inner}) do
    {:compose_filter, normalize_image_filter!(outer), normalize_image_filter!(inner)}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.Offset{x: x, y: y, input: input}) do
    {:offset_filter, normalize_number!(x), normalize_number!(y),
     normalize_optional_filter!(input)}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.DropShadow{} = shadow) do
    {:drop_shadow_filter, normalize_number!(shadow.dx), normalize_number!(shadow.dy),
     normalize_number!(shadow.sigma_x), normalize_number!(shadow.sigma_y),
     normalize_color!(shadow.color),
     {normalize_optional_filter!(shadow.input), shadow.shadow_only}}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.ColorFilter{color_filter: filter, input: input}) do
    {:color_filter_image_filter, normalize_color_filter!(filter),
     normalize_optional_filter!(input)}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.Shader{shader: shader}) do
    {:shader_image_filter, normalize_color!(shader)}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.Magnifier{} = filter) do
    {:magnifier_filter, normalize_rect!(filter.bounds), normalize_number!(filter.zoom),
     normalize_number!(filter.inset), normalize_sampling_options!(filter.sampling),
     normalize_optional_filter!(filter.input)}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.MatrixConvolution{} = filter) do
    {:matrix_convolution_filter, filter.kernel_size,
     Enum.map(filter.kernel, &normalize_number!/1),
     {normalize_number!(filter.gain), normalize_number!(filter.bias), filter.offset, filter.tile,
      filter.convolve_alpha, normalize_optional_filter!(filter.input)}}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.MatrixTransform{} = filter) do
    {:matrix_transform_filter, normalize_optional_matrix!(filter.matrix),
     normalize_sampling_options!(filter.sampling), normalize_optional_filter!(filter.input)}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.Merge{filters: filters}) when is_list(filters) do
    {:merge_filter, Enum.map(filters, &normalize_optional_filter!/1)}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.Tile{} = filter) do
    {:tile_filter, normalize_rect!(filter.src), normalize_rect!(filter.dst),
     normalize_optional_filter!(filter.input)}
  end

  defp normalize_image_filter!(%Skia.ImageFilter.Morphology{
         op: op,
         radius_x: x,
         radius_y: y,
         input: input
       })
       when op in [:dilate, :erode] do
    {:morphology_filter, op, normalize_number!(x), normalize_number!(y),
     normalize_optional_filter!(input)}
  end

  defp normalize_image_filter!({:blur, sigma}) do
    normalize_image_filter!(Skia.ImageFilter.blur(sigma))
  end

  defp normalize_image_filter!({:blur, sigma_x, sigma_y}) do
    normalize_image_filter!(Skia.ImageFilter.blur(sigma_x, sigma_y))
  end

  defp normalize_image_filter!(value),
    do: raise(ArgumentError, "invalid image filter #{inspect(value)}")

  defp normalize_optional_filter!(nil), do: nil
  defp normalize_optional_filter!(filter), do: normalize_image_filter!(filter)

  defp normalize_color!(%Skia.Shader.LinearGradient{
         from: from,
         to: to,
         colors: colors,
         tile_mode: tile_mode,
         matrix: matrix
       }) do
    normalize_color!({:linear_gradient, from, to, colors, tile_mode, matrix})
  end

  defp normalize_color!(%Skia.Shader.TwoPointConicalGradient{} = gradient) do
    normalize_color!(
      {:two_point_conical_gradient, gradient.start, gradient.start_radius, gradient.end,
       gradient.end_radius, gradient.colors, gradient.tile_mode, gradient.matrix}
    )
  end

  defp normalize_color!(%Skia.Shader.ColorShader{color: color}) do
    {:color_shader, normalize_color!(color)}
  end

  defp normalize_color!(%Skia.Shader.RadialGradient{
         center: center,
         radius: radius,
         colors: colors,
         tile_mode: tile_mode,
         matrix: matrix
       }) do
    normalize_color!({:radial_gradient, center, radius, colors, tile_mode, matrix})
  end

  defp normalize_color!(%Skia.Shader.SweepGradient{
         center: center,
         start_degrees: start_degrees,
         end_degrees: end_degrees,
         colors: colors,
         tile_mode: tile_mode,
         matrix: matrix
       }) do
    normalize_color!(
      {:sweep_gradient, center, start_degrees, end_degrees, colors, tile_mode, matrix}
    )
  end

  defp normalize_color!(%Skia.Shader.RuntimeEffect{} = shader) do
    {float_uniforms, int_uniforms} = normalize_uniforms!(shader.uniforms)

    {:runtime_effect_shader, shader.effect, float_uniforms, int_uniforms,
     normalize_children!(shader.children), normalize_optional_matrix!(shader.matrix)}
  end

  defp normalize_color!(%Skia.Shader.ImageShader{} = shader) do
    {:image_shader, shader.image, shader.tile_x, shader.tile_y,
     normalize_sampling_options!(shader.sampling), normalize_optional_matrix!(shader.matrix)}
  end

  defp normalize_color!(%Skia.Shader.PictureShader{} = shader) do
    {:picture_shader, shader.picture, shader.tile_x, shader.tile_y, shader.filter,
     normalize_optional_matrix!(shader.matrix), normalize_optional_rect!(shader.tile_rect)}
  end

  defp normalize_color!(%Skia.Shader.GradientStop{color: color, position: position}) do
    normalize_color!({:gradient_stop, color, position})
  end

  defp normalize_color!(
         {:runtime_effect_shader, %Skia.RuntimeEffect{} = effect, uniforms, matrix}
       ) do
    {float_uniforms, int_uniforms} = normalize_uniforms!(uniforms)

    {:runtime_effect_shader, effect, float_uniforms, int_uniforms, [],
     normalize_optional_matrix!(matrix)}
  end

  defp normalize_color!({:image_shader, %Skia.Image{} = image, tile_x, tile_y, sampling, matrix})
       when is_atom(tile_x) and is_atom(tile_y) do
    {:image_shader, image, tile_x, tile_y, normalize_sampling_options!(sampling),
     normalize_optional_matrix!(matrix)}
  end

  defp normalize_color!(
         {:picture_shader, %Skia.Picture{} = picture, tile_x, tile_y, filter, matrix, tile_rect}
       )
       when is_atom(tile_x) and is_atom(tile_y) and is_atom(filter) do
    {:picture_shader, picture, tile_x, tile_y, filter, normalize_optional_matrix!(matrix),
     normalize_optional_rect!(tile_rect)}
  end

  defp normalize_color!({:gradient_stop, color, position}) do
    {:gradient_stop, normalize_color!(color), normalize_number!(position)}
  end

  defp normalize_color!({:linear_gradient, from, to, colors}) when is_list(colors) do
    normalize_color!({:linear_gradient, from, to, colors, :clamp, nil})
  end

  defp normalize_color!({:linear_gradient, from, to, colors, matrix}) when is_list(colors) do
    normalize_color!({:linear_gradient, from, to, colors, :clamp, matrix})
  end

  defp normalize_color!({:linear_gradient, from, to, colors, tile_mode, matrix})
       when is_list(colors) and is_atom(tile_mode) do
    {:linear_gradient, normalize_point!(from), normalize_point!(to),
     Enum.map(colors, &normalize_color!/1), tile_mode, normalize_optional_matrix!(matrix)}
  end

  defp normalize_color!(
         {:two_point_conical_gradient, start, start_radius, finish, end_radius, colors}
       )
       when is_list(colors) do
    normalize_color!(
      {:two_point_conical_gradient, start, start_radius, finish, end_radius, colors, :clamp, nil}
    )
  end

  defp normalize_color!(
         {:two_point_conical_gradient, start, start_radius, finish, end_radius, colors, tile_mode,
          matrix}
       )
       when is_list(colors) and is_atom(tile_mode) do
    {:two_point_conical_gradient, normalize_point!(start), normalize_number!(start_radius),
     normalize_point!(finish), normalize_number!(end_radius),
     {Enum.map(colors, &normalize_color!/1), tile_mode, normalize_optional_matrix!(matrix)}}
  end

  defp normalize_color!({:radial_gradient, center, radius, colors}) when is_list(colors) do
    normalize_color!({:radial_gradient, center, radius, colors, :clamp, nil})
  end

  defp normalize_color!({:radial_gradient, center, radius, colors, matrix})
       when is_list(colors) do
    normalize_color!({:radial_gradient, center, radius, colors, :clamp, matrix})
  end

  defp normalize_color!({:radial_gradient, center, radius, colors, tile_mode, matrix})
       when is_list(colors) and is_atom(tile_mode) do
    {:radial_gradient, normalize_point!(center), normalize_number!(radius),
     Enum.map(colors, &normalize_color!/1), tile_mode, normalize_optional_matrix!(matrix)}
  end

  defp normalize_color!({:sweep_gradient, center, start_degrees, end_degrees, colors})
       when is_list(colors) do
    normalize_color!({:sweep_gradient, center, start_degrees, end_degrees, colors, :clamp, nil})
  end

  defp normalize_color!({:sweep_gradient, center, start_degrees, end_degrees, colors, matrix})
       when is_list(colors) do
    normalize_color!(
      {:sweep_gradient, center, start_degrees, end_degrees, colors, :clamp, matrix}
    )
  end

  defp normalize_color!(
         {:sweep_gradient, center, start_degrees, end_degrees, colors, tile_mode, matrix}
       )
       when is_list(colors) and is_atom(tile_mode) do
    {:sweep_gradient, normalize_point!(center), normalize_number!(start_degrees),
     normalize_number!(end_degrees), Enum.map(colors, &normalize_color!/1), tile_mode,
     normalize_optional_matrix!(matrix)}
  end

  defp normalize_color!({:color_shader, color}) do
    {:color_shader, normalize_color!(color)}
  end

  defp normalize_color!({:rgba, red, green, blue, alpha}) do
    {:rgba, channel!(red), channel!(green), channel!(blue), channel!(alpha)}
  end

  defp normalize_color!({red, green, blue}) do
    {:rgba, channel!(red), channel!(green), channel!(blue), 255}
  end

  defp normalize_color!({red, green, blue, alpha}) do
    {:rgba, channel!(red), channel!(green), channel!(blue), channel!(alpha)}
  end

  defp normalize_color!(color) when is_atom(color) do
    case color do
      :black -> {:rgba, 0, 0, 0, 255}
      :white -> {:rgba, 255, 255, 255, 255}
      :red -> {:rgba, 255, 0, 0, 255}
      :green -> {:rgba, 0, 128, 0, 255}
      :blue -> {:rgba, 0, 0, 255, 255}
      :transparent -> {:rgba, 0, 0, 0, 0}
      _ -> raise ArgumentError, "unknown color #{inspect(color)}"
    end
  end

  defp normalize_color!("#" <> hex) when byte_size(hex) in [6, 8] do
    [red, green, blue | rest] =
      hex
      |> String.graphemes()
      |> Enum.chunk_every(2)
      |> Enum.map(fn pair ->
        pair
        |> Enum.join()
        |> Integer.parse(16)
        |> case do
          {value, ""} -> value
          _ -> raise ArgumentError, "invalid color ##{hex}"
        end
      end)

    alpha = List.first(rest) || 255
    {:rgba, red, green, blue, alpha}
  end

  defp normalize_color!(color), do: raise(ArgumentError, "invalid color #{inspect(color)}")

  defp normalize_uniforms!(uniforms) when is_map(uniforms),
    do: uniforms |> Map.to_list() |> normalize_uniforms!()

  defp normalize_uniforms!(uniforms) when is_list(uniforms) do
    {ints, floats} =
      Enum.split_with(uniforms, fn {_name, value} -> match?({:int, _}, value) end)

    {
      Enum.map(floats, fn
        {name, {:float, value}} -> {to_string(name), normalize_uniform_float!(value)}
        {name, value} -> {to_string(name), normalize_uniform_float!(value)}
      end),
      Enum.map(ints, fn {name, {:int, value}} ->
        {to_string(name), normalize_uniform_int!(value)}
      end)
    }
  end

  defp normalize_uniform_float!(value) when is_number(value), do: [normalize_number!(value)]

  defp normalize_uniform_float!(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> normalize_uniform_float!()

  defp normalize_uniform_float!(values) when is_list(values),
    do: Enum.map(values, &normalize_number!/1)

  defp normalize_uniform_int!(value) when is_integer(value), do: [value]

  defp normalize_uniform_int!(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> normalize_uniform_int!()

  defp normalize_uniform_int!(values) when is_list(values),
    do: Enum.map(values, fn value when is_integer(value) -> value end)

  defp normalize_children!(children) when is_map(children),
    do: children |> Map.to_list() |> normalize_children!()

  defp normalize_children!(children) when is_list(children) do
    Enum.map(children, fn {name, shader} -> {to_string(name), normalize_color!(shader)} end)
  end

  defp normalize_color_filter!(%Skia.ColorFilter.Blend{color: color, blend_mode: blend_mode})
       when is_atom(blend_mode) do
    {:blend_color_filter, normalize_color!(color), blend_mode}
  end

  defp normalize_color_filter!(%Skia.ColorFilter.Matrix{matrix: matrix, clamp: clamp})
       when is_list(matrix) and is_boolean(clamp) do
    {:matrix_color_filter, Enum.map(matrix, &normalize_number!/1), clamp}
  end

  defp normalize_color_filter!(%Skia.ColorFilter.Compose{outer: outer, inner: inner}) do
    {:compose_color_filter, normalize_color_filter!(outer), normalize_color_filter!(inner)}
  end

  defp normalize_color_filter!(%Skia.ColorFilter.Luma{}), do: :luma_color_filter

  defp normalize_color_filter!(value),
    do: raise(ArgumentError, "invalid color filter #{inspect(value)}")

  defp normalize_mask_filter!(%Skia.MaskFilter.Blur{
         style: style,
         sigma: sigma,
         respect_ctm: respect_ctm
       })
       when is_atom(style) and is_boolean(respect_ctm) do
    {:blur_mask_filter, style, normalize_number!(sigma), respect_ctm}
  end

  defp normalize_mask_filter!(value),
    do: raise(ArgumentError, "invalid mask filter #{inspect(value)}")

  defp normalize_vertices!(%Skia.Vertices{
         mode: mode,
         positions: positions,
         colors: colors,
         indices: indices
       })
       when is_atom(mode) and is_list(positions) and is_list(colors) do
    {mode, Enum.map(positions, &normalize_point!/1), Enum.map(colors, &normalize_color!/1),
     indices}
  end

  defp normalize_vertices!(value), do: raise(ArgumentError, "invalid vertices #{inspect(value)}")

  defp normalize_path_effect!(%Skia.PathEffect.Dash{intervals: intervals, phase: phase}) do
    {:dash_path_effect, Enum.map(intervals, &normalize_number!/1), normalize_number!(phase)}
  end

  defp normalize_path_effect!(%Skia.PathEffect.Corner{radius: radius}) do
    {:corner_path_effect, normalize_number!(radius)}
  end

  defp normalize_path_effect!(%Skia.PathEffect.Trim{start: start, stop: stop, mode: mode})
       when mode in [:normal, :inverted] do
    {:trim_path_effect, normalize_number!(start), normalize_number!(stop), mode}
  end

  defp normalize_path_effect!(%Skia.PathEffect.Discrete{} = effect) do
    {:discrete_path_effect, normalize_number!(effect.segment_length),
     normalize_number!(effect.deviation), effect.seed}
  end

  defp normalize_path_effect!(%Skia.PathEffect.Path1D{} = effect) do
    {:path_1d_effect, effect.path, normalize_number!(effect.advance),
     normalize_number!(effect.phase), effect.style}
  end

  defp normalize_path_effect!(%Skia.PathEffect.Line2D{} = effect) do
    {:line_2d_effect, normalize_number!(effect.width), normalize_optional_matrix!(effect.matrix)}
  end

  defp normalize_path_effect!(%Skia.PathEffect.Path2D{} = effect) do
    {:path_2d_effect, normalize_optional_matrix!(effect.matrix), effect.path}
  end

  defp normalize_path_effect!(%Skia.PathEffect.Compose{outer: outer, inner: inner}) do
    {:compose_path_effect, normalize_path_effect!(outer), normalize_path_effect!(inner)}
  end

  defp normalize_path_effect!(%Skia.PathEffect.Sum{first: first, second: second}) do
    {:sum_path_effect, normalize_path_effect!(first), normalize_path_effect!(second)}
  end

  defp normalize_path_effect!(value),
    do: raise(ArgumentError, "invalid path effect #{inspect(value)}")

  defp normalize_sampling_options!(%Skia.SamplingOptions{} = sampling) do
    cond do
      is_integer(sampling.max_aniso) ->
        {:sampling_aniso, sampling.max_aniso}

      sampling.cubic != nil ->
        {:sampling_cubic, normalize_cubic!(sampling.cubic)}

      true ->
        {:sampling_options, sampling.filter, sampling.mipmap}
    end
  end

  defp normalize_sampling_options!(sampling) when is_atom(sampling) do
    {:sampling_options, sampling, :none}
  end

  defp normalize_sampling_options!({filter, mipmap}) when is_atom(filter) and is_atom(mipmap) do
    {:sampling_options, filter, mipmap}
  end

  defp normalize_sampling_options!(value),
    do: raise(ArgumentError, "invalid sampling options #{inspect(value)}")

  defp normalize_cubic!(:mitchell), do: :mitchell
  defp normalize_cubic!(:catmull_rom), do: :catmull_rom
  defp normalize_cubic!({b, c}), do: {normalize_number!(b), normalize_number!(c)}

  defp normalize_cubic!(value),
    do: raise(ArgumentError, "invalid cubic sampling #{inspect(value)}")

  defp normalize_spans!(spans) when is_list(spans), do: Enum.map(spans, &normalize_span!/1)

  defp normalize_spans!(value),
    do: raise(ArgumentError, "invalid text spans #{inspect(value)}")

  defp normalize_span!(%Skia.TextSpan{text: text, style: style}) when is_binary(text) do
    {text, normalize_text_style!(style)}
  end

  defp normalize_span!({text, %Skia.TextStyle{} = style}) when is_binary(text) do
    {text, normalize_text_style!(style)}
  end

  defp normalize_span!(text) when is_binary(text), do: {text, []}

  defp normalize_span!(value),
    do: raise(ArgumentError, "invalid text span #{inspect(value)}")

  defp normalize_text_style!(nil), do: []

  defp normalize_text_style!(%Skia.TextStyle{} = style) do
    style
    |> Skia.TextStyle.to_opts()
    |> Enum.map(fn
      {:size, value} -> {:size, normalize_number!(value)}
      {:fill, value} -> {:fill, normalize_color!(value)}
      {:line_height, value} -> {:line_height, normalize_number!(value)}
      other -> other
    end)
  end

  defp normalize_rect!({x, y, width, height}) do
    {normalize_number!(x), normalize_number!(y), normalize_number!(width),
     normalize_number!(height)}
  end

  defp normalize_rect!(value), do: raise(ArgumentError, "invalid rect #{inspect(value)}")

  defp normalize_optional_rect!(nil), do: nil
  defp normalize_optional_rect!(rect), do: normalize_rect!(rect)

  defp normalize_point!({x, y}), do: {normalize_number!(x), normalize_number!(y)}
  defp normalize_point!(value), do: raise(ArgumentError, "invalid point #{inspect(value)}")

  defp normalize_optional_matrix!(nil), do: nil

  defp normalize_optional_matrix!(%Skia.Matrix{} = matrix),
    do: matrix |> Skia.Matrix.to_tuple() |> normalize_optional_matrix!()

  defp normalize_optional_matrix!({m00, m01, m02, m10, m11, m12}) do
    {normalize_number!(m00), normalize_number!(m01), normalize_number!(m02),
     normalize_number!(m10), normalize_number!(m11), normalize_number!(m12)}
  end

  defp normalize_optional_matrix!(value),
    do: raise(ArgumentError, "invalid matrix #{inspect(value)}")

  defp normalize_number!(value) when is_integer(value) or is_float(value), do: value * 1.0
  defp normalize_number!(value), do: raise(ArgumentError, "invalid number #{inspect(value)}")

  defp channel!(value) when is_integer(value) and value >= 0 and value <= 255, do: value
  defp channel!(value), do: raise(ArgumentError, "invalid color channel #{inspect(value)}")

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(command, opts) do
      fields =
        [args: command.args]
        |> Keyword.merge(command.opts)
        |> Enum.map(fn {key, value} -> concat([to_string(key), "=", to_doc(value, opts)]) end)
        |> Enum.intersperse(" ")

      concat(["#Skia.Command<", to_string(command.op), command_fields(fields), ">"])
    end

    defp command_fields([]), do: ""
    defp command_fields(fields), do: concat([" ", concat(fields)])
  end
end
