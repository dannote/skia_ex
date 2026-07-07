defmodule Skia.Codegen.Command.Domain.Transforms do
  @moduledoc false

  alias Skia.Codegen.Command.SpecReader, as: CommandSpecs

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
  def commands, do: CommandSpecs.command_metadata_from_file(__ENV__.file, "draw")

  @spec translate(Skia.Document.t(), translate_opts()) :: Skia.Document.t()
  def translate(document, opts), do: keep_command_shape(document, opts)

  @spec scale(Skia.Document.t(), scale_opts()) :: Skia.Document.t()
  def scale(document, opts), do: keep_command_shape(document, opts)

  @spec rotate(Skia.Document.t(), rotate_opts()) :: Skia.Document.t()
  def rotate(document, opts), do: keep_command_shape(document, opts)

  @spec rotate_at(Skia.Document.t(), rotate_at_opts()) :: Skia.Document.t()
  def rotate_at(document, opts), do: keep_command_shape(document, opts)

  @spec concat(Skia.Document.t(), concat_opts()) :: Skia.Document.t()
  def concat(document, opts), do: keep_command_shape(document, opts)

  defp keep_command_shape(document, _opts), do: document
end
