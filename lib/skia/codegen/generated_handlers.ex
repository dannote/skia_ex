defmodule Skia.Codegen.GeneratedHandlers do
  @moduledoc false

  @asts Skia.Codegen.HandlerShells.generated_asts(Skia.CommandSpec.all(),
          except: [:save, :restore]
        )
  @items Enum.map(@asts, &RustQ.Rust.item(RustQ.Rust.AST.Render.render_item(&1)))
  @source Enum.map_join(@asts, "\n\n", &RustQ.Rust.AST.Render.render_item/1)

  @doc false
  def __rustq_asts__, do: @asts

  @doc false
  def __rustq_items__, do: @items

  @doc false
  def __rustq_source__, do: @source
end
