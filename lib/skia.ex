defmodule Skia do
  @moduledoc """
  Batched, Elixir-native drawing API designed for a future Skia renderer.

  The fluent API and `Skia.DSL` both build immutable `%Skia.Document{}`
  values. Rendering can later be implemented as a single Rustler NIF call that
  consumes the normalized command list.
  """

  alias Skia.{Command, CommandSpec, Document}

  @type document :: Document.t()

  @doc "Creates an empty drawing document."
  @spec canvas(pos_integer(), pos_integer()) :: Document.t()
  def canvas(width, height), do: Document.new(width, height)

  @doc "Creates a linear gradient paint value."
  @spec linear_gradient({number(), number()}, {number(), number()}, [term()], keyword()) ::
          Skia.Shader.LinearGradient.t()
  def linear_gradient(from, to, colors, opts \\ []),
    do: %Skia.Shader.LinearGradient{
      from: from,
      to: to,
      colors: colors,
      tile_mode: Keyword.get(opts, :tile, Keyword.get(opts, :tile_mode, :clamp)),
      matrix: Keyword.get(opts, :matrix)
    }

  @doc "Creates a two-point conical gradient paint value."
  @spec two_point_conical_gradient(
          {number(), number()},
          number(),
          {number(), number()},
          number(),
          [term()],
          keyword()
        ) :: Skia.Shader.TwoPointConicalGradient.t()
  def two_point_conical_gradient(start, start_radius, finish, end_radius, colors, opts \\ []) do
    %Skia.Shader.TwoPointConicalGradient{
      start: start,
      start_radius: start_radius,
      end: finish,
      end_radius: end_radius,
      colors: colors,
      tile_mode: Keyword.get(opts, :tile, Keyword.get(opts, :tile_mode, :clamp)),
      matrix: Keyword.get(opts, :matrix)
    }
  end

  @doc "Creates a solid-color shader paint value."
  @spec color_shader(term()) :: Skia.Shader.ColorShader.t()
  def color_shader(color), do: %Skia.Shader.ColorShader{color: color}

  @doc "Creates a radial gradient paint value."
  @spec radial_gradient({number(), number()}, number(), [term()], keyword()) ::
          Skia.Shader.RadialGradient.t()
  def radial_gradient(center, radius, colors, opts \\ []),
    do: %Skia.Shader.RadialGradient{
      center: center,
      radius: radius,
      colors: colors,
      tile_mode: Keyword.get(opts, :tile, Keyword.get(opts, :tile_mode, :clamp)),
      matrix: Keyword.get(opts, :matrix)
    }

  @doc "Creates a sweep/conic gradient paint value."
  @spec sweep_gradient({number(), number()}, number(), number(), [term()], keyword()) ::
          Skia.Shader.SweepGradient.t()
  def sweep_gradient(center, start_degrees, end_degrees, colors, opts \\ []) do
    %Skia.Shader.SweepGradient{
      center: center,
      start_degrees: start_degrees,
      end_degrees: end_degrees,
      colors: colors,
      tile_mode: Keyword.get(opts, :tile, Keyword.get(opts, :tile_mode, :clamp)),
      matrix: Keyword.get(opts, :matrix)
    }
  end

  @doc "Creates a positioned gradient stop."
  @spec gradient_stop(term(), number()) :: Skia.Shader.GradientStop.t()
  def gradient_stop(color, position),
    do: %Skia.Shader.GradientStop{color: color, position: position}

  @doc "Creates an image shader paint value."
  @spec image_shader(Skia.Image.t(), keyword()) :: Skia.Shader.ImageShader.t()
  def image_shader(%Skia.Image{} = image, opts \\ []) do
    %Skia.Shader.ImageShader{
      image: image,
      tile_x: image_shader_tile(opts) |> elem(0),
      tile_y: image_shader_tile(opts) |> elem(1),
      sampling: Keyword.get(opts, :sampling, :linear),
      matrix: Keyword.get(opts, :matrix)
    }
  end

  defp image_shader_tile(opts) do
    case Keyword.get(opts, :tile) do
      nil -> {Keyword.get(opts, :tile_x, :clamp), Keyword.get(opts, :tile_y, :clamp)}
      {tile_x, tile_y} -> {tile_x, tile_y}
      tile when is_atom(tile) -> {tile, tile}
    end
  end

  @doc "Measures text using the native text engine."
  @spec measure_text(String.t(), keyword()) ::
          {:ok, %{width: float(), bounds: {float(), float(), float(), float()}}}
          | {:error, atom()}
  def measure_text(text, opts \\ []) when is_binary(text) do
    font = Keyword.get(opts, :font)
    size = Keyword.get(opts, :size, 16)

    case Skia.Native.measure_text(text, font, size) do
      {:ok, width, left, top, right, bottom} ->
        {:ok, %{width: width, bounds: {left, top, right, bottom}}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  for {name, spec} <- CommandSpec.all(),
      name not in [
        :save,
        :save_layer,
        :restore,
        :translate,
        :rotate,
        :push_style,
        :pop_style,
        :text
      ] do
    args = Keyword.get(spec, :args, [])
    arg_vars = Enum.map(args, fn {arg_name, _type} -> Macro.var(arg_name, __MODULE__) end)

    if args == [] do
      @doc "Adds a `#{name}` command to the document."
      @spec unquote(name)(Document.t(), keyword()) :: Document.t()
      def unquote(name)(%Document{} = document, opts \\ []) do
        append_command(document, unquote(name), [], opts)
      end
    else
      @doc "Adds a `#{name}` command to the document."
      @spec unquote(name)(
              Document.t(),
              unquote_splicing(Enum.map(args, fn _ -> quote(do: term()) end)),
              keyword()
            ) :: Document.t()
      def unquote(name)(%Document{} = document, unquote_splicing(arg_vars), opts \\ []) do
        append_command(document, unquote(name), unquote(arg_vars), opts)
      end
    end
  end

  @doc "Adds text with optional `%Skia.TextStyle{}` and `%Skia.ParagraphStyle{}` values."
  @spec text(Document.t(), String.t(), keyword()) :: Document.t()
  def text(%Document{} = document, text, opts \\ []) when is_binary(text) do
    {text_style, opts} = Keyword.pop(opts, :style)
    {paragraph_style, opts} = Keyword.pop(opts, :paragraph_style)

    opts =
      []
      |> Keyword.merge(style_opts(text_style, Skia.TextStyle))
      |> Keyword.merge(style_opts(paragraph_style, Skia.ParagraphStyle))
      |> Keyword.merge(opts)

    append_command(document, :text, [text], opts)
  end

  defp style_opts(nil, _module), do: []
  defp style_opts(%Skia.TextStyle{} = style, Skia.TextStyle), do: Skia.TextStyle.to_opts(style)

  defp style_opts(%Skia.ParagraphStyle{} = style, Skia.ParagraphStyle),
    do: Skia.ParagraphStyle.to_opts(style)

  @doc "Adds a saved canvas group with optional transforms."
  @spec group(Document.t(), keyword(), (Document.t() -> Document.t())) :: Document.t()
  def group(%Document{} = document, opts, fun) when is_list(opts) and is_function(fun, 1) do
    document
    |> append_command(:save, [], [])
    |> apply_group_opts(opts)
    |> fun.()
    |> append_command(:restore, [], [])
  end

  @doc "Adds a saved layer with optional opacity."
  @spec layer(Document.t(), keyword(), (Document.t() -> Document.t())) :: Document.t()
  def layer(%Document{} = document, opts, fun) when is_list(opts) and is_function(fun, 1) do
    document
    |> append_command(:save_layer, [], opts)
    |> fun.()
    |> append_command(:restore, [], [])
  end

  @doc "Adds a style scope for following commands in the group."
  @spec style(Document.t(), keyword(), (Document.t() -> Document.t())) :: Document.t()
  def style(%Document{} = document, opts, fun) when is_list(opts) and is_function(fun, 1) do
    document
    |> append_command(:push_style, [], style: opts)
    |> fun.()
    |> append_command(:pop_style, [], [])
  end

  @doc "Returns normalized commands in render order."
  @spec commands(Document.t()) :: [Command.t()]
  def commands(%Document{} = document), do: Document.commands(document)

  @doc "Encodes the document to the term batch a native renderer would consume."
  @spec to_batch(Document.t()) :: %{
          width: pos_integer(),
          height: pos_integer(),
          commands: [Command.t()]
        }
  def to_batch(%Document{} = document) do
    %{width: document.width, height: document.height, commands: commands(document)}
  end

  @doc "Renders the document according to `Skia.RenderOptions`."
  @spec render(Document.t(), keyword() | Skia.RenderOptions.t()) ::
          {:ok, binary() | map()} | {:error, atom(), map()}
  def render(%Document{} = document, opts \\ []) do
    options = if is_list(opts), do: Skia.RenderOptions.new(opts), else: opts

    case options.format do
      :png -> to_png(document)
      :jpeg -> to_jpeg(document, quality: options.quality || 90)
      :webp -> to_webp(document, quality: options.quality || 90)
      :raw -> to_raw(document)
      format -> {:error, :unsupported_format, %{format: format}}
    end
  end

  @doc "Renders the document to PNG through the native renderer."
  @spec to_png(Document.t()) :: {:ok, binary()} | {:error, atom(), map()}
  def to_png(%Document{} = document) do
    with :ok <- validate(document), do: render_native(document, &Skia.Native.render_png/1)
  end

  @doc "Renders the document to JPEG through the native renderer."
  @spec to_jpeg(Document.t(), keyword()) :: {:ok, binary()} | {:error, atom(), map()}
  def to_jpeg(%Document{} = document, opts \\ []) do
    quality = Keyword.get(opts, :quality, 90)

    with :ok <- validate(document),
         do: render_native(document, &Skia.Native.render_jpeg(&1, quality))
  end

  @doc "Renders the document to WEBP through the native renderer."
  @spec to_webp(Document.t(), keyword()) :: {:ok, binary()} | {:error, atom(), map()}
  def to_webp(%Document{} = document, opts \\ []) do
    quality = Keyword.get(opts, :quality, 90)

    with :ok <- validate(document),
         do: render_native(document, &Skia.Native.render_webp(&1, quality))
  end

  @doc "Encodes the normalized command batch as an Erlang external term binary."
  @spec to_binary_batch(Document.t()) :: binary()
  def to_binary_batch(%Document{} = document),
    do: document |> to_batch() |> :erlang.term_to_binary()

  @doc "Renders the document to a raw RGBA buffer."
  @spec to_raw(Document.t()) ::
          {:ok,
           %{width: pos_integer(), height: pos_integer(), stride: pos_integer(), data: binary()}}
          | {:error, atom(), map()}
  def to_raw(%Document{} = document) do
    with :ok <- validate(document) do
      batch = to_batch(document)

      case Skia.Native.render_rgba(batch) do
        {:ok, {width, height, stride, data}} ->
          {:ok, %{width: width, height: height, stride: stride, data: data}}

        {:error, reason} ->
          {:error, reason, batch}
      end
    end
  end

  @doc "Validates the document before handing it to native code."
  @spec validate(Document.t()) :: :ok | {:error, atom(), map()}
  def validate(%Document{width: width, height: height}) when width <= 0 or height <= 0 do
    {:error, :invalid_document, %{width: width, height: height}}
  end

  def validate(%Document{} = document) do
    document
    |> commands()
    |> Enum.reduce_while(:ok, &reduce_validation/2)
  end

  defp reduce_validation(command, :ok) do
    case validate_command(command) do
      :ok -> {:cont, :ok}
      {:error, reason, meta} -> {:halt, {:error, reason, meta}}
    end
  end

  defp validate_command(%Command{op: op, opts: opts}) do
    cond do
      Keyword.has_key?(opts, :path_effect) and not Keyword.has_key?(opts, :stroke) ->
        {:error, :path_effect_requires_stroke, %{op: op}}

      Keyword.has_key?(opts, :stroke_width) and Keyword.get(opts, :stroke_width) < 0 ->
        {:error, :invalid_stroke_width, %{op: op, stroke_width: Keyword.get(opts, :stroke_width)}}

      true ->
        :ok
    end
  end

  defp render_native(%Document{} = document, render_fun) when is_function(render_fun, 1) do
    batch = to_batch(document)

    case render_fun.(batch) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason, batch}
    end
  end

  defp append_command(%Document{} = document, name, args, opts) do
    Document.append(document, Command.build!(name, args, opts))
  end

  defp apply_group_opts(%Document{} = document, opts) do
    Enum.reduce(opts, document, fn
      {:translate, {x, y}}, acc ->
        append_command(acc, :translate, [], x: x, y: y)

      {:scale, {x, y}}, acc ->
        append_command(acc, :scale, [], x: x, y: y)

      {:rotate, degrees}, acc ->
        append_command(acc, :rotate, [], degrees: degrees)

      {:rotate_at, {degrees, x, y}}, acc ->
        append_command(acc, :rotate_at, [], degrees: degrees, x: x, y: y)

      {:concat, matrix}, acc ->
        append_command(acc, :concat, [], matrix: matrix)

      {key, _value}, _acc ->
        raise ArgumentError, "unsupported group option #{inspect(key)}"
    end)
  end
end
