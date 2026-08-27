defmodule KusaDataWeb.AtlasLive do
  use KusaDataWeb, :live_view

  alias KusaData.Atlas
  alias KusaData.Players

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       nav: :atlas,
       view: :map,
       map_data: [],
       graph: nil,
       focal_player_id: nil,
       loading: true,
       error: nil
     )}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case Integer.parse(id) do
      {player_id, ""} ->
        socket =
          socket
          |> assign(
            view: :network,
            focal_player_id: player_id,
            loading: true,
            error: nil
          )
          |> spawn_atlas(player_id)

        {:noreply, socket}

      _ ->
        map_data = Atlas.map_data()

        {:noreply,
         socket
         |> assign(view: :map, map_data: map_data, loading: false, error: nil)
         |> push_event("atlas:data", %{type: "map", regions: map_data})}
    end
  end

  def handle_params(_params, _uri, socket) do
    map_data = Atlas.map_data()

    {:noreply,
     socket
     |> assign(view: :map, map_data: map_data, loading: false, error: nil)
     |> push_event("atlas:data", %{type: "map", regions: map_data})}
  end

  @impl true
  def handle_info({:atlas_loaded, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    socket =
      case result do
        {:ok, map_data, _status} when is_list(map_data) ->
          socket
          |> assign(map_data: map_data, loading: false, error: nil)
          |> push_event("atlas:data", %{type: "map", regions: map_data})

        {:ok, graph, _status} ->
          socket
          |> assign(graph: graph, loading: false, error: nil)
          |> push_event("atlas:data", %{type: "network", graph: graph})

        {:error, _reason} ->
          assign(socket, error: :atlas_unavailable, loading: false)
      end

    {:noreply, assign(socket, load_ref: nil)}
  end

  def handle_info({:atlas_loaded, _ref, _result}, socket), do: {:noreply, socket}

  @impl true
  def handle_event("focus-player", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {player_id, ""} -> {:noreply, push_navigate(socket, ~p"/player/#{player_id}")}
      _ -> {:noreply, socket}
    end
  end

  def handle_event("request-atlas", _params, socket) do
    socket =
      cond do
        socket.assigns.view == :map and socket.assigns.map_data != [] ->
          push_event(socket, "atlas:data", %{type: "map", regions: socket.assigns.map_data})

        socket.assigns.view == :network and not is_nil(socket.assigns.graph) ->
          push_event(socket, "atlas:data", %{type: "network", graph: socket.assigns.graph})

        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("open-region", %{"country" => country, "state" => state}, socket) do
    {:noreply,
     push_navigate(
       socket,
       ~p"/region/#{URI.encode_www_form(country)}/#{URI.encode_www_form(state)}"
     )}
  end

  defp spawn_atlas(socket, player_id) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:atlas_loaded, ref, Players.atlas(player_id, %{})})
    end)

    assign(socket, load_ref: ref)
  end
end
