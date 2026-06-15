defmodule SkiaTest do
  use ExUnit.Case

  test "inspects core data structures compactly" do
    document =
      Skia.canvas(800, 600)
      |> Skia.clear(:white)

    [command] = Skia.commands(document)

    path =
      Skia.Path.new()
      |> Skia.Path.move_to(0, 0)
      |> Skia.Path.close()

    assert inspect(document) == "#Skia.Document<800x600 commands=1>"
    assert inspect(command) == "#Skia.Command<clear args=[{:rgba, 255, 255, 255, 255}]>"
    assert inspect(path) == "#Skia.Path<segments=2 closed=true>"
  end

  test "builds fluent command batches" do
    batch =
      Skia.canvas(800, 600)
      |> Skia.clear(:white)
      |> Skia.rect(x: 40, y: 40, width: 200, height: 100, radius: 12, fill: "#ef4444")
      |> Skia.text("Hello", x: 60, y: 100, size: 32)
      |> Skia.to_batch()

    assert batch.width == 800
    assert batch.height == 600

    assert [clear, rect, text] = batch.commands
    assert clear.op == :clear
    assert clear.args == [{:rgba, 255, 255, 255, 255}]
    assert rect.op == :rect
    assert rect.opts[:fill] == {:rgba, 239, 68, 68, 255}
    assert text.op == :text
    assert text.args == ["Hello"]
    assert text.opts[:fill] == {:rgba, 0, 0, 0, 255}
  end

  test "builds equivalent documents with do/end DSL" do
    defmodule Poster do
      use Skia.DSL

      def document do
        canvas 400, 300 do
          clear(:black)

          group translate: {20, 30}, rotate: 15 do
            style fill: :white, font: "Inter" do
              text("Launch", x: 10, y: 40, size: 24)
              rect(x: 10, y: 60, width: 120, height: 64, radius: 8, fill: "#3b82f6")
            end
          end
        end
      end
    end

    ops = Poster.document() |> Skia.commands() |> Enum.map(& &1.op)

    assert ops == [
             :clear,
             :save,
             :translate,
             :rotate,
             :push_style,
             :text,
             :rect,
             :pop_style,
             :restore
           ]
  end

  test "renders a raw RGBA buffer through the native batch boundary" do
    document =
      Skia.canvas(2, 1)
      |> Skia.clear(:red)

    assert {:ok, raw} = Skia.to_raw(document)
    assert raw.width == 2
    assert raw.height == 1
    assert raw.stride == 8
    assert raw.data == <<255, 0, 0, 255, 255, 0, 0, 255>>
  end

  test "measures text and draws text blobs through the native text engine" do
    assert {:ok, measurement} = Skia.measure_text("Hello", size: 18)
    assert measurement.width > 0
    assert {left, top, right, bottom} = measurement.bounds
    assert right >= left
    assert bottom >= top

    assert {:ok, blob} = Skia.TextBlob.new("Blob", size: 18)
    assert inspect(blob) == "#Skia.TextBlob<size=18.0 text=\"Blob\">"
    assert {:ok, {blob_left, blob_top, blob_right, blob_bottom}} = Skia.TextBlob.bounds(blob)
    assert blob_right >= blob_left
    assert blob_bottom >= blob_top

    document =
      Skia.canvas(32, 24)
      |> Skia.clear(:white)
      |> Skia.text_blob(blob, x: 2, y: 18, fill: :black)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 32 * 24 * 4
  end

  test "renders gradient paints through the native batch boundary" do
    document =
      Skia.canvas(8, 1)
      |> Skia.rect(
        x: 0,
        y: 0,
        width: 8,
        height: 1,
        fill: Skia.Shader.linear_gradient({0, 0}, {8, 0}, [:red, :blue])
      )

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 32
  end

  test "renders JPEG through the native batch boundary" do
    document =
      Skia.canvas(2, 2)
      |> Skia.clear(:white)

    assert {:ok, jpeg} = Skia.to_jpeg(document)
    assert <<255, 216, 255, _rest::binary>> = jpeg
  end

  test "encodes debuggable command batches" do
    batch =
      Skia.canvas(8, 8)
      |> Skia.clear(:white)
      |> Skia.to_batch()
      |> :erlang.term_to_binary()
      |> :erlang.binary_to_term()

    assert %{width: 8, height: 8, commands: [%Skia.Command{op: :clear}]} = batch
  end

  test "renders vertices meshes" do
    vertices =
      Skia.Vertices.new([{1, 1}, {7, 1}, {4, 7}],
        colors: [:red, :green, :blue]
      )

    document =
      Skia.canvas(8, 8)
      |> Skia.clear(:transparent)
      |> Skia.vertices(vertices)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 8 * 8 * 4
  end

  test "renders paint with mask filters" do
    document =
      Skia.canvas(8, 8)
      |> Skia.clear(:transparent)
      |> Skia.circle(x: 4, y: 4, radius: 2, fill: :red, mask_filter: Skia.MaskFilter.blur(1.0))

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 8 * 8 * 4
  end

  test "renders layers with composed generic image filters" do
    filter =
      Skia.ImageFilter.blur(1.0, tile: :decal)
      |> Skia.ImageFilter.compose(Skia.ImageFilter.offset(1, 0))

    document =
      Skia.canvas(4, 4)
      |> Skia.clear(:transparent)
      |> Skia.layer([image_filter: filter], fn doc ->
        Skia.circle(doc, x: 2, y: 2, radius: 1, fill: :red)
      end)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "renders layers with shadow and morphology image filters" do
    filter =
      Skia.ImageFilter.drop_shadow({1, 1}, {1, 1}, :blue, input: Skia.ImageFilter.dilate({1, 1}))

    document =
      Skia.canvas(4, 4)
      |> Skia.clear(:transparent)
      |> Skia.layer([image_filter: filter], fn doc ->
        Skia.rect(doc, x: 1, y: 1, width: 2, height: 2, fill: :red)
      end)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "renders layers with generic image filters" do
    document =
      Skia.canvas(4, 4)
      |> Skia.clear(:transparent)
      |> Skia.layer([image_filter: Skia.ImageFilter.blur(1.0, tile: :decal)], fn doc ->
        Skia.circle(doc, x: 2, y: 2, radius: 1, fill: :red)
      end)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "renders layers through the native batch boundary" do
    document =
      Skia.canvas(2, 1)
      |> Skia.clear(:transparent)
      |> Skia.layer([opacity: 0.5], fn doc ->
        Skia.rect(doc, x: 0, y: 0, width: 2, height: 1, fill: :red)
      end)

    assert {:ok, raw} = Skia.to_raw(document)
    assert <<red, 0, 0, alpha, red, 0, 0, alpha>> = raw.data
    assert red in 127..128
    assert alpha in 127..128
  end

  test "renders paths and text through the native batch boundary" do
    document =
      Skia.canvas(64, 64)
      |> Skia.clear(:white)
      |> Skia.path(
        Skia.Path.new()
        |> Skia.Path.move_to(8, 8)
        |> Skia.Path.line_to(56, 8)
        |> Skia.Path.line_to(32, 56)
        |> Skia.Path.close(),
        fill: :blue
      )
      |> Skia.text("A", x: 20, y: 40, size: 24, fill: :red)

    assert {:ok, png} = Skia.to_png(document)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = png
  end

  test "decodes and draws image resources" do
    source =
      Skia.canvas(4, 4)
      |> Skia.clear(:blue)

    assert {:ok, png} = Skia.to_png(source)
    assert {:ok, image} = Skia.Image.decode(png)
    assert Skia.Image.width(image) == 4
    assert Skia.Image.height(image) == 4
    assert inspect(image) == "#Skia.Image<4x4>"

    document =
      Skia.canvas(8, 8)
      |> Skia.clear(:white)
      |> Skia.image(image, x: 2, y: 2, width: 4, height: 4)

    assert {:ok, rendered} = Skia.to_png(document)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = rendered
  end

  test "records and draws reusable Skia pictures" do
    source =
      Skia.canvas(4, 4)
      |> Skia.clear(:transparent)
      |> Skia.rect(x: 0, y: 0, width: 4, height: 4, fill: :red)

    assert {:ok, picture} = Skia.Picture.record(source)
    assert Skia.Picture.width(picture) == 4
    assert Skia.Picture.height(picture) == 4
    assert inspect(picture) == "#Skia.Picture<4x4>"
    assert {:ok, info} = Skia.Picture.info(picture)
    assert info.cull_rect == {0.0, 0.0, 4.0, 4.0}
    assert info.op_count >= 1
    assert info.bytes_used > 0
    assert {:ok, bytes} = Skia.Picture.encode(picture)
    assert byte_size(bytes) > 0
    assert {:ok, decoded} = Skia.Picture.decode(bytes, width: 4, height: 4)

    document =
      Skia.canvas(8, 4)
      |> Skia.clear(:transparent)
      |> Skia.picture(decoded, x: 4, y: 0)

    assert {:ok, raw} = Skia.to_raw(document)
    assert <<0, 0, 0, 0, _::binary-size(12), 255, 0, 0, 255, _::binary>> = raw.data
    assert {:ok, image} = Skia.Image.from_picture(decoded)
    assert Skia.Image.width(image) == 4
    assert Skia.Image.height(image) == 4

    shader_doc =
      Skia.canvas(4, 4)
      |> Skia.rect(x: 0, y: 0, width: 4, height: 4, fill: Skia.Shader.picture(decoded))

    assert {:ok, shader_raw} = Skia.to_raw(shader_doc)
    assert byte_size(shader_raw.data) == 64
  end

  test "returns explicit native error atoms for malformed native inputs" do
    assert {:error, :invalid_picture} = Skia.Picture.decode("not a picture", 4, 4)
    assert {:error, :invalid_picture} = Skia.Picture.decode("not a picture", width: 0, height: 4)
    assert {:error, :invalid_path} = Skia.Path.to_svg(Skia.Path.from_svg("not a path"))

    invalid = %Skia.Document{
      width: 4,
      height: 4,
      commands: [%Skia.Command{op: :unknown, args: [], opts: []}]
    }

    assert {:error, :invalid_command, _batch} = Skia.to_raw(invalid)
  end

  test "supports image encode resize and crop helpers" do
    source =
      Skia.canvas(2, 1)
      |> Skia.rect(x: 0, y: 0, width: 1, height: 1, fill: :red)
      |> Skia.rect(x: 1, y: 0, width: 1, height: 1, fill: :blue)

    assert {:ok, png} = Skia.to_png(source)
    assert {:ok, image} = Skia.Image.decode(png)
    assert {:ok, encoded} = Skia.Image.encode(image, :png)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = encoded
    assert {:ok, resized} = Skia.Image.resize(image, 4, 2)
    assert Skia.Image.width(resized) == 4
    assert Skia.Image.height(resized) == 2
    assert {:ok, cropped} = Skia.Image.crop(image, {1, 0, 1, 1})
    assert Skia.Image.width(cropped) == 1
    assert Skia.Image.height(cropped) == 1
  end

  test "draws cropped image source rectangles" do
    source =
      Skia.canvas(2, 1)
      |> Skia.rect(x: 0, y: 0, width: 1, height: 1, fill: :red)
      |> Skia.rect(x: 1, y: 0, width: 1, height: 1, fill: :blue)

    assert {:ok, png} = Skia.to_png(source)
    assert {:ok, image} = Skia.Image.decode(png)

    document =
      Skia.canvas(1, 1)
      |> Skia.image(image,
        x: 0,
        y: 0,
        width: 1,
        height: 1,
        source: {1, 0, 1, 1},
        sampling: :nearest
      )

    assert {:ok, raw} = Skia.to_raw(document)
    assert raw.data == <<0, 0, 255, 255>>
  end

  test "supports blend modes and stroke styles" do
    document =
      Skia.canvas(2, 1)
      |> Skia.clear(:blue)
      |> Skia.rect(x: 0, y: 0, width: 1, height: 1, fill: :red, blend_mode: :multiply)
      |> Skia.line(
        from: {1, 0},
        to: {1, 1},
        stroke: :red,
        stroke_width: 1,
        stroke_cap: :round,
        stroke_join: :round
      )

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 8
  end

  test "clips path and circle drawing through the native batch boundary" do
    path =
      Skia.Path.new()
      |> Skia.Path.move_to(0, 0)
      |> Skia.Path.line_to(1, 0)
      |> Skia.Path.line_to(1, 1)
      |> Skia.Path.line_to(0, 1)
      |> Skia.Path.close()

    document =
      Skia.canvas(2, 1)
      |> Skia.clip_path(path)
      |> Skia.clip_circle(x: 0.5, y: 0.5, radius: 1, antialias: false)
      |> Skia.rect(x: 0, y: 0, width: 2, height: 1, fill: :red)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 8
  end

  test "clips drawing through the native batch boundary" do
    document =
      Skia.canvas(4, 1)
      |> Skia.clip_rect(x: 0, y: 0, width: 2, height: 1)
      |> Skia.rect(x: 0, y: 0, width: 4, height: 1, fill: :red)

    assert {:ok, raw} = Skia.to_raw(document)
    assert raw.data == <<255, 0, 0, 255, 255, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0>>
  end

  test "supports expanded transforms and layer options" do
    document =
      Skia.canvas(4, 4)
      |> Skia.group([translate: {1, 1}, scale: {2, 2}], fn doc ->
        Skia.rect(doc, x: 0, y: 0, width: 1, height: 1, fill: :red)
      end)
      |> Skia.group([rotate_at: {45, 2, 2}], fn doc ->
        Skia.oval(doc, x: 1, y: 1, width: 2, height: 2, fill: :blue)
      end)
      |> Skia.layer(
        [opacity: 0.8, bounds: {0, 0, 4, 4}, blend_mode: :src_over, blur: 0.1],
        fn doc ->
          Skia.arc(doc,
            x: 0,
            y: 0,
            width: 4,
            height: 4,
            start_degrees: 0,
            sweep_degrees: 180,
            stroke: :green,
            stroke_width: 1
          )
        end
      )

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports inferred blend modes and positioned sweep gradients" do
    document =
      Skia.canvas(4, 4)
      |> Skia.rect(
        x: 0,
        y: 0,
        width: 4,
        height: 4,
        fill:
          Skia.Shader.sweep_gradient({2, 2}, 0, 360, [
            Skia.Shader.stop(:red, 0),
            Skia.Shader.stop(:blue, 1)
          ])
      )
      |> Skia.rect(x: 0, y: 0, width: 2, height: 2, fill: :white, blend_mode: :soft_light)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports gradient local matrices" do
    document =
      Skia.canvas(4, 4)
      |> Skia.rect(
        x: 0,
        y: 0,
        width: 4,
        height: 4,
        fill:
          Skia.Shader.linear_gradient({0, 0}, {4, 0}, [:red, :blue],
            tile: :mirror,
            matrix: Skia.Matrix.translate(1, 0)
          )
      )
      |> Skia.rect(
        x: 0,
        y: 0,
        width: 4,
        height: 4,
        fill:
          Skia.Shader.radial_gradient({2, 2}, 2, [:white, :black],
            tile: :repeat,
            matrix: Skia.Matrix.translate(0, 1)
          ),
        blend_mode: :screen
      )
      |> Skia.rect(
        x: 0,
        y: 0,
        width: 4,
        height: 4,
        fill:
          Skia.Shader.sweep_gradient({2, 2}, 0, 180, [:green, :transparent],
            tile: :clamp,
            matrix: Skia.Matrix.identity()
          ),
        blend_mode: :overlay
      )

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports image shader fills" do
    source =
      Skia.canvas(2, 1)
      |> Skia.rect(x: 0, y: 0, width: 1, height: 1, fill: :red)
      |> Skia.rect(x: 1, y: 0, width: 1, height: 1, fill: :blue)

    assert {:ok, png} = Skia.to_png(source)
    assert {:ok, image} = Skia.Image.decode(png)

    document =
      Skia.canvas(2, 1)
      |> Skia.rect(
        x: 0,
        y: 0,
        width: 2,
        height: 1,
        fill: Skia.Shader.image(image, tile: :clamp, sampling: :nearest)
      )

    assert {:ok, raw} = Skia.to_raw(document)
    assert raw.data == <<255, 0, 0, 255, 0, 0, 255, 255>>
  end

  test "supports conical and color shaders" do
    document =
      Skia.canvas(4, 4)
      |> Skia.rect(
        x: 0,
        y: 0,
        width: 4,
        height: 4,
        fill: Skia.Shader.two_point_conical_gradient({1, 1}, 0.5, {3, 3}, 2, [:red, :blue])
      )
      |> Skia.rect(x: 1, y: 1, width: 2, height: 2, fill: Skia.Shader.color(:green))

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports color filters and image-filter shader leaves" do
    filter =
      Skia.ColorFilter.blend(:blue, :src_in)
      |> Skia.ColorFilter.compose(
        Skia.ColorFilter.matrix([
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0
        ])
      )

    document =
      Skia.canvas(4, 4)
      |> Skia.rect(x: 0, y: 0, width: 4, height: 4, fill: :red, color_filter: filter)
      |> Skia.layer([image_filter: Skia.ImageFilter.shader(Skia.Shader.color(:green))], & &1)
      |> Skia.layer([image_filter: Skia.ImageFilter.color_filter(filter)], & &1)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports rich sampling options" do
    source =
      Skia.canvas(2, 2)
      |> Skia.rect(x: 0, y: 0, width: 1, height: 1, fill: :red)
      |> Skia.rect(x: 1, y: 1, width: 1, height: 1, fill: :blue)

    assert {:ok, png} = Skia.to_png(source)
    assert {:ok, image} = Skia.Image.decode(png)

    document =
      Skia.canvas(4, 4)
      |> Skia.image(image,
        x: 0,
        y: 0,
        width: 4,
        height: 4,
        sampling: Skia.SamplingOptions.mipmap(:linear, :linear)
      )
      |> Skia.rect(
        x: 0,
        y: 0,
        width: 4,
        height: 4,
        fill: Skia.Shader.image(image, sampling: Skia.SamplingOptions.cubic(:catmull_rom))
      )

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports path effects and paint image filters" do
    document =
      Skia.canvas(8, 4)
      |> Skia.line(
        from: {0, 2},
        to: {8, 2},
        stroke: :red,
        stroke_width: 2,
        path_effect: Skia.PathEffect.dash([2, 1])
      )
      |> Skia.rect(
        x: 1,
        y: 1,
        width: 3,
        height: 2,
        fill: :blue,
        image_filter: Skia.ImageFilter.blur(1)
      )

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 128
  end

  test "supports first-class paint values" do
    paint =
      Skia.Paint.new(
        fill: :red,
        image_filter: Skia.ImageFilter.blur(0.5),
        color_filter: Skia.ColorFilter.blend(:blue, :src_in),
        blend_mode: :src_over
      )

    document =
      Skia.canvas(4, 4)
      |> Skia.rect(x: 0, y: 0, width: 4, height: 4, paint: paint)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports advanced image filters" do
    filter =
      Skia.ImageFilter.merge([
        Skia.ImageFilter.magnifier({0, 0, 4, 4}, 1.2, 0.5),
        Skia.ImageFilter.matrix_transform(Skia.Matrix.translate(1, 0)),
        Skia.ImageFilter.tile({0, 0, 2, 2}, {0, 0, 4, 4}),
        Skia.ImageFilter.matrix_convolution({1, 1}, [1.0])
      ])

    document =
      Skia.canvas(4, 4)
      |> Skia.layer([image_filter: filter], fn doc ->
        Skia.rect(doc, x: 0, y: 0, width: 4, height: 4, fill: :red)
      end)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports 1D and 2D path effects" do
    stamp =
      Skia.Path.new()
      |> Skia.Path.move_to(0, 0)
      |> Skia.Path.line_to(1, 1)

    effect =
      Skia.PathEffect.path_1d(stamp, 2, style: :rotate)
      |> Skia.PathEffect.sum(Skia.PathEffect.line_2d(1, Skia.Matrix.scale(2, 2)))
      |> Skia.PathEffect.sum(Skia.PathEffect.path_2d(Skia.Matrix.scale(2, 2), stamp))

    document =
      Skia.canvas(8, 4)
      |> Skia.line(from: {0, 2}, to: {8, 2}, stroke: :red, stroke_width: 1, path_effect: effect)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 128
  end

  test "supports trim and discrete path effects" do
    effect =
      Skia.PathEffect.trim(0.1, 0.9)
      |> Skia.PathEffect.compose(Skia.PathEffect.discrete(2, 0.5, seed: 1))

    path =
      Skia.Path.new()
      |> Skia.Path.move_to(0, 2)
      |> Skia.Path.line_to(8, 2)

    document =
      Skia.canvas(8, 4)
      |> Skia.path(path, stroke: :red, stroke_width: 1, path_effect: effect)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 128
  end

  test "supports composed path effects" do
    effect =
      Skia.PathEffect.corner(1)
      |> Skia.PathEffect.compose(Skia.PathEffect.dash([2, 1], phase: 0))
      |> Skia.PathEffect.sum(Skia.PathEffect.corner(0.5))

    path =
      Skia.Path.new()
      |> Skia.Path.move_to(0, 3)
      |> Skia.Path.line_to(3, 0)
      |> Skia.Path.line_to(6, 3)

    document =
      Skia.canvas(8, 4)
      |> Skia.path(path, stroke: :red, stroke_width: 1, path_effect: effect)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 128
  end

  test "supports arc and rounded-rect path helpers" do
    path =
      Skia.Path.new()
      |> Skia.Path.arc_to({0, 0, 6, 6}, 0, 180, force_move_to: true)
      |> Skia.Path.r_arc_to({2, 2}, 0, false, :cw, {3, 0})
      |> Skia.Path.rrect({1, 1, 4, 3}, {1, 1})

    document =
      Skia.canvas(8, 8)
      |> Skia.path(path, fill: :blue, stroke: :red, stroke_width: 1)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 256
  end

  test "supports conic, relative, and SVG paths" do
    path =
      Skia.Path.new()
      |> Skia.Path.move_to(1, 2)
      |> Skia.Path.r_line_to(2, 0)
      |> Skia.Path.r_conic_to(1, -2, 2, 0, 0.5)
      |> Skia.Path.r_cubic_to(1, 0, 1, 1, 0, 1)

    svg_path = Skia.Path.from_svg("M0 0L3 0L3 3Z")

    assert {:ok, svg} = Skia.Path.to_svg(svg_path)
    assert is_binary(svg)

    document =
      Skia.canvas(4, 4)
      |> Skia.path(path, stroke: :red, stroke_width: 1)
      |> Skia.path(svg_path, fill: :blue)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports compact batches and clip operations" do
    document =
      Skia.canvas(4, 4)
      |> Skia.clip_rect(x: 0, y: 0, width: 2, height: 2, clip_op: :intersect)
      |> Skia.clip_circle(x: 1, y: 1, radius: 1, clip_op: :difference)
      |> Skia.rect(x: 0, y: 0, width: 4, height: 4, fill: :red)

    assert {4, 4, commands} = Skia.Compact.encode(document)
    assert is_binary(Skia.Compact.encode_binary(document))
    assert [{clip_rect_id, [], _}, _, _] = commands
    assert clip_rect_id == Skia.Compact.op_id(:clip_rect)
    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "compares normal compact and picture rendering overhead" do
    document =
      Skia.canvas(8, 8)
      |> Skia.clear(:white)
      |> Skia.rect(x: 1, y: 1, width: 6, height: 6, fill: :red)

    assert {:ok, result} = Skia.Benchmark.compare(document, iterations: 1)
    assert result.iterations == 1
    assert result.normal_batch_bytes > 0
    assert result.compact_batch_bytes > 0
    assert result.normal_render_us >= 0
    assert result.compact_render_us >= 0
    assert result.picture_record_us >= 0
    assert result.picture_replay_us >= 0
  end

  test "renders compact batches through native compact renderer" do
    document =
      Skia.canvas(2, 1)
      |> Skia.clear(:red)

    assert {:ok, raw} = Skia.Compact.to_raw(document)
    assert raw.data == <<255, 0, 0, 255, 255, 0, 0, 255>>
    assert {:ok, png} = Skia.Compact.render(document, format: :png)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _::binary>> = png

    path =
      Skia.Path.new()
      |> Skia.Path.move_to(0, 0)
      |> Skia.Path.quad_to(1, 0, 1, 1)
      |> Skia.Path.conic_to(2, 1, 2, 2, 0.5)
      |> Skia.Path.cubic_to(3, 2, 3, 3, 2, 3)
      |> Skia.Path.r_arc_to({1, 1}, 0, false, :cw, {1, 0})

    assert {:ok, compact_path_raw} =
             Skia.canvas(4, 4)
             |> Skia.path(path, stroke: :red, stroke_width: 1)
             |> Skia.Compact.to_raw()

    assert byte_size(compact_path_raw.data) == 64
  end

  test "lists and matches system fonts" do
    assert {:ok, families} = Skia.Typeface.families()
    assert is_list(families)

    case families do
      [family | _] ->
        assert {:ok, typeface} = Skia.Typeface.match_family(family, weight: 400)
        assert inspect(typeface) =~ "#Skia.Typeface<family="
        assert {:ok, typeface_info} = Skia.Typeface.info(typeface)
        assert typeface_info.weight > 0

        font = Skia.Font.new(typeface, size: 12)
        assert inspect(font) =~ "#Skia.Font<typeface="
        assert {:ok, metrics} = Skia.Font.metrics(font)
        assert metrics.line_spacing >= 0
        assert {:ok, glyph_ids} = Skia.Font.glyph_ids(font, "A")
        assert is_list(glyph_ids)
        assert {:ok, measurement} = Skia.measure_text("A", font: font)
        assert measurement.width >= 0

      [] ->
        assert true
    end
  end

  test "supports render options and preflight validation" do
    document = Skia.canvas(4, 4) |> Skia.rect(x: 0, y: 0, width: 4, height: 4, fill: :red)
    assert {:ok, png} = Skia.render(document, format: :png)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = png
    assert {:ok, %{data: data}} = Skia.render(document, Skia.RenderOptions.new(format: :raw))
    assert byte_size(data) == 64

    invalid =
      Skia.canvas(4, 4) |> Skia.line(from: {0, 0}, to: {4, 4}, stroke: :red, stroke_width: -1)

    assert {:error, :invalid_stroke_width, %{}} = Skia.to_png(invalid)
  end

  test "supports golden hashes for expanded rendering features" do
    fixtures = [
      conical:
        Skia.canvas(8, 8)
        |> Skia.rect(
          x: 0,
          y: 0,
          width: 8,
          height: 8,
          fill: Skia.Shader.two_point_conical_gradient({2, 2}, 0.5, {6, 6}, 4, [:red, :blue])
        ),
      paint:
        Skia.canvas(8, 8)
        |> Skia.rect(
          x: 0,
          y: 0,
          width: 8,
          height: 8,
          paint: Skia.Paint.new(fill: :red, color_filter: Skia.ColorFilter.blend(:blue, :src_in))
        ),
      svg:
        Skia.canvas(8, 8)
        |> Skia.path(Skia.Path.from_svg("M0 0L8 0L8 8Z"), fill: :green),
      spans:
        Skia.canvas(64, 24)
        |> Skia.text("",
          x: 0,
          y: 0,
          paragraph_style: Skia.ParagraphStyle.new(width: 64),
          spans: [
            Skia.TextSpan.new("A", fill: :red, size: 14),
            Skia.TextSpan.new("B", fill: :blue, size: 14)
          ]
        )
    ]

    expected = %{
      conical: "031e470625b7a589e6cbc7dc6ed257ba168fc4ca102ccada064666f78585d979",
      paint: "a2cd62e99d4bd43d248f0f19b5394bbf1da38dc03528bd0cdf99cc2817d12fe4",
      svg: "ad31af7254ede9fba37933385a8b877baafe5c63ac2e67b4784be3907f0ad180",
      spans: "8b0a9b450966731eacd9ed94881dceb1aab53baa5d5ce1dcd3022798b774e7f4"
    }

    for {name, document} <- fixtures do
      assert {:ok, png} = Skia.to_png(document)
      assert Base.encode16(:crypto.hash(:sha256, png), case: :lower) == expected[name]
    end
  end

  test "supports styled text spans" do
    spans = [
      Skia.TextSpan.new("Red ", fill: :red, size: 12),
      Skia.TextSpan.new("Blue", fill: :blue, size: 16)
    ]

    document =
      Skia.canvas(96, 48)
      |> Skia.text("",
        x: 0,
        y: 0,
        paragraph_style: Skia.ParagraphStyle.new(width: 96),
        spans: spans
      )

    assert {:ok, png} = Skia.to_png(document)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = png
  end

  test "supports reusable text and paragraph styles" do
    style = Skia.TextStyle.new(size: 12, fill: :black, font_family: "Arial", line_height: 14)
    paragraph = Skia.ParagraphStyle.new(width: 48, align: :center, direction: :ltr)

    document =
      Skia.canvas(96, 48)
      |> Skia.text("Styled text", x: 0, y: 0, style: style, paragraph_style: paragraph)

    assert {:ok, png} = Skia.to_png(document)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = png
  end

  test "supports path boolean operations" do
    a =
      Skia.Path.new()
      |> Skia.Path.move_to(0, 0)
      |> Skia.Path.line_to(3, 0)
      |> Skia.Path.line_to(3, 3)
      |> Skia.Path.line_to(0, 3)
      |> Skia.Path.close()

    b =
      Skia.Path.new()
      |> Skia.Path.move_to(1, 1)
      |> Skia.Path.line_to(4, 1)
      |> Skia.Path.line_to(4, 4)
      |> Skia.Path.line_to(1, 4)
      |> Skia.Path.close()

    document =
      Skia.canvas(4, 4)
      |> Skia.path_op(a, b, path_op: :intersect, fill: :red)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
  end

  test "supports path outline drawing" do
    path =
      Skia.Path.new()
      |> Skia.Path.move_to(0, 0)
      |> Skia.Path.line_to(4, 0)

    document =
      Skia.canvas(4, 2)
      |> Skia.path_outline(path, outline_width: 1, stroke: :red)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 32
  end

  test "supports paragraph text layout options" do
    document =
      Skia.canvas(96, 48)
      |> Skia.text("Hello wrapped world",
        x: 0,
        y: 0,
        width: 48,
        size: 12,
        align: :center,
        direction: :ltr,
        font_family: "Arial",
        line_height: 14
      )

    assert {:ok, png} = Skia.to_png(document)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = png
  end

  test "matches golden PNG hashes for core renderer features" do
    fixtures = [
      gradient:
        Skia.canvas(8, 8)
        |> Skia.rect(
          x: 0,
          y: 0,
          width: 8,
          height: 8,
          fill:
            Skia.Shader.linear_gradient({0, 0}, {8, 0}, [
              Skia.Shader.stop(:red, 0),
              Skia.Shader.stop(:blue, 1)
            ])
        ),
      blend:
        Skia.canvas(4, 4)
        |> Skia.clear(:blue)
        |> Skia.rect(x: 0, y: 0, width: 4, height: 4, fill: :red, blend_mode: :multiply),
      path:
        (fn ->
           a =
             Skia.Path.new()
             |> Skia.Path.move_to(0, 0)
             |> Skia.Path.line_to(4, 0)
             |> Skia.Path.line_to(4, 4)
             |> Skia.Path.close()

           b =
             Skia.Path.new()
             |> Skia.Path.move_to(2, 0)
             |> Skia.Path.line_to(4, 4)
             |> Skia.Path.line_to(0, 4)
             |> Skia.Path.close()

           Skia.canvas(4, 4) |> Skia.path_op(a, b, path_op: :intersect, fill: :red)
         end).()
    ]

    assert Enum.map(fixtures, fn {name, document} ->
             {:ok, png} = Skia.to_png(document)
             {name, Base.encode16(:crypto.hash(:sha256, png), case: :lower), byte_size(png)}
           end) == [
             {:gradient, "98dc2822a91ef3fc07e391c8cb9b3dc779d15c2fe29b0e3128a1dad6ace8d5d2", 104},
             {:blend, "40bdcc3e40d653dad2eab473b717d3f7af8ed892c2c6a168fe5c5d825ccb2d5a", 94},
             {:path, "7f93fafd0941b69a1afd002fc3b258a3551b57e18b6062eb9b0b034ac877ccdc", 115}
           ]
  end

  test "renders a PNG through the native batch boundary" do
    document =
      Skia.canvas(32, 32)
      |> Skia.clear(:transparent)

    assert {:ok, png} = Skia.to_png(document)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = png
  end

  test "supports path blocks in the DSL" do
    defmodule Shape do
      use Skia.DSL

      def document do
        canvas 200, 200 do
          path fill: :red do
            move_to(10, 10)
            line_to(190, 10)
            line_to(100, 190)
            close()
          end
        end
      end
    end

    [command] = Shape.document() |> Skia.commands()
    [path] = command.args

    assert command.op == :path
    assert command.opts[:fill] == {:rgba, 255, 0, 0, 255}

    assert Skia.Path.segments(path) == [
             {:move_to, 10.0, 10.0},
             {:line_to, 190.0, 10.0},
             {:line_to, 100.0, 190.0},
             :close
           ]
  end
end
