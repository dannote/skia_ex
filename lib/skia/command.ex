defmodule Skia.Command do
  import Inspect.Algebra

  @moduledoc """
  Normalized drawing command.

  Commands are intentionally small, explicit data structures. They are easy to
  inspect in tests and can later be encoded into a compact binary protocol for a
  Rustler NIF.
  """

  alias Skia.CommandSpec

  @type color ::
          {:rgba, non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()}
  @type t :: %__MODULE__{op: atom(), args: [term()], opts: keyword()}

  defstruct [:op, args: [], opts: []]

  @spec build!(atom(), [term()], keyword()) :: t()
  def build!(name, args, opts) when is_atom(name) and is_list(args) and is_list(opts) do
    spec = CommandSpec.fetch!(name)
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

  defp normalize_value!(_name, _key, :number, value) when is_integer(value) or is_float(value),
    do: value * 1.0

  defp normalize_value!(_name, _key, :integer, value) when is_integer(value), do: value
  defp normalize_value!(_name, _key, :string, value) when is_binary(value), do: value
  defp normalize_value!(_name, _key, :atom, value) when is_atom(value), do: value

  defp normalize_value!(_command, _key, {:enum, _enum_name, _opts}, value) when is_atom(value),
    do: value

  defp normalize_value!(_name, _key, :boolean, value) when is_boolean(value), do: value
  defp normalize_value!(_name, _key, :term, value), do: value
  defp normalize_value!(_name, _key, :color, value), do: normalize_color!(value)
  defp normalize_value!(_name, _key, :path, %Skia.Path{} = value), do: value
  defp normalize_value!(_name, _key, :image, %Skia.Image{} = value), do: value
  defp normalize_value!(_name, _key, :font, %Skia.Font{} = value), do: value
  defp normalize_value!(_name, _key, :image_filter, value), do: normalize_image_filter!(value)
  defp normalize_value!(_name, _key, :path_effect, value), do: normalize_path_effect!(value)

  defp normalize_value!(_name, _key, :sampling_options, value),
    do: normalize_sampling_options!(value)

  defp normalize_value!(_name, _key, {:tuple, types}, value) when is_tuple(value),
    do: normalize_tuple!(types, value)

  defp normalize_value!(name, key, type, value) do
    raise ArgumentError,
          "invalid #{inspect(key)} for #{name}: expected #{inspect(type)}, got #{inspect(value)}"
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

  defp normalize_color!(%Skia.Shader.ImageShader{} = shader) do
    {:image_shader, shader.image, shader.tile_x, shader.tile_y,
     normalize_sampling_options!(shader.sampling), normalize_optional_matrix!(shader.matrix)}
  end

  defp normalize_color!(%Skia.Shader.GradientStop{color: color, position: position}) do
    normalize_color!({:gradient_stop, color, position})
  end

  defp normalize_color!({:image_shader, %Skia.Image{} = image, tile_x, tile_y, sampling, matrix})
       when is_atom(tile_x) and is_atom(tile_y) do
    {:image_shader, image, tile_x, tile_y, normalize_sampling_options!(sampling),
     normalize_optional_matrix!(matrix)}
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

  defp normalize_path_effect!(%Skia.PathEffect.Dash{intervals: intervals, phase: phase}) do
    {:dash_path_effect, Enum.map(intervals, &normalize_number!/1), normalize_number!(phase)}
  end

  defp normalize_path_effect!(%Skia.PathEffect.Corner{radius: radius}) do
    {:corner_path_effect, normalize_number!(radius)}
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
