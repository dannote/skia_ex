defmodule Skia.Codegen.Rusty.PaintSupport do
  @moduledoc false

  use RustQ.Meta

  alias RustQ.Type, as: R

  defrustmod(SkiaSafe.Path1DStyle, as: [:skia_safe, :path_1d_path_effect, :Style])
  defrustmod(SkiaSafe.TrimPathMode, as: [:skia_safe, :trim_path_effect, :Mode])
  defrustmod(SkiaSafe.SamplingOptions, as: :SamplingOptions)
  defrustmod(SkiaSafe.CubicResampler, as: :CubicResampler)
  defrustmod(SkiaSafe.PathEffect, as: :PathEffect)
  defrustmod(SkiaSafe.MaskFilter, as: :MaskFilter)

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
          {:ok, some(unwrap!(matrix_from_term(matrix_term)))}
        end

      {:error, _reason} ->
        {:ok, some(unwrap!(matrix_from_term(matrix_term)))}
    end
  end

  @spec optional_rect_from_term(R.term()) :: R.nif_result(R.option(Rect.t()))
  defrust optional_rect_from_term(rect_term) do
    case decode_as(rect_term, R.atom()) do
      {:ok, atom} ->
        if atom == Atoms.nil() do
          {:ok, none()}
        else
          {:ok, some(unwrap!(rect_from_term(rect_term)))}
        end

      {:error, _reason} ->
        {:ok, some(unwrap!(rect_from_term(rect_term)))}
    end
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

  @spec optional_image_filter_from_term(R.term()) ::
          R.nif_result(R.option(R.path({:skia_safe, :ImageFilter})))
  defrust optional_image_filter_from_term(term) do
    case decode_as(term, R.atom()) do
      {:ok, atom} ->
        if atom == Atoms.nil() do
          {:ok, none()}
        else
          {:ok, some(unwrap!(decode_image_filter(term)))}
        end

      {:error, _reason} ->
        {:ok, some(unwrap!(decode_image_filter(term)))}
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
