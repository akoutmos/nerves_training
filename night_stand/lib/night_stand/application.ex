defmodule NightStand.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {NightStand,
         lat: 29.97783,
         long: -95.57377,
         city: "Houston",
         state: "Texas",
         timezone: "America/Chicago",
         panel_opts: [
           font_path: "/root/livebook/elixir_conf_2026/files/Terminus22.wingsfont",
           margins: {10, 10, 10, 10}
         ]}
      ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NightStand.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
