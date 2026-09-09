defmodule NightStand.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    fonts_path =
      :egd
      |> :code.priv_dir()
      |> Path.join("fonts")

    children =
      [
        {NightStand,
         lat: 29.97783,
         long: -95.57377,
         city: "Houston",
         state: "Texas",
         timezone: "America/Chicago",
         panel_opts: [
           font_path: "#{fonts_path}/Terminus22.wingsfont",
           margins: {10, 10, 10, 10}
         ]}
      ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NightStand.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
