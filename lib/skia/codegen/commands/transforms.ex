defmodule Skia.Codegen.Commands.Transforms do
  @moduledoc false

  @type matrix ::
          {RustQ.Type.f32(), RustQ.Type.f32(), RustQ.Type.f32(), RustQ.Type.f32(),
           RustQ.Type.f32(), RustQ.Type.f32()}

  @type translate_opts :: %{required(:x) => RustQ.Type.f32(), required(:y) => RustQ.Type.f32()}
  @type scale_opts :: %{required(:x) => RustQ.Type.f32(), required(:y) => RustQ.Type.f32()}
  @type rotate_opts :: %{required(:degrees) => RustQ.Type.f32()}
  @type rotate_at_opts :: %{
          required(:degrees) => RustQ.Type.f32(),
          required(:x) => RustQ.Type.f32(),
          required(:y) => RustQ.Type.f32()
        }
  @type concat_opts :: %{required(:matrix) => matrix()}

  @spec commands() :: keyword()
  def commands do
    __ENV__.file
    |> Skia.Codegen.CommandSpecs.from_file()
    |> Enum.map(fn command ->
      {command.name,
       [
         handler: handler(command.name),
         args: command.args,
         opts: command.opts
       ]}
    end)
  end

  defp handler(name), do: String.to_atom("draw_#{name}")

  @spec translate(Skia.Document.t(), translate_opts()) :: Skia.Document.t()
  def translate(document, opts), do: {document, opts}

  @spec scale(Skia.Document.t(), scale_opts()) :: Skia.Document.t()
  def scale(document, opts), do: {document, opts}

  @spec rotate(Skia.Document.t(), rotate_opts()) :: Skia.Document.t()
  def rotate(document, opts), do: {document, opts}

  @spec rotate_at(Skia.Document.t(), rotate_at_opts()) :: Skia.Document.t()
  def rotate_at(document, opts), do: {document, opts}

  @spec concat(Skia.Document.t(), concat_opts()) :: Skia.Document.t()
  def concat(document, opts), do: {document, opts}
end
