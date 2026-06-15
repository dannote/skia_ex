defmodule Skia.Benchmark do
  @moduledoc "Small, dependency-free helpers for comparing batch and picture rendering overhead."

  @type result :: %{
          iterations: pos_integer(),
          normal_batch_bytes: non_neg_integer(),
          compact_batch_bytes: non_neg_integer(),
          normal_render_us: non_neg_integer(),
          compact_encode_us: non_neg_integer(),
          compact_render_us: non_neg_integer(),
          picture_record_us: non_neg_integer(),
          picture_replay_us: non_neg_integer()
        }

  @spec compare(Skia.Document.t(), keyword()) :: {:ok, result()} | {:error, atom(), map()}
  def compare(%Skia.Document{} = document, opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 10)
    iterations = max(iterations, 1)

    normal_batch = Skia.to_batch(document)
    compact_batch = Skia.Compact.encode(document)

    with {:ok, picture} <- Skia.Picture.record(document) do
      {:ok,
       %{
         iterations: iterations,
         normal_batch_bytes: byte_size(:erlang.term_to_binary(normal_batch)),
         compact_batch_bytes: byte_size(:erlang.term_to_binary(compact_batch)),
         normal_render_us: timed(iterations, fn -> Skia.to_raw(document) end),
         compact_encode_us: timed(iterations, fn -> Skia.Compact.encode_binary(document) end),
         compact_render_us: timed(iterations, fn -> Skia.Compact.to_raw(document) end),
         picture_record_us: timed(iterations, fn -> Skia.Picture.record(document) end),
         picture_replay_us:
           timed(iterations, fn ->
             document.width
             |> Skia.canvas(document.height)
             |> Skia.picture(picture)
             |> Skia.to_raw()
           end)
       }}
    end
  end

  defp timed(iterations, fun) do
    {microseconds, _} = :timer.tc(fn -> repeat(iterations, fun) end)
    div(microseconds, iterations)
  end

  defp repeat(0, _fun), do: :ok

  defp repeat(count, fun) do
    _ = fun.()
    repeat(count - 1, fun)
  end
end
