defmodule Skia.Codegen.Commands.Transforms do
  @moduledoc false

  @type matrix :: {number(), number(), number(), number(), number(), number()}

  @native_refs %{
    translate: ["skia_safe::Canvas::translate"],
    scale: ["skia_safe::Canvas::scale"],
    rotate: ["skia_safe::Canvas::rotate"],
    rotate_at: ["skia_safe::Canvas::rotate"],
    concat: ["skia_safe::Canvas::concat"]
  }

  @type translate_opts :: %{required(:x) => number(), required(:y) => number()}
  @type scale_opts :: %{required(:x) => number(), required(:y) => number()}
  @type rotate_opts :: %{required(:degrees) => number()}
  @type rotate_at_opts :: %{
          required(:degrees) => number(),
          required(:x) => number(),
          required(:y) => number()
        }
  @type concat_opts :: %{required(:matrix) => matrix()}

  @spec commands() :: keyword()
  def commands do
    __ENV__.file
    |> Skia.Codegen.CommandSchema.from_file()
    |> Enum.map(fn command ->
      {command.name,
       [
         handler: handler(command.name),
         args: command.args,
         opts: command.opts,
         native_refs: Map.fetch!(@native_refs, command.name)
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
