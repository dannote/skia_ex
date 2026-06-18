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

## Module structure

The codegen root is orchestration only:

```text
lib/skia/codegen.ex
lib/skia/codegen/handler_shells.ex
```

Rusty Elixir semantic implementations live under `Skia.Codegen.Rusty`:

```text
lib/skia/codegen/rusty/paint.ex
lib/skia/codegen/rusty/args.ex
lib/skia/codegen/rusty/geometry.ex
lib/skia/codegen/rusty/transforms.ex
lib/skia/codegen/rusty/shapes.ex
lib/skia/codegen/rusty/layers.ex
lib/skia/codegen/rusty/clips.ex
lib/skia/codegen/rusty/paths.ex
lib/skia/codegen/rusty/images.ex
lib/skia/codegen/rusty/text.ex
```

Family modules are plural (`Shapes`, `Transforms`, `Clips`). Helper macro modules are singular concepts (`Paint`, `Args`, `Geometry`).

## Command metadata direction

`Skia.Codegen.Commands` is the command aggregate. Command args/options are declared as real Elixir `@type`/`@spec` declarations in `Skia.Codegen.Commands.*` modules and reflected structurally from quoted Elixir AST. Do not reintroduce parallel keyword-list command specs. For example, option requirements belong in map types such as:

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
