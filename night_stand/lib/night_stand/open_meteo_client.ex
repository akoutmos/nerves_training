defmodule NightStand.OpenMeteoClient do
  @moduledoc """
  This module is used to communicate with [Open-Meteo](https://open-meteo.com/)
  and fetch weather data.

  DISPLAY SIZE:
  57x18
  """

  alias Req.Response

  @base_uri %URI{
    scheme: "https",
    authority: "api.open-meteo.com",
    userinfo: nil,
    host: "api.open-meteo.com",
    port: 443,
    path: "/v1/forecast",
    query: nil,
    fragment: nil
  }

  def get_forecast(lat, long) do
    query_params =
      URI.encode_query(
        latitude: lat,
        longitude: long,
        current:
          Enum.join(
            [
              "temperature_2m",
              "relative_humidity_2m",
              "wind_speed_10m",
              "wind_direction_10m",
              "precipitation",
              "rain",
              "showers",
              "snowfall",
              "weather_code",
              "cloud_cover"
            ],
            ","
          ),
        forecast_days: "1"
      )

    @base_uri
    |> URI.append_query(query_params)
    |> URI.to_string()
    |> Req.get!()
    |> handle_response()
  end

  defp handle_response(%Response{status: 200, body: body}) do
    {:ok, body}
  end

  defp handle_response(%Response{status: status}) do
    {:error, "Received HTTP #{inspect(status)} status code from Open-Meteo"}
  end
end
