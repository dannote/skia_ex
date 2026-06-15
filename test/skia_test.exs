defmodule SkiaTest do
  use ExUnit.Case

  test "inspects core data structures compactly" do
    document =
      Skia.canvas(800, 600)
      |> Skia.background(:white)

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
      |> Skia.background(:white)
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
          background(:black)

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
      |> Skia.background(:red)

    assert {:ok, raw} = Skia.to_raw(document)
    assert raw.width == 2
    assert raw.height == 1
    assert raw.stride == 8
    assert raw.data == <<255, 0, 0, 255, 255, 0, 0, 255>>
  end

  test "measures text through the native text engine" do
    assert {:ok, measurement} = Skia.measure_text("Hello", size: 18)
    assert measurement.width > 0
    assert {left, top, right, bottom} = measurement.bounds
    assert right >= left
    assert bottom >= top
  end

  test "renders gradient paints through the native batch boundary" do
    document =
      Skia.canvas(8, 1)
      |> Skia.rect(
        x: 0,
        y: 0,
        width: 8,
        height: 1,
        fill: Skia.linear_gradient({0, 0}, {8, 0}, [:red, :blue])
      )

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 32
  end

  test "renders JPEG through the native batch boundary" do
    document =
      Skia.canvas(2, 2)
      |> Skia.background(:white)

    assert {:ok, jpeg} = Skia.to_jpeg(document)
    assert <<255, 216, 255, _rest::binary>> = jpeg
  end

  test "encodes debuggable command batches" do
    batch =
      Skia.canvas(8, 8)
      |> Skia.background(:white)
      |> Skia.to_binary_batch()
      |> :erlang.binary_to_term()

    assert %{width: 8, height: 8, commands: [%Skia.Command{op: :clear}]} = batch
  end

  test "renders layers through the native batch boundary" do
    document =
      Skia.canvas(2, 1)
      |> Skia.background(:transparent)
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
      |> Skia.background(:white)
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
      |> Skia.background(:blue)

    assert {:ok, png} = Skia.to_png(source)
    assert {:ok, image} = Skia.Image.decode(png)
    assert Skia.Image.width(image) == 4
    assert Skia.Image.height(image) == 4
    assert inspect(image) == "#Skia.Image<4x4>"

    document =
      Skia.canvas(8, 8)
      |> Skia.background(:white)
      |> Skia.image(image, x: 2, y: 2, width: 4, height: 4)

    assert {:ok, rendered} = Skia.to_png(document)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = rendered
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
      |> Skia.background(:blue)
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
          Skia.sweep_gradient({2, 2}, 0, 360, [
            Skia.gradient_stop(:red, 0),
            Skia.gradient_stop(:blue, 1)
          ])
      )
      |> Skia.rect(x: 0, y: 0, width: 2, height: 2, fill: :white, blend_mode: :soft_light)

    assert {:ok, raw} = Skia.to_raw(document)
    assert byte_size(raw.data) == 64
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

  test "supports paragraph text layout options" do
    document =
      Skia.canvas(96, 48)
      |> Skia.text("Hello wrapped world",
        x: 0,
        y: 0,
        width: 48,
        size: 12,
        align: :center,
        direction: :ltr
      )

    assert {:ok, png} = Skia.to_png(document)
    assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = png
  end

  test "renders a PNG through the native batch boundary" do
    document =
      Skia.canvas(32, 32)
      |> Skia.background(:transparent)

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
