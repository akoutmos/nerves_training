defmodule PngToMono do
  import Bitwise

  @threshold 128

  @doc """
  Convert a PNG to a packed 1bpp buffer sized exactly for the panel.

  Output is 1 = white, 0 = black, MSB = leftmost pixel.
  """
  def from_png(png, {cw, ch} = _canvas) when rem(cw, 8) == 0 do
    img = StbImage.read_binary!(png)
    {ih, iw, channels} = img.shape

    scale = min(cw / iw, ch / ih)
    w = iw |> Kernel.*(scale) |> round() |> clamp(1, cw)
    h = ih |> Kernel.*(scale) |> round() |> clamp(1, ch)

    img
    |> StbImage.resize(h, w)
    |> Map.fetch!(:data)
    |> to_gray(channels)
    |> center_on_white(w, h, cw, ch)
    |> pack(<<>>)
  end

  defp clamp(v, lo, hi), do: v |> max(lo) |> min(hi)

  # --- greyscale in one pass, specialised on channel count ---

  defp to_gray(data, 1), do: data

  defp to_gray(data, 2),
    do: for(<<v, a <- data>>, into: <<>>, do: <<over_white(v, a)>>)

  defp to_gray(data, 3),
    do: for(<<r, g, b <- data>>, into: <<>>, do: <<luma(r, g, b)>>)

  defp to_gray(data, 4),
    do: for(<<r, g, b, a <- data>>, into: <<>>, do: <<over_white(luma(r, g, b), a)>>)

  # Rec.601 in 8.8 fixed point: 77 + 151 + 28 == 256
  defp luma(r, g, b), do: (r * 77 + g * 151 + b * 28) >>> 8

  defp over_white(v, 255), do: v
  defp over_white(v, a), do: (v * a + 255 * (255 - a) + 128) >>> 8

  # --- centre on a white canvas of exactly cw x ch ---

  defp center_on_white(gray, w, h, cw, ch) do
    left = div(cw - w, 2)
    top = div(ch - h, 2)

    lpad = :binary.copy(<<255>>, left)
    rpad = :binary.copy(<<255>>, cw - w - left)
    blank = :binary.copy(<<255>>, cw)

    body =
      for <<row::binary-size(^w) <- gray>>, into: <<>> do
        <<lpad::binary, row::binary, rpad::binary>>
      end

    :binary.copy(blank, top) <> body <> :binary.copy(blank, ch - h - top)
  end

  # --- 8 pixels -> 1 byte, MSB = leftmost ---

  defp pack(<<>>, acc), do: acc

  defp pack(<<a, b, c, d, e, f, g, h, rest::binary>>, acc) do
    byte =
      <<bit(a)::1, bit(b)::1, bit(c)::1, bit(d)::1, bit(e)::1, bit(f)::1, bit(g)::1, bit(h)::1>>

    pack(rest, <<acc::binary, byte::binary>>)
  end

  defp bit(v) when v >= @threshold, do: 1
  defp bit(_), do: 0
end
