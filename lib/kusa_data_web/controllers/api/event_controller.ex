defmodule KusaDataWeb.API.EventController do
  @moduledoc """
  Read-only JSON/CSV export of event bracket data.

  All endpoints reuse the same contexts and cache keys as the UI
  (`KusaData.Events`), so exports never re-fetch what the browser already
  warmed. Identifiers accept a numeric event id or a full
  `tournament/slug/event/slug` path.
  """

  use KusaDataWeb, :controller

  alias KusaData.Events
  alias KusaDataWeb.API.Export

  @seeds_columns ~w(entrant_id name player_id seed)
  @results_columns ~w(entrant_id name player_id placement)
  @sets_columns ~w(id round display_score winner_id completed_at entrant_1_id entrant_1_name entrant_2_id entrant_2_name)
  @standings_columns ~w(entrant_id name player_id seed placement seed_delta upset reason wins losses sets_played games_won games_lost)

  def seeds(conn, %{"event" => identifier}) do
    with_event(conn, identifier, fn event_id ->
      case Events.seeding(event_id) do
        {:ok, rows, _} ->
          rows =
            Enum.map(
              rows,
              &(Map.take(&1, ["id", "name", "player_id", "seed"])
                |> Map.put("entrant_id", &1["id"]))
            )

          Export.render(conn, format(conn), @seeds_columns, rows)

        {:error, :not_found} ->
          Export.error(conn, 404, "unknown event")

        {:error, _reason} ->
          Export.error(conn, 422, "event data unavailable right now")
      end
    end)
  end

  def results(conn, %{"event" => identifier}) do
    with_event(conn, identifier, fn event_id ->
      case Events.results(event_id) do
        {:ok, rows, _} ->
          rows =
            Enum.map(
              rows,
              &(Map.take(&1, ["name", "player_id", "placement"])
                |> Map.put("entrant_id", &1["entrant_id"]))
            )

          Export.render(conn, format(conn), @results_columns, rows)

        {:error, :not_found} ->
          Export.error(conn, 404, "unknown event")

        {:error, _reason} ->
          Export.error(conn, 422, "event data unavailable right now")
      end
    end)
  end

  def sets(conn, %{"event" => identifier}) do
    with_event(conn, identifier, fn event_id ->
      case Events.sets(event_id) do
        {:ok, rows, _} ->
          Export.render(conn, format(conn), @sets_columns, Enum.map(rows, &flatten_set/1))

        {:error, :not_found} ->
          Export.error(conn, 404, "unknown event")

        {:error, _reason} ->
          Export.error(conn, 422, "event data unavailable right now")
      end
    end)
  end

  def analytics(conn, %{"event" => identifier}) do
    with_event(conn, identifier, fn event_id ->
      case Events.analytics(event_id) do
        {:ok, data, _} ->
          Export.render(conn, format(conn), @standings_columns, data["analysis"]["entrants"])

        {:error, :not_found} ->
          Export.error(conn, 404, "unknown event")

        {:error, _reason} ->
          Export.error(conn, 422, "event data unavailable right now")
      end
    end)
  end

  defp with_event(conn, identifier, fun) do
    case resolve_event_id(identifier) do
      {:ok, event_id} -> fun.(event_id)
      {:error, :not_found} -> Export.error(conn, 404, "unknown event")
      {:error, _reason} -> Export.error(conn, 422, "event data unavailable right now")
    end
  end

  defp resolve_event_id(identifier) do
    case Integer.parse(identifier) do
      {id, ""} ->
        {:ok, id}

      _ ->
        case Events.get(identifier) do
          {:ok, event, _} -> {:ok, event["id"]}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp flatten_set(set) do
    [first, second] = pad_slots(set["slots"])

    %{
      "id" => set["id"],
      "round" => set["round"],
      "display_score" => set["display_score"],
      "winner_id" => set["winner_id"],
      "completed_at" => set["completed_at"],
      "entrant_1_id" => first["entrant_id"],
      "entrant_1_name" => first["name"],
      "entrant_2_id" => second["entrant_id"],
      "entrant_2_name" => second["name"]
    }
  end

  defp pad_slots(slots) do
    slots = slots || []

    case slots do
      [a, b] -> [a, b]
      [a] -> [a, %{"entrant_id" => nil, "name" => nil}]
      [] -> [%{"entrant_id" => nil, "name" => nil}, %{"entrant_id" => nil, "name" => nil}]
    end
  end

  defp format(conn) do
    conn.query_params["format"]
  end
end
