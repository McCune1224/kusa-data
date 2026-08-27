defmodule KusaDataWeb.API.TournamentController do
  @moduledoc """
  Serves a CSV export of a tournament's per-event standings.

  A `GET /api/tournament/:slug/export` request returns `text/csv` built from
  the tournament's per-event analytics: one row per standings entry, with the
  computed wins and losses derived from the event's recorded sets.
  """

  use KusaDataWeb, :controller

  alias KusaData.CSV
  alias KusaData.Tournaments

  def export(conn, %{"slug" => slug}) do
    case Tournaments.export(slug) do
      {:ok, %{"events" => events}, _} ->
        csv = build_csv(events)

        conn
        |> put_resp_content_type("text/csv")
        |> put_resp_header("content-disposition", "attachment; filename=\"#{slug}.csv\"")
        |> send_resp(:ok, csv)

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found"})
    end
  end

  defp build_csv(events) do
    columns = ["event", "placement", "player", "wins", "losses"]

    rows =
      events
      |> Enum.flat_map(fn analytics ->
        event_name = analytics["event"]["name"]
        set_stats = build_set_stats(analytics["sets"])

        (analytics["results"] || [])
        |> Enum.sort_by(& &1["placement"])
        |> Enum.map(fn standing ->
          entrant_id = standing["entrant_id"]
          {wins, losses} = Map.get(set_stats, entrant_id, {0, 0})

          [event_name, standing["placement"], standing["name"], wins, losses]
        end)
      end)

    CSV.encode(columns, rows)
  end

  # Derives a per-entrant win/loss tally from the recorded sets. A set counts
  # only when it has two entrants and a known winner, so byes and broken sets
  # are skipped rather than mis-attributed.
  defp build_set_stats(sets) do
    Enum.reduce(sets || [], %{}, fn set, acc ->
      winner_id = set["winner_id"]

      entrants =
        (set["slots"] || [])
        |> Enum.map(& &1["entrant_id"])
        |> Enum.reject(&is_nil/1)

      if length(entrants) >= 2 and not is_nil(winner_id) do
        Enum.reduce(entrants, acc, fn entrant_id, acc ->
          {wins, losses} = Map.get(acc, entrant_id, {0, 0})

          if entrant_id == winner_id do
            Map.put(acc, entrant_id, {wins + 1, losses})
          else
            Map.put(acc, entrant_id, {wins, losses + 1})
          end
        end)
      else
        acc
      end
    end)
  end
end
