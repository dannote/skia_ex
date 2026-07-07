defmodule Skia.Codegen.Rusty.PaintSupport do
  @moduledoc false

  use Skia.Codegen.Rusty.SkiaSafeSources,
    files: [
      :color,
      :color_filter,
      :data,
      :gradient_shader,
      :image,
      :image_filters,
      :mask_filter,
      :paint,
      :path_effects,
      :picture,
      :runtime_effect,
      :sampling_options,
      :shader
    ],
    rust_sources: [
      "native/skia_native/src/lib.rs",
      "native/skia_native/src/generated_enums.rs",
      "native/skia_native/src/generated_path.rs"
    ]

  alias RustQ.Type, as: R

  defrustmod(SkiaSafe.Path1DStyle, as: [:skia_safe, :path_1d_path_effect, :Style])
  defrustmod(SkiaSafe.TrimPathMode, as: [:skia_safe, :trim_path_effect, :Mode])
  defrustmod(SkiaSafe.SamplingOptions, as: :SamplingOptions)
  defrustmod(SkiaSafe.CubicResampler, as: :CubicResampler)
  defrustmod(SkiaSafe.PathEffect, as: :PathEffect)
  defrustmod(SkiaSafe.MaskFilter, as: :MaskFilter)
  defrustmod(SkiaSafe.ColorFilterClamp, as: [:color_filters, :Clamp])
  defrustmod(SkiaSafe.Shaders, as: [:skia_safe, :shaders])

  @spec decode_path_1d_style(atom()) ::
          R.nif_result(R.path({:skia_safe, :path_1d_path_effect, :Style}))
  defrust decode_path_1d_style(style) do
    case style do
      :translate -> {:ok, SkiaSafe.Path1DStyle.Translate}
      :rotate -> {:ok, SkiaSafe.Path1DStyle.Rotate}
      :morph -> {:ok, SkiaSafe.Path1DStyle.Morph}
      _ -> {:error, badarg()}
    end
  end

  @spec optional_matrix_from_term(term()) :: R.nif_result(R.option(R.path(:Matrix)))
  defrust optional_matrix_from_term(matrix_term) do
    case decode_as(matrix_term, atom()) do
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

  @spec optional_rect_from_term(term()) :: R.nif_result(R.option(Rect.t()))
  defrust optional_rect_from_term(rect_term) do
    case decode_as(rect_term, atom()) do
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

    for {name, values} <- float_uniforms, reduce: :ok do
      :ok ->
        uniform = ok_or!(effect.find_uniform(name), badarg())
        offset = uniform.offset()
        byte_len = values.len() * 4

        if offset + byte_len > bytes.len() or byte_len > uniform.size_in_bytes() do
          {:error, badarg()}
        else
          for {index, value} <- values.into_iter().enumerate() do
            start = offset + index * 4
            encoded = cast(value, :f32).to_ne_bytes()
            assign!(index(bytes, start), index(encoded, 0))
            assign!(index(bytes, start + 1), index(encoded, 1))
            assign!(index(bytes, start + 2), index(encoded, 2))
            assign!(index(bytes, start + 3), index(encoded, 3))
          end

          :ok
        end
    end

    for {name, values} <- int_uniforms, reduce: :ok do
      :ok ->
        uniform = ok_or!(effect.find_uniform(name), badarg())
        offset = uniform.offset()
        byte_len = values.len() * 4

        if offset + byte_len > bytes.len() or byte_len > uniform.size_in_bytes() do
          {:error, badarg()}
        else
          for {index, value} <- values.into_iter().enumerate() do
            start = offset + index * 4
            encoded = cast(value, :i32).to_ne_bytes()
            assign!(index(bytes, start), index(encoded, 0))
            assign!(index(bytes, start + 1), index(encoded, 1))
            assign!(index(bytes, start + 2), index(encoded, 2))
            assign!(index(bytes, start + 3), index(encoded, 3))
          end

          :ok
        end
    end

    {:ok, Data.new_copy(bytes)}
  end

  @spec runtime_children(R.ref(R.path(:RuntimeEffect)), R.vec({R.path(:String), term()})) ::
          R.nif_result(R.vec(R.path(:ChildPtr)))
  defrust runtime_children(effect, children) do
    effect_children = effect.children()
    ordered = Vec.with_capacity(effect_children.len())

    for _child <- effect_children do
      ordered.push(none())
    end

    for {name, child_term} <- children do
      child = ok_or!(effect.find_child(name), badarg())
      paint = decode_paint(child_term)
      shader = ok_or!(paint.shader(), badarg())
      assign!(index(ordered, child.index()), some(ChildPtr.from(shader)))
    end

    decoded = Vec.with_capacity(ordered.len())

    for child <- ordered, reduce: :ok do
      :ok ->
        case child do
          {:some, child} ->
            decoded.push(child)
            :ok

          :none ->
            {:error, badarg()}
        end
    end

    {:ok, decoded}
  end

  @spec decode_paint(term()) :: R.nif_result(Paint.t())
  defrust decode_paint(term) do
    case decode_color(term) do
      {:ok, color} -> {:ok, fill_paint(color)}
      {:error, _reason} -> decode_linear_gradient_paint(term)
    end
  end

  @spec decode_linear_gradient_paint(term()) :: R.nif_result(Paint.t())
  defrust decode_linear_gradient_paint(term) do
    case decode_as(
           term,
           {atom(), {R.f64(), R.f64()}, {R.f64(), R.f64()}, R.vec(term()), atom(), term()}
         ) do
      {:ok, {tag, {from_x, from_y}, {to_x, to_y}, stops, tile_mode, matrix_term}}
      when tag == Atoms.linear_gradient() ->
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

        {:ok, paint}

      _ ->
        decode_two_point_conical_gradient_paint(term)
    end
  end

  @spec decode_two_point_conical_gradient_paint(term()) :: R.nif_result(Paint.t())
  defrust decode_two_point_conical_gradient_paint(term) do
    case decode_as(
           term,
           {atom(), {R.f64(), R.f64()}, R.f64(), {R.f64(), R.f64()}, R.f64(), term()}
         ) do
      {:ok, {tag, {start_x, start_y}, start_radius, {end_x, end_y}, end_radius, gradient_opts}}
      when tag == Atoms.two_point_conical_gradient() ->
        {stops, tile_mode, matrix_term} =
          decode_as!(gradient_opts, {R.vec(term()), atom(), term()})

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

        {:ok, paint}

      _ ->
        decode_color_shader_paint(term)
    end
  end

  @spec decode_color_shader_paint(term()) :: R.nif_result(Paint.t())
  defrust decode_color_shader_paint(term) do
    case decode_as(term, {atom(), term()}) do
      {:ok, {tag, color_term}} when tag == Atoms.color_shader() ->
        paint = Paint.default()
        paint.set_anti_alias(true).set_style(PaintStyle.Fill)
        paint.set_shader(SkiaSafe.Shaders.color(decode_color(color_term)))
        {:ok, paint}

      _ ->
        decode_radial_gradient_paint(term)
    end
  end

  @spec decode_radial_gradient_paint(term()) :: R.nif_result(Paint.t())
  defrust decode_radial_gradient_paint(term) do
    case decode_as(
           term,
           {atom(), {R.f64(), R.f64()}, R.f64(), R.vec(term()), atom(), term()}
         ) do
      {:ok, {tag, {center_x, center_y}, radius, stops, tile_mode, matrix_term}}
      when tag == Atoms.radial_gradient() ->
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

        {:ok, paint}

      _ ->
        decode_sweep_gradient_paint(term)
    end
  end

  @spec decode_sweep_gradient_paint(term()) :: R.nif_result(Paint.t())
  defrust decode_sweep_gradient_paint(term) do
    case decode_as(
           term,
           {atom(), {R.f64(), R.f64()}, R.f64(), R.f64(), R.vec(term()), atom(), term()}
         ) do
      {:ok,
       {tag, {center_x, center_y}, start_degrees, end_degrees, stops, tile_mode, matrix_term}}
      when tag == Atoms.sweep_gradient() ->
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

        {:ok, paint}

      _ ->
        decode_runtime_effect_shader_paint(term)
    end
  end

  @spec decode_runtime_effect_shader_paint(term()) :: R.nif_result(Paint.t())
  defrust decode_runtime_effect_shader_paint(term) do
    case decode_as(
           term,
           {atom(), term(), R.vec({R.path(:String), R.vec(R.f64())}),
            R.vec({R.path(:String), R.vec(R.i64())}), R.vec({R.path(:String), term()}), term()}
         ) do
      {:ok, {tag, effect_term, float_uniforms, int_uniforms, children, matrix_term}}
      when tag == Atoms.runtime_effect_shader() ->
        effect = runtime_effect_from_term(effect_term)
        uniforms = runtime_uniform_data(ref(effect), float_uniforms, int_uniforms)
        children = runtime_children(ref(effect), children)
        matrix = optional_matrix_from_term(matrix_term)
        paint = Paint.default()
        paint.set_anti_alias(true).set_style(PaintStyle.Fill)

        paint.set_shader(
          ok_or!(effect.make_shader(uniforms, children.as_slice(), matrix.as_ref()), badarg())
        )

        {:ok, paint}

      _ ->
        decode_image_shader_paint(term)
    end
  end

  @spec decode_image_shader_paint(term()) :: R.nif_result(Paint.t())
  defrust decode_image_shader_paint(term) do
    case decode_as(term, {atom(), term(), atom(), atom(), term(), term()}) do
      {:ok, {tag, image_term, tile_x, tile_y, sampling_term, matrix_term}}
      when tag == Atoms.image_shader() ->
        image = image_from_term(image_term)
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

        {:ok, paint}

      _ ->
        decode_picture_shader_paint(term)
    end
  end

  @spec decode_picture_shader_paint(term()) :: R.nif_result(Paint.t())
  defrust decode_picture_shader_paint(term) do
    case decode_as(term, {atom(), term(), atom(), atom(), atom(), term(), term()}) do
      {:ok, {tag, picture_term, tile_x, tile_y, filter_mode, matrix_term, tile_rect_term}}
      when tag == Atoms.picture_shader() ->
        picture = picture_from_term(picture_term)
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

        {:ok, paint}

      _ ->
        {:error, badarg()}
    end
  end

  @spec decode_sampling_options(term()) :: R.nif_result(R.path(:SamplingOptions))
  defrust decode_sampling_options(term) do
    case decode_as(term, {atom(), atom(), atom()}) do
      {:ok, {tag, filter, mipmap}} ->
        if tag == Atoms.sampling_options() do
          {:ok,
           SkiaSafe.SamplingOptions.new(
             GeneratedEnums.decode_sampling(filter),
             GeneratedEnums.decode_mipmap_mode(mipmap)
           )}
        else
          decode_sampling_cubic_or_aniso(term)
        end

      {:error, _reason} ->
        decode_sampling_cubic_or_aniso(term)
    end
  end

  @spec decode_sampling_cubic_or_aniso(term()) :: R.nif_result(R.path(:SamplingOptions))
  defrust decode_sampling_cubic_or_aniso(term) do
    case decode_as(term, {atom(), term()}) do
      {:ok, {tag, cubic_term}} ->
        if tag == Atoms.sampling_cubic() do
          cubic =
            case decode_as(cubic_term, atom()) do
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

          {:ok, SkiaSafe.SamplingOptions.from(cubic)}
        else
          if tag == Atoms.sampling_aniso() do
            {:ok,
             SkiaSafe.SamplingOptions.from_aniso(decode_as!(cubic_term, R.i64()) |> cast(:i32))}
          else
            {:error, badarg()}
          end
        end

      {:error, _reason} ->
        {:error, badarg()}
    end
  end

  @spec decode_color_filter(term()) :: R.nif_result(R.path(:ColorFilter))
  defrust decode_color_filter(term) do
    case decode_as(term, {atom(), term(), atom()}) do
      {:ok, {tag, color_term, blend_mode}} ->
        if tag == Atoms.blend_color_filter() do
          {:ok,
           ok_or!(
             ColorFilters.blend(
               decode_color(color_term),
               GeneratedEnums.decode_blend_mode(blend_mode)
             ),
             badarg()
           )}
        else
          decode_matrix_color_filter(term)
        end

      {:error, _reason} ->
        decode_matrix_color_filter(term)
    end
  end

  @spec decode_matrix_color_filter(term()) :: R.nif_result(R.path(:ColorFilter))
  defrust decode_matrix_color_filter(term) do
    case decode_as(term, {atom(), R.vec(R.f64()), R.bool()}) do
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

          {:ok, ColorFilters.matrix_row_major(ref(values), clamp)}
        else
          decode_compose_color_filter(term)
        end

      {:error, _reason} ->
        decode_compose_color_filter(term)
    end
  end

  @spec decode_compose_color_filter(term()) :: R.nif_result(R.path(:ColorFilter))
  defrust decode_compose_color_filter(term) do
    case decode_as(term, {atom(), term(), term()}) do
      {:ok, {tag, outer, inner}} ->
        if tag == Atoms.compose_color_filter() do
          {:ok,
           ok_or!(
             ColorFilters.compose(decode_color_filter(outer), decode_color_filter(inner)),
             badarg()
           )}
        else
          {:error, badarg()}
        end

      {:error, _reason} ->
        {:error, badarg()}
    end
  end

  @spec decode_image_filter(term()) :: R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_image_filter(term) do
    case decode_as(term, {atom(), R.f64(), R.f64(), atom()}) do
      {:ok, {tag, sigma_x, sigma_y, tile_mode}} when tag == Atoms.blur_filter() ->
        {:ok,
         ok_or!(
           ImageFilters.blur(
             {cast(sigma_x, :f32), cast(sigma_y, :f32)},
             GeneratedEnums.decode_tile_mode(tile_mode),
             none(),
             none()
           ),
           badarg()
         )}

      _ ->
        decode_compose_image_filter(term)
    end
  end

  @spec decode_compose_image_filter(term()) :: R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_compose_image_filter(term) do
    case decode_as(term, {atom(), term(), term()}) do
      {:ok, {tag, outer, inner}} when tag == Atoms.compose_filter() ->
        {:ok,
         ok_or!(
           ImageFilters.compose(decode_image_filter(outer), decode_image_filter(inner)),
           badarg()
         )}

      _ ->
        decode_offset_image_filter(term)
    end
  end

  @spec decode_offset_image_filter(term()) :: R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_offset_image_filter(term) do
    case decode_as(term, {atom(), R.f64(), R.f64(), term()}) do
      {:ok, {tag, x, y, input_term}} when tag == Atoms.offset_filter() ->
        {:ok,
         ok_or!(
           ImageFilters.offset(
             {cast(x, :f32), cast(y, :f32)},
             optional_image_filter_from_term(input_term),
             none()
           ),
           badarg()
         )}

      _ ->
        decode_drop_shadow_image_filter(term)
    end
  end

  @spec decode_drop_shadow_image_filter(term()) ::
          R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_drop_shadow_image_filter(term) do
    case decode_as(term, {atom(), R.f64(), R.f64(), R.f64(), R.f64(), term(), term()}) do
      {:ok, {tag, dx, dy, sigma_x, sigma_y, color_term, shadow_opts}}
      when tag == Atoms.drop_shadow_filter() ->
        {input_term, shadow_only} = decode_as!(shadow_opts, {R.term(), R.bool()})
        color = decode_color(color_term)
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

        {:ok, ok_or!(filter, badarg())}

      _ ->
        decode_color_filter_image_filter(term)
    end
  end

  @spec decode_color_filter_image_filter(term()) ::
          R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_color_filter_image_filter(term) do
    case decode_as(term, {atom(), term(), term()}) do
      {:ok, {tag, filter_term, input_term}} when tag == Atoms.color_filter_image_filter() ->
        {:ok,
         ok_or!(
           ImageFilters.color_filter(
             decode_color_filter(filter_term),
             optional_image_filter_from_term(input_term),
             none()
           ),
           badarg()
         )}

      _ ->
        decode_shader_image_filter(term)
    end
  end

  @spec decode_shader_image_filter(term()) :: R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_shader_image_filter(term) do
    case decode_as(term, {atom(), term()}) do
      {:ok, {tag, shader_term}} when tag == Atoms.shader_image_filter() ->
        {:ok, ok_or!(ImageFilters.shader(decode_shader(shader_term), none()), badarg())}

      _ ->
        decode_magnifier_image_filter(term)
    end
  end

  @spec decode_magnifier_image_filter(term()) :: R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_magnifier_image_filter(term) do
    case decode_as(
           term,
           {atom(), {R.f64(), R.f64(), R.f64(), R.f64()}, R.f64(), R.f64(), term(), term()}
         ) do
      {:ok, {tag, {x, y, width, height}, zoom, inset, sampling_term, input_term}}
      when tag == Atoms.magnifier_filter() ->
        {:ok,
         ok_or!(
           ImageFilters.magnifier(
             Rect.from_xywh(cast(x, :f32), cast(y, :f32), cast(width, :f32), cast(height, :f32)),
             cast(zoom, :f32),
             cast(inset, :f32),
             decode_sampling_options(sampling_term),
             optional_image_filter_from_term(input_term),
             none()
           ),
           badarg()
         )}

      _ ->
        decode_matrix_convolution_image_filter(term)
    end
  end

  @spec decode_matrix_convolution_image_filter(term()) ::
          R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_matrix_convolution_image_filter(term) do
    case decode_as(term, {atom(), {R.i64(), R.i64()}, R.vec(R.f64()), term()}) do
      {:ok, {tag, {kernel_width, kernel_height}, kernel, conv_opts}}
      when tag == Atoms.matrix_convolution_filter() ->
        {gain, bias, {offset_x, offset_y}, tile, convolve_alpha, input_term} =
          decode_as!(
            conv_opts,
            {R.f64(), R.f64(), {R.i64(), R.i64()}, atom(), R.bool(), term()}
          )

        mapped_kernel = Vec.with_capacity(kernel.len())

        for value <- kernel do
          mapped_kernel.push(cast(value, :f32))
        end

        {:ok,
         ok_or!(
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
           ),
           badarg()
         )}

      _ ->
        decode_matrix_transform_image_filter(term)
    end
  end

  @spec decode_matrix_transform_image_filter(term()) ::
          R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_matrix_transform_image_filter(term) do
    case decode_as(term, {atom(), term(), term(), term()}) do
      {:ok, {tag, matrix_term, sampling_term, input_term}}
      when tag == Atoms.matrix_transform_filter() ->
        {:ok,
         ok_or!(
           ImageFilters.matrix_transform(
             ref(matrix_from_term(matrix_term)),
             decode_sampling_options(sampling_term),
             optional_image_filter_from_term(input_term)
           ),
           badarg()
         )}

      _ ->
        decode_merge_image_filter(term)
    end
  end

  @spec decode_merge_image_filter(term()) :: R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_merge_image_filter(term) do
    case decode_as(term, {atom(), R.vec(term())}) do
      {:ok, {tag, filters}} when tag == Atoms.merge_filter() ->
        mapped_filters = Vec.with_capacity(filters.len())

        for filter <- filters do
          mapped_filters.push(optional_image_filter_from_term(filter))
        end

        {:ok, ok_or!(ImageFilters.merge(mapped_filters, none()), badarg())}

      _ ->
        decode_tile_image_filter(term)
    end
  end

  @spec decode_tile_image_filter(term()) :: R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_tile_image_filter(term) do
    case decode_as(
           term,
           {atom(), {R.f64(), R.f64(), R.f64(), R.f64()}, {R.f64(), R.f64(), R.f64(), R.f64()},
            term()}
         ) do
      {:ok, {tag, {src_x, src_y, src_w, src_h}, {dst_x, dst_y, dst_w, dst_h}, input_term}}
      when tag == Atoms.tile_filter() ->
        {:ok,
         ok_or!(
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
           ),
           badarg()
         )}

      _ ->
        decode_morphology_image_filter(term)
    end
  end

  @spec decode_morphology_image_filter(term()) :: R.nif_result(R.path({:skia_safe, :ImageFilter}))
  defrust decode_morphology_image_filter(term) do
    case decode_as(term, {atom(), atom(), R.f64(), R.f64(), term()}) do
      {:ok, {tag, op, radius_x, radius_y, input_term}} when tag == Atoms.morphology_filter() ->
        input = optional_image_filter_from_term(input_term)

        if op == Atoms.dilate() do
          {:ok,
           ok_or!(
             ImageFilters.dilate({cast(radius_x, :f32), cast(radius_y, :f32)}, input, none()),
             badarg()
           )}
        else
          if op == Atoms.erode() do
            {:ok,
             ok_or!(
               ImageFilters.erode({cast(radius_x, :f32), cast(radius_y, :f32)}, input, none()),
               badarg()
             )}
          else
            {:error, badarg()}
          end
        end

      _ ->
        {:error, badarg()}
    end
  end

  @spec optional_image_filter_from_term(term()) ::
          R.nif_result(R.option(R.path({:skia_safe, :ImageFilter})))
  defrust optional_image_filter_from_term(term) do
    case decode_as(term, atom()) do
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

  @spec decode_shader(term()) :: R.nif_result(R.path(:Shader))
  defrust decode_shader(term) do
    paint = decode_paint(term)
    paint.shader().ok_or(badarg())
  end

  @spec decode_mask_filter(term()) :: R.nif_result(R.path(:MaskFilter))
  defrust decode_mask_filter(term) do
    case decode_as(term, {atom(), atom(), R.f64(), R.bool()}) do
      {:ok, {tag, style, sigma, respect_ctm}} ->
        if tag == Atoms.blur_mask_filter() do
          {:ok,
           ok_or!(
             SkiaSafe.MaskFilter.blur(
               GeneratedEnums.decode_blur_style(style),
               cast(sigma, :f32),
               respect_ctm
             ),
             badarg()
           )}
        else
          {:error, badarg()}
        end

      {:error, _reason} ->
        {:error, badarg()}
    end
  end

  @spec decode_path_effect(term()) :: R.nif_result(R.path(:PathEffect))
  defrust decode_path_effect(term) do
    case decode_as(term, {atom(), R.vec(R.f64()), R.f64()}) do
      {:ok, {tag, intervals, phase}} when tag == Atoms.dash_path_effect() ->
        mapped_intervals = Vec.with_capacity(intervals.len())

        for value <- intervals do
          mapped_intervals.push(cast(value, :f32))
        end

        {:ok,
         ok_or!(
           SkiaSafe.PathEffect.dash(mapped_intervals.as_slice(), cast(phase, :f32)),
           badarg()
         )}

      _ ->
        decode_corner_path_effect(term)
    end
  end

  @spec decode_corner_path_effect(term()) :: R.nif_result(R.path(:PathEffect))
  defrust decode_corner_path_effect(term) do
    case decode_as(term, {atom(), R.f64()}) do
      {:ok, {tag, radius}} when tag == Atoms.corner_path_effect() ->
        {:ok, ok_or!(SkiaSafe.PathEffect.corner_path(cast(radius, :f32)), badarg())}

      _ ->
        decode_trim_path_effect(term)
    end
  end

  @spec decode_trim_path_effect(term()) :: R.nif_result(R.path(:PathEffect))
  defrust decode_trim_path_effect(term) do
    case decode_as(term, {atom(), R.f64(), R.f64(), atom()}) do
      {:ok, {tag, start, stop, mode}} when tag == Atoms.trim_path_effect() ->
        if mode == Atoms.inverted() do
          {:ok,
           ok_or!(
             SkiaSafe.PathEffect.trim(
               cast(start, :f32),
               cast(stop, :f32),
               SkiaSafe.TrimPathMode.Inverted
             ),
             badarg()
           )}
        else
          if mode == Atoms.normal() do
            {:ok,
             ok_or!(
               SkiaSafe.PathEffect.trim(
                 cast(start, :f32),
                 cast(stop, :f32),
                 SkiaSafe.TrimPathMode.Normal
               ),
               badarg()
             )}
          else
            {:error, badarg()}
          end
        end

      _ ->
        decode_discrete_path_effect(term)
    end
  end

  @spec decode_discrete_path_effect(term()) :: R.nif_result(R.path(:PathEffect))
  defrust decode_discrete_path_effect(term) do
    case decode_as(term, {atom(), R.f64(), R.f64(), term()}) do
      {:ok, {tag, segment_length, deviation, seed_term}}
      when tag == Atoms.discrete_path_effect() ->
        seed =
          case decode_as(seed_term, atom()) do
            {:ok, atom} ->
              if atom == Atoms.nil() do
                none()
              else
                some(decode_as!(seed_term, R.i64()) |> cast(:u32))
              end

            {:error, _reason} ->
              some(decode_as!(seed_term, R.i64()) |> cast(:u32))
          end

        {:ok,
         ok_or!(
           SkiaSafe.PathEffect.discrete(cast(segment_length, :f32), cast(deviation, :f32), seed),
           badarg()
         )}

      _ ->
        decode_path_1d_effect(term)
    end
  end

  @spec decode_path_1d_effect(term()) :: R.nif_result(R.path(:PathEffect))
  defrust decode_path_1d_effect(term) do
    case decode_as(term, {atom(), term(), R.f64(), R.f64(), atom()}) do
      {:ok, {tag, path_term, advance, phase, style}} when tag == Atoms.path_1d_effect() ->
        {:ok,
         ok_or!(
           SkiaSafe.PathEffect.path_1d(
             ref(build_path(path_term)),
             cast(advance, :f32),
             cast(phase, :f32),
             decode_path_1d_style(style)
           ),
           badarg()
         )}

      _ ->
        decode_line_2d_path_effect(term)
    end
  end

  @spec decode_line_2d_path_effect(term()) :: R.nif_result(R.path(:PathEffect))
  defrust decode_line_2d_path_effect(term) do
    case decode_as(term, {atom(), R.f64(), term()}) do
      {:ok, {tag, width, matrix_term}} when tag == Atoms.line_2d_effect() ->
        {:ok,
         ok_or!(
           SkiaSafe.PathEffect.line_2d(cast(width, :f32), ref(matrix_from_term(matrix_term))),
           badarg()
         )}

      _ ->
        decode_binary_path_effect(term)
    end
  end

  @spec decode_binary_path_effect(term()) :: R.nif_result(R.path(:PathEffect))
  defrust decode_binary_path_effect(term) do
    case decode_as(term, {atom(), term(), term()}) do
      {:ok, {tag, first, second}} when tag == Atoms.path_2d_effect() ->
        {:ok, SkiaSafe.PathEffect.path_2d(ref(matrix_from_term(first)), ref(build_path(second)))}

      {:ok, {tag, first, second}} when tag == Atoms.compose_path_effect() ->
        {:ok, SkiaSafe.PathEffect.compose(decode_path_effect(first), decode_path_effect(second))}

      {:ok, {tag, first, second}} when tag == Atoms.sum_path_effect() ->
        {:ok, SkiaSafe.PathEffect.sum(decode_path_effect(first), decode_path_effect(second))}

      _ ->
        {:error, badarg()}
    end
  end

  @spec decode_color(term()) :: R.nif_result(R.path(:Color))
  defrust decode_color(term) do
    case decode_as(term, {atom(), R.u32()}) do
      {:ok, {tag, rgba}} ->
        if tag == Atoms.c() do
          red = Bitwise.band(Bitwise.bsr(rgba, 24), 0xFF) |> cast(:u8)
          green = Bitwise.band(Bitwise.bsr(rgba, 16), 0xFF) |> cast(:u8)
          blue = Bitwise.band(Bitwise.bsr(rgba, 8), 0xFF) |> cast(:u8)
          alpha = Bitwise.band(rgba, 0xFF) |> cast(:u8)

          {:ok, Color.from_argb(alpha, red, green, blue)}
        else
          decode_rgba_color(term)
        end

      {:error, _reason} ->
        decode_rgba_color(term)
    end
  end

  @spec decode_rgba_color(term()) :: R.nif_result(R.path(:Color))
  defrust decode_rgba_color(term) do
    {tag, red, green, blue, alpha} = decode_as!(term, {atom(), R.u8(), R.u8(), R.u8(), R.u8()})

    if tag == Atoms.rgba() do
      {:ok, Color.from_argb(alpha, red, green, blue)}
    else
      {:error, badarg()}
    end
  end

  @spec decode_gradient_stops(R.vec(term())) ::
          R.nif_result({R.vec(R.path(:Color)), R.option(R.vec(R.f32()))})
  defrust decode_gradient_stops(stops) do
    colors = Vec.with_capacity(stops.len())
    positions = Vec.with_capacity(stops.len())
    explicit_positions = true

    for stop <- stops do
      case decode_as(stop, {atom(), term(), R.f64()}) do
        {:ok, {tag, color_term, position}} ->
          if tag == Atoms.gradient_stop() do
            colors.push(decode_color(color_term))
            positions.push(cast(position, :f32))
          else
            assign!(explicit_positions, false)
            colors.push(decode_color(stop))
          end

        {:error, _reason} ->
          assign!(explicit_positions, false)
          colors.push(decode_color(stop))
      end
    end

    if explicit_positions do
      {:ok, {colors, some(positions)}}
    else
      {:ok, {colors, none()}}
    end
  end
end
