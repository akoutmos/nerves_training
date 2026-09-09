defmodule LivebookRenderer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    :ok = EventPubSub.subscribe([:clear, :movement])

    state = %{
      cursor_position: Keyword.fetch!(opts, :starting_point),
      previous_positions: [],
      frame: Keyword.fetch!(opts, :frame)
    }

    render(state)

    {:ok, state}
  end

  @impl GenServer
  def handle_info({:movement, attrs}, state) do
    {previous_x, previous_y} = state.cursor_position

    new_cursor_position =
      case attrs.axis do
        :x -> {attrs.position, previous_y}
        :y -> {previous_x, attrs.position}
      end

    updated_state =
      state
      |> Map.put(:cursor_position, new_cursor_position)
      |> Map.update!(:previous_positions, fn previous_positions ->
        [{previous_x, previous_y} | previous_positions]
      end)

    render(updated_state)

    {:noreply, updated_state}
  end

  def handle_info({:clear, _opts}, state) do
    updated_state = Map.put(state, :previous_positions, [])
    render(updated_state)

    {:noreply, updated_state}
  end

  defp render(state) do
    formatted_points =
      state.previous_positions
      |> List.insert_at(0, state.cursor_position)
      |> Enum.map_join(" ", fn {x, y} ->
        "#{x},#{y}"
      end)

    svg =
      """
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="888"
        height="720"
        viewBox="0 0 888 720"
      >
        <g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
          <g>
            <rect
              fill="#940B22"
              x="0" y="0"
              width="888" height="720"
              rx="32"
            />

            <g transform="translate(120, 120)">
              <rect fill="#C8D4C8" width="648" height="480"></rect>

              <polyline
                fill="none"
                stroke="black"
                stroke-width="2"
                points="#{formatted_points}"
              />
            </g>

            <text font-size="64" font-weight="normal" fill="#DADADA">
              <tspan x="260" y="76">Etch A Sketch</tspan>
            </text>

            <g
              transform="
                translate(120, 624)
                rotate(#{calc_rotation(state.cursor_position, :x)}, 36, 36)
              "
            >
              <circle
                stroke="#979797" fill="#DADADA"
                cx="36" cy="36"
                r="36"
              />
              <circle fill="#505050" cx="36" cy="12" r="6" />
            </g>

            <g
              transform="
                translate(696, 624)
                rotate(#{calc_rotation(state.cursor_position, :y)}, 36, 36)
              "
            >
              <circle
                stroke="#979797" fill="#DADADA"
                cx="36" cy="36"
                r="36"
              />
              <circle fill="#505050" cx="36" cy="12" r="6" />
            </g>
          </g>
        </g>
      </svg>
      """
      |> Kino.Image.new(:svg)

    Kino.Frame.render(state.frame, svg)
  end

  defp calc_rotation({x_axis, y_axis}, axis) do
    case axis do
      :x -> -135 + x_axis / 648 * 270
      :y -> -135 + y_axis / 480 * 270
    end
  end
end
