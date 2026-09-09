defmodule NightStand do
  use GenServer

  alias NightStand.Utils

  @behaviour EgdTextPanel.Renderer

  @default_eink_opts [
    dc_pin: "EPD_DC",
    reset_pin: "EPD_RESET",
    busy_pin: "EPD_BUSY",
    spi_device: "spidev0.0"
  ]

  @default_panel_opts [
    renderer: __MODULE__,
    width: 648,
    height: 480
  ]

  @time_refresh :timer.minutes(1)
  @weather_refresh :timer.minutes(30)

  # Public API functions

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def print(string) do
    GenServer.cast(__MODULE__, {:print, string})
  end

  # GenServer Callback functions

  @impl GenServer
  def init(opts) do
    VintageNet.subscribe(["connection"])

    eink_opts = get_and_merge_defaults(opts, :eink_opts, @default_eink_opts)
    panel_opts = get_and_merge_defaults(opts, :panel_opts, @default_panel_opts)

    # Ensure there are no dangling handlers to GPIO pins
    close_gpios()

    # Create a SPI handler for the EInk display
    {:ok, eink} = EInk.new(EInk.Driver.UC8179, eink_opts)

    # Create an EdgTextPanel to print text to
    render_state = {:renderer_state, %{eink: eink}}
    {:ok, panel} = EgdTextPanel.start_link([render_state | panel_opts])

    state = %{
      eink: eink,
      panel: panel,
      lat: Keyword.fetch!(opts, :lat),
      long: Keyword.fetch!(opts, :long),
      city: Keyword.fetch!(opts, :city),
      state: Keyword.fetch!(opts, :state),
      timezone: Keyword.fetch!(opts, :timezone),
      last_weather_poll: nil,
      internet_access?: VintageNet.get(["connection"]) == :internet
    }

    """
    +-------------------------------------------------------+
    |                                                       |
    |                                                       |
    |                                                       |
    |                                                       |
    |                                                       |
    |                 Waiting for an internet               |
    |                      connection...                    |
    |                                                       |
    |                                                       |
    |                                                       |
    |                                                       |
    |                                                       |
    |                                                       |
    |                                                       |
    |                                                       |
    |                                                       |
    |                                                       |
    +-------------------------------------------------------+
    """
    |> String.trim()
    |> print()

    Process.send_after(self(), :time_refresh, @time_refresh)
    Process.send_after(self(), :weather_refresh, @weather_refresh)

    {:ok, state}
  end

  @impl GenServer
  def handle_continue(:refresh_eink, state) do
    [
      Utils.generate_title_layer(state.city, state.state, state.timezone),
      Utils.generate_stats_layer(state.last_weather_poll),
      Utils.generate_ascii_art_layer(state.last_weather_poll)
    ]
    |> Utils.merge_layers()
    |> print()

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({VintageNet, ["connection"], _old, :internet, _meta}, state) do
    {:ok, weather_stats} = NightStand.OpenMeteoClient.get_forecast(state.lat, state.long)

    state =
      state
      |> Map.put(:last_weather_poll, weather_stats)
      |> Map.put(:internet_access?, true)

    {:noreply, state, {:continue, :refresh_eink}}
  end

  def handle_info({VintageNet, ["connection"], _old, _new, _meta}, state) do
    {:noreply, %{state | internet_access?: false}}
  end

  def handle_info(:time_refresh, %{internet_access?: true} = state) do
    Process.send_after(self(), :time_refresh, @time_refresh)

    {:noreply, state, {:continue, :refresh_eink}}
  end

  def handle_info(:time_refresh, state) do
    Process.send_after(self(), :time_refresh, @time_refresh)

    {:noreply, state}
  end

  def handle_info(:weather_refresh, %{internet_access?: true} = state) do
    {:ok, weather_stats} = NightStand.OpenMeteoClient.get_forecast(state.lat, state.long)
    state = Map.put(state, :last_weather_poll, weather_stats)

    Process.send_after(self(), :weather_refresh, @time_refresh)

    {:noreply, state, {:continue, :refresh_eink}}
  end

  def handle_info(:weather_refresh, state) do
    Process.send_after(self(), :weather_refresh, @weather_refresh)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:print, string}, %{panel: panel} = state) do
    IO.puts(panel, string)

    Process.sleep(500)

    {:noreply, state}
  end

  # EgdTextPanel Callback functions

  @impl EgdTextPanel.Renderer
  def draw_background(_image, state), do: state

  @impl EgdTextPanel.Renderer
  def render_image(image, state) do
    rgb = :egd.render(image, :raw_bitmap)
    data = pack_bits(rgb)
    EInk.draw(state.eink, data, refresh_type: :full)

    state
  end

  # Helper functions

  defp get_and_merge_defaults(full_opts, key, defaults) do
    opts = Keyword.get(full_opts, key, [])
    Keyword.merge(defaults, opts)
  end

  defp close_gpios do
    Enum.each(["EPD_DC", "EPD_RESET", "EPD_BUSY"], fn gpio ->
      Circuits.GPIO.force_close(gpio)
    end)
  end

  defp pack_bits(binary) do
    # Convert 24-bit RGB to 1 bpp. This samples the high bit of the red
    # component. A more sophisticated conversion would convert to gray and
    # dither, but the example source image is black and white anyway.
    for <<b0::1, _::23, b1::1, _::23, b2::1, _::23, b3::1, _::23, b4::1, _::23, b5::1, _::23,
          b6::1, _::23, b7::1, _::23 <- binary>>,
        into: <<>> do
      <<b0::1, b1::1, b2::1, b3::1, b4::1, b5::1, b6::1, b7::1>>
    end
  end
end
