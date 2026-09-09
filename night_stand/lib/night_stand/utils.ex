defmodule NightStand.Utils do
  @moduledoc """
  Small little utility functions to drive this EInk display.
  """

  @desired_width 57
  @desired_height 19

  @blank_layer 1..@desired_height
               |> Enum.map(fn _ ->
                 " "
                 |> String.duplicate(@desired_width)
                 |> String.split("")
               end)

  alias NightStand.WeatherCode

  @doc """
  Given a list of layers, merge them together.
  """
  def merge_layers(layers) do
    layers
    |> Enum.reduce(@blank_layer, fn layer, acc ->
      layer = String.split(layer, "\n")

      Enum.zip_with(acc, layer, fn acc_row, layer_row ->
        layer_row = String.split(layer_row, "")

        Enum.zip_with(acc_row, layer_row, fn
          " ", layer_char -> layer_char
          acc_char, _layer_char -> acc_char
        end)
      end)
    end)
    |> Enum.join("\n")
  end

  @doc """
  Given the city and state, create the title bar along with the
  time and date.
  """
  def generate_title_layer(city, state, timezone) do
    date_time =
      timezone
      |> DateTime.now!()
      |> Calendar.strftime("%-I:%M%P %-m/%-d/%Y")

    title = "#{city} #{state} Weather"

    String.trim("""
    +-------------------------------------------------------+
    |#{format_string(title, :center, 55)}|
    |#{format_string(date_time, :center, 55)}|
    +----------------------------+--------------------------+
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    |                            |                          |
    +----------------------------+--------------------------+
    """)
  end

  @doc """
  Given the city and state, create the title bar along with the
  time and date.
  """
  def generate_stats_layer(weather_stats) do
    temp = "Temperature: #{generate_stat(weather_stats, "temperature_2m")}"
    cloud_cov = "Cloud coverage: #{generate_stat(weather_stats, "cloud_cover")}"
    precip = "Precipitation: #{generate_stat(weather_stats, "precipitation")}"
    wind_speed = "Wind speed: #{generate_stat(weather_stats, "wind_speed_10m")}"
    wind_dir = "Wind direction: #{generate_stat(weather_stats, "wind_direction_10m")}"
    humidity = "Humidity: #{generate_stat(weather_stats, "relative_humidity_2m")}"

    String.trim("""
    +-------------------------------------------------------+
    |                                                       |
    |                                                       |
    +----------------------------+--------------------------+
    |                            |                          |
    |                            | #{format_string(temp, :left, 26)} |
    |                            |                          |
    |                            | #{format_string(cloud_cov, :left, 26)} |
    |                            |                          |
    |                            | #{format_string(precip, :left, 26)} |
    |                            |                          |
    |                            | #{format_string(wind_speed, :left, 26)} |
    |                            |                          |
    |                            | #{format_string(wind_dir, :left, 26)} |
    |                            |                          |
    |                            | #{format_string(humidity, :left, 26)} |
    |                            |                          |
    |                            |                          |
    +----------------------------+--------------------------+
    """)
  end

  defp generate_stat(%{"current" => values, "current_units" => units}, field) do
    "#{Map.fetch!(values, field)}#{Map.fetch!(units, field)}"
  end

  @doc """
  Given a weather code, generate the ascii art layer.
  """
  def generate_ascii_art_layer(%{"current" => %{"weather_code" => weather_code}}) do
    weather_code
    |> WeatherCode.to_ascii()
    |> String.trim()
  end

  def format_string(string, alignment, width) do
    string = String.slice(string, 0, width)
    available_white_space = width - String.length(string)

    half_white_space = div(available_white_space, 2)
    remainder_white_space = rem(available_white_space, 2)

    {left_pad, right_pad} =
      case alignment do
        :left -> {0, available_white_space}
        :center -> {half_white_space, half_white_space + remainder_white_space}
        :right -> {available_white_space, 0}
      end

    "#{String.duplicate(" ", left_pad)}#{string}#{String.duplicate(" ", right_pad)}"
  end
end
