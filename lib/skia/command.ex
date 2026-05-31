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
  defp normalize_value!(_name, _key, :boolean, value) when is_boolean(value), do: value
  defp normalize_value!(_name, _key, :term, value), do: value
  defp normalize_value!(_name, _key, :color, value), do: normalize_color!(value)
  defp normalize_value!(_name, _key, :path, %Skia.Path{} = value), do: value
  defp normalize_value!(_name, _key, :image, %Skia.Image{} = value), do: value
  defp normalize_value!(_name, _key, :font, %Skia.Font{} = value), do: value

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

  defp normalize_color!(%Skia.Shader.LinearGradient{from: from, to: to, colors: colors}) do
    normalize_color!({:linear_gradient, from, to, colors})
  end

  defp normalize_color!(%Skia.Shader.RadialGradient{
         center: center,
         radius: radius,
         colors: colors
       }) do
    normalize_color!({:radial_gradient, center, radius, colors})
  end

  defp normalize_color!({:linear_gradient, from, to, colors}) when is_list(colors) do
    {:linear_gradient, normalize_point!(from), normalize_point!(to),
     Enum.map(colors, &normalize_color!/1)}
  end

  defp normalize_color!({:radial_gradient, center, radius, colors}) when is_list(colors) do
    {:radial_gradient, normalize_point!(center), normalize_number!(radius),
     Enum.map(colors, &normalize_color!/1)}
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

  defp normalize_point!({x, y}), do: {normalize_number!(x), normalize_number!(y)}
  defp normalize_point!(value), do: raise(ArgumentError, "invalid point #{inspect(value)}")

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
