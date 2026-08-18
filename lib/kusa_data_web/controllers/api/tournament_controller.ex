defmodule KusaDataWeb.API.TournamentController do
  @moduledoc """
  Full tournament export (JSON or CSV) reusing the UI contexts and cache keys.

  JSON returns the normalized `%{tournament, events}` map from
  `KusaData.Tournaments.export/1`. CSV flattens every event's entrant rows
  into one deterministic table.
  """

  use KusaDataWeb, :controller

  alias KusaData.Tournaments
  alias KusaDataWeb.API.Export

  @export_columns ~w(event_id event_name tournament_name entrant_id entrant_name player_id seed placement seed_delta upset reason wins losses sets_played games_won games_lost)

  def export(conn, %{"slug" => slug}) do
    case Tournaments.export(slug) do
      {:ok, %{"events" => events} = data, _} ->
        case format(conn) do
          "csv" ->
            Export.csv(conn, @export_columns, flatten_events(events))

          "json" ->
            Export.json(conn, data)

          nil ->
            Export.json(conn, data)

          _ ->
            Export.error(conn, 422, "invalid export format (use ?format=json or ?format=csv)")
        end

      {:error, :not_found} ->
        Export.error(conn, 404, "unknown tournament")

      {:error, _reason} ->
        Export.error(conn, 422, "tournament data unavailable right now")
    end
  end

  defp flatten_events(events) do
    Enum.flat_map(events, fn analytics ->
      analysis = analytics["analysis"]
      recap = analysis["context"]

      Enum.map(analysis["entrants"], fn entrant ->
        entrant
        |> Map.put("entrant_name", entrant["name"])
        |> Map.put("event_id", recap["event_id"])
        |> Map.put("event_name", recap["event_name"])
        |> Map.put("tournament_name", recap["tournament_name"])
      end)
    end)
  end

  defp format(conn), do: conn.query_params["format"]
end
