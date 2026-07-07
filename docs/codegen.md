# Skia codegen intent

Skia uses RustQ as a Rusty Elixir lowering engine: Skia describes drawing semantics in valid Elixir `@spec + defrust` modules, and RustQ lowers those bodies to Rust. The goal is readable Skia-owned semantics, not Rust strings hidden in Elixir.

## Ownership boundary

Skia owns:

- public Elixir command APIs, command argument/option typespecs, and generated option structs (`GeneratedOpts.*`)
- drawing semantics for shapes, transforms, clips, layers, paths, images, and text
- Rustler handler shells that decode command batches and dispatch to semantic impls
- Skia-specific helper macros such as paint/geometry/argument helpers

RustQ owns:

- valid-Elixir `defrust` lowering
- Rust AST types and renderers
- Rustler AST decoding/rendering primitives
- generic Rust syntax support such as refs, matches, options, tuples, calls, assignments, and helper builders
- structural Rust parsing/introspection through syn-backed helpers; never parse Rust source with regex

Do not create fake RustQ module declarations for Skia-owned Rust modules such as `atoms`, `generated_opts`, or `skia_safe`. Use ordinary remote types and calls instead:

```elixir
@spec draw_rect_impl(
        R.ref(SkiaSafe.Canvas.t()),
        GeneratedOpts.RectOpts.t(R.lifetime(:a)),
        R.slice({R.atom(), R.term()})
      ) :: R.nif_result(R.unit())
defrust draw_rect_impl(canvas, opts, raw_opts) do
  rect = Rect.from_xywh(opts.x, opts.y, opts.width, opts.height)
  canvas.draw_rect(rect, ref(paint))
  :ok
end
```

## Generated output and Rust inputs

Generated Rust outputs live only under:

```text
native/skia_native/src/generated_*.rs
```

Do not edit those files by hand. Change the Elixir generator, Rusty-Elixir source,
RustQ primitives, or the Rust support inputs instead, then run `mix rustq.gen`.

Generated files are rendered directly from RustQ/Rusty-Elixir items. There are
currently no hand-written Rust support inputs under `priv/codegen/templates`;
previous support helpers have been migrated to Rusty Elixir.

Keep small generated module shells and semantic helper bodies out of
`priv/codegen/templates`. Prefer `defrust` for semantic helpers and RustQ item
rendering for generated item lists. Use support inputs only for substantial
hand-written Rust interop/decoder code that is not yet clearer as Rusty Elixir.

## Module structure

The codegen tree is organized by pipeline concern:

```text
lib/skia/codegen/command/              # command model and docs metadata
lib/skia/codegen/native/               # skia-safe/native metadata
lib/skia/codegen/rust/                 # generated Rust builders and target registry
lib/skia/codegen/rusty/                # Rusty-Elixir implementation source
```

Command metadata is pure Elixir command shape:

```text
lib/skia/codegen/command/registry.ex
lib/skia/codegen/command/spec_reader.ex
lib/skia/codegen/command/overlay.ex
lib/skia/codegen/command/domain/*.ex
```

Native metadata is about external Skia/skia-safe facts:

```text
lib/skia/codegen/native/schema.ex
lib/skia/codegen/native/skia_safe.ex
lib/skia/codegen/native/enums.ex
```

Generated Rust builders and target metadata live under `Skia.Codegen.Rust`:

```text
lib/skia/codegen/rust/commands.ex
lib/skia/codegen/rust/core.ex
lib/skia/codegen/rust/nifs.ex
lib/skia/codegen/rust/opts.ex
lib/skia/codegen/rust/targets.ex
```

Rusty Elixir semantic implementations are split between command bodies and support helpers:

```text
lib/skia/codegen/rusty/command/*.ex
lib/skia/codegen/rusty/support/*.ex
lib/skia/codegen/rusty/source_sets/*.ex
```

## Command metadata direction

`Skia.Codegen.Command.Registry` is the command aggregate. Command args/options are declared as real Elixir `@type`/`@spec` declarations in `Skia.Codegen.Command.Domain.*` modules and reflected structurally from quoted Elixir AST. Do not reintroduce parallel keyword-list command specs. For example, option requirements belong in map types such as:

```elixir
@type path_op_opts :: %{
        required(:path_op) => path_op(),
        optional(:fill_rule) => fill_rule()
      }

@spec path_op(Skia.Document.t(), Skia.Path.t(), Skia.Path.t(), path_op_opts()) :: Skia.Document.t()
```

Native Rust binding introspection, when needed, must go through RustQ syn parser helpers or another structural Rust API. Do not infer semantics from rendered Rust strings, do not use regex to parse Rust, and do not introduce Skia-side Rust module resolver tables.

## Naming conventions

- Rusty family modules expose `commands/0` and `generated_asts/0`.
- `defrust` function names match the generated Rust function names exactly, for example `draw_rect_impl/3` and `draw_rect_shape/4`.
- Helper macros should read as Skia semantics, for example `with_fill_paint` and `with_stroke_paint`.
- Type specs use ordinary remote types where possible:
  - `SkiaSafe.Canvas.t()`
  - `GeneratedOpts.RectOpts.t(R.lifetime(:a))`
  - `R.slice({R.atom(), R.term()})`
- `R.path/1,2` is a low-level escape hatch, not normal Skia authoring style.

## Rusty Elixir authoring rules

Prefer, in order:

1. valid Elixir bodies with `@spec + defrust`
2. ordinary Elixir macros with `quote`, `unquote`, and `var!` when needed for helper reuse
3. RustQ AST builders for structural Rust that is not natural as a function body
4. isolated raw Rust strings only as explicit escape hatches

Avoid:

- raw Rust body strings for drawing semantics
- Skia tests that assert RustQ AST internals
- fake modules for Rust modules owned by Skia
- Rust-shaped Elixir syntax such as `if_let`
- workaround bindings such as `paint = paint`

Mutable Rust bindings should be expressed semantically. For example, if a case binding is used with `mut_ref/1`, RustQ renders the pattern binding mutable:

```elixir
case unwrap!(opt_fill_paint(raw_opts, Atoms.fill())) do
  {:some, paint} ->
    unwrap!(apply_blend_mode(mut_ref(paint), raw_opts))
    canvas.draw_rect(rect, ref(paint))

  :none ->
    :ok
end
```

renders as Rust with `Some(mut paint)`, without a Skia-side shadow assignment.

## Validation expectations

Skia should build confidence through generated-source smoke checks, freshness checks, Rust compilation, and real rendering behavior tests. RustQ tests RustQ AST internals; Skia should test that generated source is sane and behavior is correct.
