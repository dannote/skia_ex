defmodule Skia.Codegen.Rusty.PaintSupport do
  @moduledoc false

  use RustQ.Meta

  alias RustQ.Type, as: R

  defrustmod(SkiaSafe.Path1DStyle, as: [:skia_safe, :path_1d_path_effect, :Style])
  defrustmod(SkiaSafe.SamplingOptions, as: :SamplingOptions)
  defrustmod(SkiaSafe.CubicResampler, as: :CubicResampler)

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
