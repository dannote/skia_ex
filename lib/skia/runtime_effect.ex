defmodule Skia.RuntimeEffect do
  import Inspect.Algebra

  @moduledoc "Compiled SkSL runtime effect."

  @type t :: %__MODULE__{ref: reference(), source: String.t()}
  defstruct [:ref, :source]

  @spec compile(String.t()) :: {:ok, t()} | {:error, String.t()}
  def compile(source) when is_binary(source) do
    case Skia.Native.compile_runtime_effect(source) do
      {:ok, ref} -> {:ok, %__MODULE__{ref: ref, source: source}}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec shader(t(), keyword()) :: Skia.Shader.RuntimeEffect.t()
  def shader(%__MODULE__{} = effect, opts \\ []) do
    %Skia.Shader.RuntimeEffect{
      effect: effect,
      uniforms: Keyword.get(opts, :uniforms, %{}),
      matrix: Keyword.get(opts, :matrix)
    }
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(_effect, _opts), do: concat(["#Skia.RuntimeEffect<>"])
  end
end
