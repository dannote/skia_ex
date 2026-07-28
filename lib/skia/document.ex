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
          commands: [Command.t()],
          style_stack: [keyword()]
        }

  defstruct [:width, :height, commands: [], style_stack: []]

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

  @doc false
  @spec push_style(t(), keyword()) :: t()
  def push_style(%__MODULE__{} = document, style) when is_list(style) do
    %{document | style_stack: [style | document.style_stack]}
  end

  @doc false
  @spec pop_style(t()) :: t()
  def pop_style(%__MODULE__{style_stack: [_style | rest]} = document) do
    %{document | style_stack: rest}
  end

  @doc false
  @spec current_style(t()) :: keyword()
  def current_style(%__MODULE__{} = document) do
    document.style_stack
    |> Enum.reverse()
    |> Enum.reduce([], fn style, inherited -> Keyword.merge(inherited, style) end)
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
