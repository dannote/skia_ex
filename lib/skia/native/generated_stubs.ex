defmodule Skia.Native.GeneratedStubs do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      def compile_runtime_effect(_source) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def render_png(_batch) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def render_rgba(_batch) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def render_compact_png(_batch) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def render_compact_rgba(_batch) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def render_jpeg(_batch, _quality) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def render_webp(_batch, _quality) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def decode_image(_bytes) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def encode_image(_image_term, _format, _quality) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def resize_image(_image_term, _width, _height) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def crop_image(_image_term, _source) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def load_font(_bytes) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def font_families do
        :erlang.nif_error(:nif_not_loaded)
      end

      def match_font(_family, _weight, _slant) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def typeface_info(_typeface_term) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def font_metrics(_font_term) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def font_glyph_ids(_font_term, _text) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def measure_text(_text, _font_term, _size) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def create_text_blob(_text, _font_term, _size) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def text_blob_bounds(_blob_term) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def record_picture(_batch) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def decode_picture(_bytes) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def encode_picture(_picture_term) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def picture_info(_picture_term) do
        :erlang.nif_error(:nif_not_loaded)
      end

      def path_to_svg(_path_term) do
        :erlang.nif_error(:nif_not_loaded)
      end
    end
  end
end
