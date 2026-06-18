defmodule Skia.Codegen.NativeRef do
  @moduledoc false

  defstruct [:target, :method]

  @type t :: %__MODULE__{target: String.t(), method: String.t()}

  @spec new(String.t(), String.t()) :: t()
  def new(target, method) when is_binary(target) and is_binary(method) do
    %__MODULE__{target: target, method: method}
  end

  @spec descriptor!(t()) :: Skia.Codegen.NativeSchema.Method.t()
  def descriptor!(%__MODULE__{target: target, method: method}) do
    Skia.Codegen.NativeSchema.descriptor!(target, method)
  end

  @spec format(t()) :: String.t()
  def format(%__MODULE__{target: target, method: method}), do: "skia_safe::#{target}::#{method}"
end
