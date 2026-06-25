defmodule Skia.Codegen.Rusty.PaintSupport do
  @moduledoc false

  use Skia.Codegen.Rusty.SkiaSafeSources,
    files: [:gradient_shader, :image, :image_filters, :picture, :runtime_effect],
    rust_sources: ["native/skia_native/src/lib.rs", "native/skia_native/src/generated_enums.rs"]

  alias RustQ.Type, as: R

  defrustmod(SkiaSafe.Path1DStyle, as: [:skia_safe, :path_1d_path_effect, :Style])
  defrustmod(SkiaSafe.TrimPathMode, as: [:skia_safe, :trim_path_effect, :Mode])
  defrustmod(SkiaSafe.SamplingOptions, as: :SamplingOptions)
  defrustmod(SkiaSafe.CubicResampler, as: :CubicResampler)
  defrustmod(SkiaSafe.PathEffect, as: :PathEffect)
  defrustmod(SkiaSafe.MaskFilter, as: :MaskFilter)
  defrustmod(SkiaSafe.ColorFilterClamp, as: [:color_filters, :Clamp])
  defrustmod(SkiaSafe.Shaders, as: [:skia_safe, :shaders])

  @spec decode_path_1d_style(R.atom()) ::
          R.nif_result(R.path({:skia_safe, :path_1d_path_effect, :Style}))
  defrust decode_path_1d_style(style) do
    case style do
      :translate -> {:ok, SkiaSafe.Path1DStyle.Translate}
      :rotate -> {:ok, SkiaSafe.Path1DStyle.Rotate}
      :morph -> {:ok, SkiaSafe.Path1DStyle.Morph}
      _ -> {:error, badarg()}
    end
  end

  @spec optional_matrix_from_term(R.term()) :: R.nif_result(R.option(R.path(:Matrix)))
  defrust optional_matrix_from_term(matrix_term) do
    case decode_as(matrix_term, R.atom()) do
      {:ok, atom} ->
        if atom == Atoms.nil() do
          {:ok, none()}
        else
          {:ok, some(matrix_from_term(matrix_term))}
        end

      {:error, _reason} ->
        {:ok, some(matrix_from_term(matrix_term))}
    end
  end

  @spec optional_rect_from_term(R.term()) :: R.nif_result(R.option(Rect.t()))
  defrust optional_rect_from_term(rect_term) do
    case decode_as(rect_term, R.atom()) do
      {:ok, atom} ->
        if atom == Atoms.nil() do
          {:ok, none()}
        else
          {:ok, some(rect_from_term(rect_term))}
        end

      {:error, _reason} ->
        {:ok, some(rect_from_term(rect_term))}
    end
  end

  @spec runtime_uniform_data(
          R.ref(R.path(:RuntimeEffect)),
          R.vec({R.path(:String), R.vec(R.f64())}),
          R.vec({R.path(:String), R.vec(R.i64())})
        ) :: R.nif_result(R.path(:Data))
  defrust runtime_uniform_data(effect, float_uniforms, int_uniforms) do
    bytes = Vec.new()
    bytes.resize(effect.uniform_size(), 0)

    for {name, values} <- float_uniforms do
      uniform = unwrap!(effect.find_uniform(ref(name)).ok_or(badarg()))
      offset = uniform.offset()
      byte_len = values.len() * 4

      if offset + byte_len > bytes.len() or byte_len > uniform.size_in_bytes() do
        return!({:error, badarg()})
      end

      for {index, value} <- values.into_iter().enumerate() do
        start = offset + index * 4
        encoded = cast(value, :f32).to_ne_bytes()
        assign!(index(bytes, start), index(encoded, 0))
        assign!(index(bytes, start + 1), index(encoded, 1))
        assign!(index(bytes, start + 2), index(encoded, 2))
        assign!(index(bytes, start + 3), index(encoded, 3))
      end
    end

    for {name, values} <- int_uniforms do
      uniform = unwrap!(effect.find_uniform(ref(name)).ok_or(badarg()))
      offset = uniform.offset()
      byte_len = values.len() * 4

      if offset + byte_len > bytes.len() or byte_len > uniform.size_in_bytes() do
        return!({:error, badarg()})
      end

      for {index, value} <- values.into_iter().enumerate() do
        start = offset + index * 4
        encoded = cast(value, :i32).to_ne_bytes()
        assign!(index(bytes, start), index(encoded, 0))
        assign!(index(bytes, start + 1), index(encoded, 1))
        assign!(index(bytes, start + 2), index(encoded, 2))
        assign!(index(bytes, start + 3), index(encoded, 3))
      end
    end

    {:ok, Data.new_copy(ref(bytes))}
  end

  @spec runtime_children(R.ref(R.path(:RuntimeEffect)), R.vec({R.path(:String), R.term()})) ::
          R.nif_result(R.vec(R.path(:ChildPtr)))
  defrust runtime_children(effect, children) do
    effect_children = effect.children()
    ordered = Vec.with_capacity(effect_children.len())

    for _child <- effect_children do
      ordered.push(none())
    end

    for {name, child_term} <- children do
      child = unwrap!(effect.find_child(ref(name)).ok_or(badarg()))
      paint = unwrap!(decode_paint(child_term))
      shader = unwrap!(paint.shader().ok_or(badarg()))
      assign!(index(ordered, child.index()), some(ChildPtr.from(shader)))
    end

    decoded = Vec.with_capacity(ordered.len())

    for child <- ordered do
      case child do
        {:some, child} -> decoded.push(child)
        :none -> return!({:error, badarg()})
      end
    end

    {:ok, decoded}
  end

  @spec decode_paint(R.term()) :: R.nif_result(Paint.t())
  defrust decode_paint(term) do
    case decode_color(term) do
      {:ok, color} -> return!({:ok, fill_paint(color)})
      {:error, _reason} -> :ok
    end

    case decode_as(
           term,
           {R.atom(), {R.f64(), R.f64()}, {R.f64(), R.f64()}, R.vec(R.term()), R.atom(), R.term()}
         ) do
      {:ok, {tag, {from_x, from_y}, {to_x, to_y}, stops, tile_mode, matrix_term}} ->
        if tag == Atoms.linear_gradient() do
          {colors, positions} = decode_gradient_stops(stops)
          tile_mode = GeneratedEnums.decode_tile_mode(tile_mode)
          matrix = optional_matrix_from_term(matrix_term)
          paint = Paint.default()
          paint.set_anti_alias(true).set_style(PaintStyle.Fill)

          case Shader.linear_gradient(
                 {{cast(from_x, :f32), cast(from_y, :f32)}, {cast(to_x, :f32), cast(to_y, :f32)}},
                 colors.as_slice(),
                 positions.as_deref(),
                 tile_mode,
                 none(),
                 matrix.as_ref()
               ) do
            {:some, shader} -> paint.set_shader(shader)
            :none -> :ok
          end

          return!({:ok, paint})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(
           term,
           {R.atom(), {R.f64(), R.f64()}, R.f64(), {R.f64(), R.f64()}, R.f64(), R.term()}
         ) do
      {:ok, {tag, {start_x, start_y}, start_radius, {end_x, end_y}, end_radius, gradient_opts}} ->
        if tag == Atoms.two_point_conical_gradient() do
          {stops, tile_mode, matrix_term} =
            decode_as!(gradient_opts, {R.vec(R.term()), R.atom(), R.term()})

          {colors, positions} = decode_gradient_stops(stops)
          tile_mode = GeneratedEnums.decode_tile_mode(tile_mode)
          matrix = optional_matrix_from_term(matrix_term)
          paint = Paint.default()
          paint.set_anti_alias(true).set_style(PaintStyle.Fill)

          case Shader.two_point_conical_gradient(
                 {cast(start_x, :f32), cast(start_y, :f32)},
                 cast(start_radius, :f32),
                 {cast(end_x, :f32), cast(end_y, :f32)},
                 cast(end_radius, :f32),
                 colors.as_slice(),
                 positions.as_deref(),
                 tile_mode,
                 none(),
                 matrix.as_ref()
               ) do
            {:some, shader} -> paint.set_shader(shader)
            :none -> :ok
          end

          return!({:ok, paint})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term()}) do
      {:ok, {tag, color_term}} ->
        if tag == Atoms.color_shader() do
          paint = Paint.default()
          paint.set_anti_alias(true).set_style(PaintStyle.Fill)
          paint.set_shader(SkiaSafe.Shaders.color(unwrap!(decode_color(color_term))))
          return!({:ok, paint})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(
           term,
           {R.atom(), {R.f64(), R.f64()}, R.f64(), R.vec(R.term()), R.atom(), R.term()}
         ) do
      {:ok, {tag, {center_x, center_y}, radius, stops, tile_mode, matrix_term}} ->
        if tag == Atoms.radial_gradient() do
          {colors, positions} = decode_gradient_stops(stops)
          tile_mode = GeneratedEnums.decode_tile_mode(tile_mode)
          matrix = optional_matrix_from_term(matrix_term)
          paint = Paint.default()
          paint.set_anti_alias(true).set_style(PaintStyle.Fill)

          case Shader.radial_gradient(
                 {cast(center_x, :f32), cast(center_y, :f32)},
                 cast(radius, :f32),
                 colors.as_slice(),
                 positions.as_deref(),
                 tile_mode,
                 none(),
                 matrix.as_ref()
               ) do
            {:some, shader} -> paint.set_shader(shader)
            :none -> :ok
          end

          return!({:ok, paint})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(
           term,
           {R.atom(), {R.f64(), R.f64()}, R.f64(), R.f64(), R.vec(R.term()), R.atom(), R.term()}
         ) do
      {:ok,
       {tag, {center_x, center_y}, start_degrees, end_degrees, stops, tile_mode, matrix_term}} ->
        if tag == Atoms.sweep_gradient() do
          {colors, positions} = decode_gradient_stops(stops)
          tile_mode = GeneratedEnums.decode_tile_mode(tile_mode)
          matrix = optional_matrix_from_term(matrix_term)
          paint = Paint.default()
          paint.set_anti_alias(true).set_style(PaintStyle.Fill)

          case Shader.sweep_gradient(
                 {cast(center_x, :f32), cast(center_y, :f32)},
                 colors.as_slice(),
                 positions.as_deref(),
                 tile_mode,
                 some({cast(start_degrees, :f32), cast(end_degrees, :f32)}),
                 none(),
                 matrix.as_ref()
               ) do
            {:some, shader} -> paint.set_shader(shader)
            :none -> :ok
          end

          return!({:ok, paint})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(
           term,
           {R.atom(), R.term(), R.vec({R.path(:String), R.vec(R.f64())}),
            R.vec({R.path(:String), R.vec(R.i64())}), R.vec({R.path(:String), R.term()}),
            R.term()}
         ) do
      {:ok, {tag, effect_term, float_uniforms, int_uniforms, children, matrix_term}} ->
        if tag == Atoms.runtime_effect_shader() do
          effect = unwrap!(runtime_effect_from_term(effect_term))
          uniforms = unwrap!(runtime_uniform_data(ref(effect), float_uniforms, int_uniforms))
          children = unwrap!(runtime_children(ref(effect), children))
          matrix = optional_matrix_from_term(matrix_term)
          paint = Paint.default()
          paint.set_anti_alias(true).set_style(PaintStyle.Fill)

          paint.set_shader(
            unwrap!(
              effect.make_shader(uniforms, children.as_slice(), matrix.as_ref()).ok_or(badarg())
            )
          )

          return!({:ok, paint})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term(), R.atom(), R.atom(), R.term(), R.term()}) do
      {:ok, {tag, image_term, tile_x, tile_y, sampling_term, matrix_term}} ->
        if tag == Atoms.image_shader() do
          image = unwrap!(image_from_term(image_term))
          tile_x = GeneratedEnums.decode_tile_mode(tile_x)
          tile_y = GeneratedEnums.decode_tile_mode(tile_y)
          sampling = decode_sampling_options(sampling_term)
          matrix = optional_matrix_from_term(matrix_term)
          paint = Paint.default()
          paint.set_anti_alias(true).set_style(PaintStyle.Fill)

          case image.to_shader({tile_x, tile_y}, sampling, matrix.as_ref()) do
            {:some, shader} -> paint.set_shader(shader)
            :none -> :ok
          end

          return!({:ok, paint})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term(), R.atom(), R.atom(), R.atom(), R.term(), R.term()}) do
      {:ok, {tag, picture_term, tile_x, tile_y, filter_mode, matrix_term, tile_rect_term}} ->
        if tag == Atoms.picture_shader() do
          picture = unwrap!(picture_from_term(picture_term))
          tile_x = GeneratedEnums.decode_tile_mode(tile_x)
          tile_y = GeneratedEnums.decode_tile_mode(tile_y)
          filter_mode = GeneratedEnums.decode_sampling(filter_mode)
          matrix = optional_matrix_from_term(matrix_term)
          tile_rect = optional_rect_from_term(tile_rect_term)
          paint = Paint.default()
          paint.set_anti_alias(true).set_style(PaintStyle.Fill)

          paint.set_shader(
            picture.to_shader({tile_x, tile_y}, filter_mode, matrix.as_ref(), tile_rect.as_ref())
          )

          return!({:ok, paint})
        end

      {:error, _reason} ->
        :ok
    end

    {:error, badarg()}
  end

  @spec decode_sampling_options(R.term()) :: R.nif_result(R.path(:SamplingOptions))
  defrust decode_sampling_options(term) do
    case decode_as(term, {R.atom(), R.atom(), R.atom()}) do
      {:ok, {tag, filter, mipmap}} ->
        if tag == Atoms.sampling_options() do
          return!(
            {:ok,
             SkiaSafe.SamplingOptions.new(
               unwrap!(GeneratedEnums.decode_sampling(filter)),
               unwrap!(GeneratedEnums.decode_mipmap_mode(mipmap))
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term()}) do
      {:ok, {tag, cubic_term}} ->
        if tag == Atoms.sampling_cubic() do
          cubic =
            case decode_as(cubic_term, R.atom()) do
              {:ok, atom} ->
                if atom == Atoms.mitchell() do
                  CubicResampler.mitchell()
                else
                  if atom == Atoms.catmull_rom() do
                    CubicResampler.catmull_rom()
                  else
                    {b, c} = decode_as!(cubic_term, {R.f64(), R.f64()})
                    struct_literal(CubicResampler, b: cast(b, :f32), c: cast(c, :f32))
                  end
                end

              {:error, _reason} ->
                {b, c} = decode_as!(cubic_term, {R.f64(), R.f64()})
                struct_literal(CubicResampler, b: cast(b, :f32), c: cast(c, :f32))
            end

          return!({:ok, SkiaSafe.SamplingOptions.from(cubic)})
        end

        if tag == Atoms.sampling_aniso() do
          return!(
            {:ok,
             SkiaSafe.SamplingOptions.from_aniso(decode_as!(cubic_term, R.i64()) |> cast(:i32))}
          )
        end

      {:error, _reason} ->
        :ok
    end

    {:error, badarg()}
  end

  @spec decode_color_filter(R.term()) :: R.nif_result(R.path(:ColorFilter))
  defrust decode_color_filter(term) do
    case decode_as(term, {R.atom(), R.term(), R.atom()}) do
      {:ok, {tag, color_term, blend_mode}} ->
        if tag == Atoms.blend_color_filter() do
          return!(
            {:ok,
             unwrap!(
               ColorFilters.blend(
                 unwrap!(decode_color(color_term)),
                 unwrap!(GeneratedEnums.decode_blend_mode(blend_mode))
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.vec(R.f64()), R.bool()}) do
      {:ok, {tag, matrix, clamp}} ->
        if tag == Atoms.matrix_color_filter() and matrix.len() == 20 do
          values =
            array([
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32),
              cast(0.0, :f32)
            ])

          index = cast(0, :usize)

          for value <- matrix do
            assign!(index(values, index), cast(value, :f32))
            assign!(index, index + cast(1, :usize))
          end

          clamp =
            if clamp do
              SkiaSafe.ColorFilterClamp.Yes
            else
              SkiaSafe.ColorFilterClamp.No
            end

          return!({:ok, ColorFilters.matrix_row_major(ref(values), clamp)})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term(), R.term()}) do
      {:ok, {tag, outer, inner}} ->
        if tag == Atoms.compose_color_filter() do
          return!(
            {:ok,
             unwrap!(
               ColorFilters.compose(
                 unwrap!(decode_color_filter(outer)),
                 unwrap!(decode_color_filter(inner))
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    {:error, badarg()}
  end

  @spec decode_image_filter(R.term()) :: R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_image_filter(term) do
    case decode_as(term, {R.atom(), R.f64(), R.f64(), R.atom()}) do
      {:ok, {tag, sigma_x, sigma_y, tile_mode}} ->
        if tag == Atoms.blur_filter() do
          return!(
            {:ok,
             unwrap!(
               ImageFilters.blur(
                 {cast(sigma_x, :f32), cast(sigma_y, :f32)},
                 unwrap!(GeneratedEnums.decode_tile_mode(tile_mode)),
                 none(),
                 none()
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term(), R.term()}) do
      {:ok, {tag, outer, inner}} ->
        if tag == Atoms.compose_filter() do
          return!(
            {:ok,
             unwrap!(
               ImageFilters.compose(
                 unwrap!(decode_image_filter(outer)),
                 unwrap!(decode_image_filter(inner))
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.f64(), R.f64(), R.term()}) do
      {:ok, {tag, x, y, input_term}} ->
        if tag == Atoms.offset_filter() do
          return!(
            {:ok,
             unwrap!(
               ImageFilters.offset(
                 {cast(x, :f32), cast(y, :f32)},
                 optional_image_filter_from_term(input_term),
                 none()
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.f64(), R.f64(), R.f64(), R.f64(), R.term(), R.term()}) do
      {:ok, {tag, dx, dy, sigma_x, sigma_y, color_term, shadow_opts}} ->
        if tag == Atoms.drop_shadow_filter() do
          {input_term, shadow_only} = decode_as!(shadow_opts, {R.term(), R.bool()})
          color = unwrap!(decode_color(color_term))
          input = optional_image_filter_from_term(input_term)

          filter =
            if shadow_only do
              ImageFilters.drop_shadow_only(
                {cast(dx, :f32), cast(dy, :f32)},
                {cast(sigma_x, :f32), cast(sigma_y, :f32)},
                color,
                none(),
                input,
                none()
              )
            else
              ImageFilters.drop_shadow(
                {cast(dx, :f32), cast(dy, :f32)},
                {cast(sigma_x, :f32), cast(sigma_y, :f32)},
                color,
                none(),
                input,
                none()
              )
            end

          return!({:ok, unwrap!(filter.ok_or(badarg()))})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term(), R.term()}) do
      {:ok, {tag, filter_term, input_term}} ->
        if tag == Atoms.color_filter_image_filter() do
          return!(
            {:ok,
             unwrap!(
               ImageFilters.color_filter(
                 unwrap!(decode_color_filter(filter_term)),
                 optional_image_filter_from_term(input_term),
                 none()
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term()}) do
      {:ok, {tag, shader_term}} ->
        if tag == Atoms.shader_image_filter() do
          return!(
            {:ok,
             unwrap!(
               ImageFilters.shader(unwrap!(decode_shader(shader_term)), none()).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(
           term,
           {R.atom(), {R.f64(), R.f64(), R.f64(), R.f64()}, R.f64(), R.f64(), R.term(), R.term()}
         ) do
      {:ok, {tag, {x, y, width, height}, zoom, inset, sampling_term, input_term}} ->
        if tag == Atoms.magnifier_filter() do
          return!(
            {:ok,
             unwrap!(
               ImageFilters.magnifier(
                 Rect.from_xywh(
                   cast(x, :f32),
                   cast(y, :f32),
                   cast(width, :f32),
                   cast(height, :f32)
                 ),
                 cast(zoom, :f32),
                 cast(inset, :f32),
                 decode_sampling_options(sampling_term),
                 optional_image_filter_from_term(input_term),
                 none()
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), {R.i64(), R.i64()}, R.vec(R.f64()), R.term()}) do
      {:ok, {tag, {kernel_width, kernel_height}, kernel, conv_opts}} ->
        if tag == Atoms.matrix_convolution_filter() do
          {gain, bias, {offset_x, offset_y}, tile, convolve_alpha, input_term} =
            decode_as!(
              conv_opts,
              {R.f64(), R.f64(), {R.i64(), R.i64()}, R.atom(), R.bool(), R.term()}
            )

          mapped_kernel = Vec.with_capacity(kernel.len())

          for value <- kernel do
            mapped_kernel.push(cast(value, :f32))
          end

          return!(
            {:ok,
             unwrap!(
               ImageFilters.matrix_convolution(
                 {cast(kernel_width, :i32), cast(kernel_height, :i32)},
                 mapped_kernel.as_slice(),
                 cast(gain, :f32),
                 cast(bias, :f32),
                 {cast(offset_x, :i32), cast(offset_y, :i32)},
                 GeneratedEnums.decode_tile_mode(tile),
                 convolve_alpha,
                 optional_image_filter_from_term(input_term),
                 none()
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term(), R.term(), R.term()}) do
      {:ok, {tag, matrix_term, sampling_term, input_term}} ->
        if tag == Atoms.matrix_transform_filter() do
          return!(
            {:ok,
             unwrap!(
               ImageFilters.matrix_transform(
                 ref(unwrap!(matrix_from_term(matrix_term))),
                 decode_sampling_options(sampling_term),
                 optional_image_filter_from_term(input_term)
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.vec(R.term())}) do
      {:ok, {tag, filters}} ->
        if tag == Atoms.merge_filter() do
          mapped_filters = Vec.with_capacity(filters.len())

          for filter <- filters do
            mapped_filters.push(unwrap!(optional_image_filter_from_term(filter)))
          end

          return!({:ok, unwrap!(ImageFilters.merge(mapped_filters, none()).ok_or(badarg()))})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(
           term,
           {R.atom(), {R.f64(), R.f64(), R.f64(), R.f64()}, {R.f64(), R.f64(), R.f64(), R.f64()},
            R.term()}
         ) do
      {:ok, {tag, {src_x, src_y, src_w, src_h}, {dst_x, dst_y, dst_w, dst_h}, input_term}} ->
        if tag == Atoms.tile_filter() do
          return!(
            {:ok,
             unwrap!(
               ImageFilters.tile(
                 Rect.from_xywh(
                   cast(src_x, :f32),
                   cast(src_y, :f32),
                   cast(src_w, :f32),
                   cast(src_h, :f32)
                 ),
                 Rect.from_xywh(
                   cast(dst_x, :f32),
                   cast(dst_y, :f32),
                   cast(dst_w, :f32),
                   cast(dst_h, :f32)
                 ),
                 optional_image_filter_from_term(input_term)
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.atom(), R.f64(), R.f64(), R.term()}) do
      {:ok, {tag, op, radius_x, radius_y, input_term}} ->
        if tag == Atoms.morphology_filter() do
          input = optional_image_filter_from_term(input_term)

          if op == Atoms.dilate() do
            return!(
              {:ok,
               unwrap!(
                 ImageFilters.dilate({cast(radius_x, :f32), cast(radius_y, :f32)}, input, none()).ok_or(
                   badarg()
                 )
               )}
            )
          end

          if op == Atoms.erode() do
            return!(
              {:ok,
               unwrap!(
                 ImageFilters.erode({cast(radius_x, :f32), cast(radius_y, :f32)}, input, none()).ok_or(
                   badarg()
                 )
               )}
            )
          end

          return!({:error, badarg()})
        end

      {:error, _reason} ->
        :ok
    end

    {:error, badarg()}
  end

  @spec optional_image_filter_from_term(R.term()) ::
          R.nif_result(R.option(R.path({:skia_safe, :ImageFilter})))
  defrust optional_image_filter_from_term(term) do
    case decode_as(term, R.atom()) do
      {:ok, atom} ->
        if atom == Atoms.nil() do
          {:ok, none()}
        else
          {:ok, some(decode_image_filter(term))}
        end

      {:error, _reason} ->
        {:ok, some(decode_image_filter(term))}
    end
  end

  @spec decode_shader(R.term()) :: R.nif_result(R.path(:Shader))
  defrust decode_shader(term) do
    paint = unwrap!(decode_paint(term))
    paint.shader().ok_or(badarg())
  end

  @spec decode_mask_filter(R.term()) :: R.nif_result(R.path(:MaskFilter))
  defrust decode_mask_filter(term) do
    case decode_as(term, {R.atom(), R.atom(), R.f64(), R.bool()}) do
      {:ok, {tag, style, sigma, respect_ctm}} ->
        if tag == Atoms.blur_mask_filter() do
          return!(
            {:ok,
             unwrap!(
               SkiaSafe.MaskFilter.blur(
                 unwrap!(GeneratedEnums.decode_blur_style(style)),
                 cast(sigma, :f32),
                 respect_ctm
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    {:error, badarg()}
  end

  @spec decode_path_effect(R.term()) :: R.nif_result(R.path(:PathEffect))
  defrust decode_path_effect(term) do
    case decode_as(term, {R.atom(), R.vec(R.f64()), R.f64()}) do
      {:ok, {tag, intervals, phase}} ->
        if tag == Atoms.dash_path_effect() do
          mapped_intervals = Vec.with_capacity(intervals.len())

          for value <- intervals do
            mapped_intervals.push(cast(value, :f32))
          end

          return!(
            {:ok,
             unwrap!(
               SkiaSafe.PathEffect.dash(mapped_intervals.as_slice(), cast(phase, :f32)).ok_or(
                 badarg()
               )
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.f64()}) do
      {:ok, {tag, radius}} ->
        if tag == Atoms.corner_path_effect() do
          return!(
            {:ok, unwrap!(SkiaSafe.PathEffect.corner_path(cast(radius, :f32)).ok_or(badarg()))}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.f64(), R.f64(), R.atom()}) do
      {:ok, {tag, start, stop, mode}} ->
        if tag == Atoms.trim_path_effect() do
          if mode == Atoms.inverted() do
            return!(
              {:ok,
               unwrap!(
                 SkiaSafe.PathEffect.trim(
                   cast(start, :f32),
                   cast(stop, :f32),
                   SkiaSafe.TrimPathMode.Inverted
                 ).ok_or(badarg())
               )}
            )
          end

          if mode == Atoms.normal() do
            return!(
              {:ok,
               unwrap!(
                 SkiaSafe.PathEffect.trim(
                   cast(start, :f32),
                   cast(stop, :f32),
                   SkiaSafe.TrimPathMode.Normal
                 ).ok_or(badarg())
               )}
            )
          end

          return!({:error, badarg()})
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.f64(), R.f64(), R.term()}) do
      {:ok, {tag, segment_length, deviation, seed_term}} ->
        if tag == Atoms.discrete_path_effect() do
          seed =
            case decode_as(seed_term, R.atom()) do
              {:ok, atom} ->
                if atom == Atoms.nil() do
                  none()
                else
                  some(decode_as!(seed_term, R.i64()) |> cast(:u32))
                end

              {:error, _reason} ->
                some(decode_as!(seed_term, R.i64()) |> cast(:u32))
            end

          return!(
            {:ok,
             unwrap!(
               SkiaSafe.PathEffect.discrete(
                 cast(segment_length, :f32),
                 cast(deviation, :f32),
                 seed
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term(), R.f64(), R.f64(), R.atom()}) do
      {:ok, {tag, path_term, advance, phase, style}} ->
        if tag == Atoms.path_1d_effect() do
          return!(
            {:ok,
             unwrap!(
               SkiaSafe.PathEffect.path_1d(
                 ref(unwrap!(build_path(path_term))),
                 cast(advance, :f32),
                 cast(phase, :f32),
                 unwrap!(decode_path_1d_style(style))
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.f64(), R.term()}) do
      {:ok, {tag, width, matrix_term}} ->
        if tag == Atoms.line_2d_effect() do
          return!(
            {:ok,
             unwrap!(
               SkiaSafe.PathEffect.line_2d(
                 cast(width, :f32),
                 ref(unwrap!(matrix_from_term(matrix_term)))
               ).ok_or(badarg())
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    case decode_as(term, {R.atom(), R.term(), R.term()}) do
      {:ok, {tag, first, second}} ->
        if tag == Atoms.path_2d_effect() do
          return!(
            {:ok,
             SkiaSafe.PathEffect.path_2d(
               ref(unwrap!(matrix_from_term(first))),
               ref(unwrap!(build_path(second)))
             )}
          )
        end

        if tag == Atoms.compose_path_effect() do
          return!(
            {:ok,
             SkiaSafe.PathEffect.compose(
               unwrap!(decode_path_effect(first)),
               unwrap!(decode_path_effect(second))
             )}
          )
        end

        if tag == Atoms.sum_path_effect() do
          return!(
            {:ok,
             SkiaSafe.PathEffect.sum(
               unwrap!(decode_path_effect(first)),
               unwrap!(decode_path_effect(second))
             )}
          )
        end

      {:error, _reason} ->
        :ok
    end

    {:error, badarg()}
  end

  @spec decode_color(R.term()) :: R.nif_result(R.path(:Color))
  defrust decode_color(term) do
    case decode_as(term, {R.atom(), R.u32()}) do
      {:ok, {tag, rgba}} ->
        if tag == Atoms.c() do
          red = Bitwise.band(Bitwise.bsr(rgba, 24), 0xFF) |> cast(:u8)
          green = Bitwise.band(Bitwise.bsr(rgba, 16), 0xFF) |> cast(:u8)
          blue = Bitwise.band(Bitwise.bsr(rgba, 8), 0xFF) |> cast(:u8)
          alpha = Bitwise.band(rgba, 0xFF) |> cast(:u8)

          return!({:ok, Color.from_argb(alpha, red, green, blue)})
        end

      {:error, _reason} ->
        :ok
    end

    {tag, red, green, blue, alpha} = decode_as!(term, {R.atom(), R.u8(), R.u8(), R.u8(), R.u8()})

    if tag == Atoms.rgba() do
      {:ok, Color.from_argb(alpha, red, green, blue)}
    else
      {:error, badarg()}
    end
  end

  @spec decode_gradient_stops(R.vec(R.term())) ::
          R.nif_result({R.vec(R.path(:Color)), R.option(R.vec(R.f32()))})
  defrust decode_gradient_stops(stops) do
    colors = Vec.with_capacity(stops.len())
    positions = Vec.with_capacity(stops.len())
    explicit_positions = true

    for stop <- stops do
      case decode_as(stop, {R.atom(), R.term(), R.f64()}) do
        {:ok, {tag, color_term, position}} ->
          if tag == Atoms.gradient_stop() do
            colors.push(unwrap!(decode_color(color_term)))
            positions.push(cast(position, :f32))
          else
            assign!(explicit_positions, false)
            colors.push(unwrap!(decode_color(stop)))
          end

        {:error, _reason} ->
          assign!(explicit_positions, false)
          colors.push(unwrap!(decode_color(stop)))
      end
    end

    if explicit_positions do
      {:ok, {colors, some(positions)}}
    else
      {:ok, {colors, none()}}
    end
  end
end
