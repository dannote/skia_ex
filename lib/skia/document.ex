defmodule Skia.Document do
  import Inspect.Algebra

  @moduledoc """
  Immutable drawing document built by the fluent API and DSL.

  A document is pure Elixir data until it is handed to a renderer. The native
  renderer can consume the command list in one batch instead of crossing the NIF
  boundary for every drawing operation.
  """

  alias Skia.Command

  @type t :: %__MODULE__{
          width: pos_integer(),
          height: pos_integer(),
          commands: [Command.t()]
        }

  defstruct [:width, :height, commands: []]

  @spec new(pos_integer(), pos_integer()) :: t()
  def new(width, height)
      when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    %__MODULE__{width: width, height: height}
  end

  @spec append(t(), Command.t()) :: t()
  def append(%__MODULE__{} = document, %Command{} = command) do
    %{document | commands: [command | document.commands]}
  end

  @spec commands(t()) :: [Command.t()]
  def commands(%__MODULE__{} = document) do
    Enum.reverse(document.commands)
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(document, opts) do
      concat([
        "#Skia.Document<",
        to_doc(document.width, opts),
        "x",
        to_doc(document.height, opts),
        " commands=",
        to_doc(length(document.commands), opts),
        ">"
      ])
    end
  end
end
