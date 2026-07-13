defmodule Skia.Codegen.Rust.Opts do
  @moduledoc false

  alias RustQ.Rustler.Opts
  alias Skia.Codegen.Command.Registry, as: Commands
  alias Skia.Codegen.Rust.Core

  @spec generated_opts() :: String.t()
  def generated_opts do
    commands =
      Commands.all()
      |> Enum.reject(fn {_name, spec} -> Keyword.get(spec, :opts, []) == [] end)
      |> Enum.flat_map(fn {name, spec} ->
        struct_name = name |> Atom.to_string() |> Macro.camelize() |> Kernel.<>("Opts")
        opts = Keyword.get(spec, :opts, [])

        Opts.decoder(struct_name,
          lifetime: :a,
          fn: "decode_#{name}_opts",
          fields: Enum.map(opts, &opts_decoder_field/1)
        )
      end)

    opts_module_template()
    |> RustQ.render!(
      "generated_opts.rs",
      preamble: Core.generated_rust_preamble(),
      splice: [commands: commands]
    )
  end

  defp opts_module_template do
    """
    #![allow(dead_code)]

    use rustler::{Atom, NifResult, Term};

    use super::{atoms, opt_atom_option, opt_bool_option, opt_f32, opt_f32_option, opt_term};

    __rq_commands!();
    """
  end

  defp opts_decoder_field(opt) do
    {Keyword.fetch!(opt, :name),
     [type: Keyword.fetch!(opt, :type), required: Keyword.get(opt, :required, false)]}
  end
end
