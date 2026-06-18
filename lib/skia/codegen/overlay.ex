defmodule Skia.Codegen.Overlay do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      import Skia.Codegen.Overlay, only: [command: 2]
      Module.register_attribute(__MODULE__, :commands, accumulate: true)
      @before_compile Skia.Codegen.Overlay
    end
  end

  defmacro command(name, opts) do
    quote bind_quoted: [name: name, opts: opts] do
      @commands {name, opts}
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @spec overlays() :: keyword()
      def overlays do
        @commands
        |> Enum.reverse()
      end
    end
  end
end
