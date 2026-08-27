defmodule KusaDataWeb.CalendarController do
  @moduledoc """
  Serves an iCalendar (.ics) export of a tournament's events.

  A `GET /calendar/:slug` request returns a `text/calendar` response built
  from the tournament's events, one `VEVENT` per event.
  """

  use KusaDataWeb, :controller

  alias KusaData.Tournaments

  def show(conn, %{"slug" => slug}) do
    case Tournaments.by_slug(slug) do
      {:ok, tournament, _} ->
        ics = build_ics(tournament, slug)

        conn
        |> put_resp_content_type("text/calendar; charset=utf-8")
        |> put_resp_header("content-disposition", "inline; filename=\"#{slug}.ics\"")
        |> send_resp(:ok, ics)

      {:error, _} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "not_found"})
    end
  end

  defp build_ics(tournament, slug) do
    vevents =
      (tournament["events"] || [])
      |> Enum.with_index()
      |> Enum.map(fn {event, index} -> build_vevent(event, slug, index) end)
      |> Enum.reject(&is_nil/1)
      |> List.flatten()

    header = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//KusaData//Tournament Calendar//EN",
      "CALSCALE:GREGORIAN"
    ]

    all_lines = Kernel.++(header, vevents)
    all_lines = Kernel.++(all_lines, ["END:VCALENDAR"])

    Enum.join(all_lines, "\r\n")
  end

  defp build_vevent(event, slug, index) do
    start_at = event["startAt"]
    end_at = event["endAt"]

    if is_integer(start_at) and is_integer(end_at) do
      name = event["name"] || ""

      [
        "BEGIN:VEVENT",
        "UID:#{slug}-#{index}@kusadata",
        "SUMMARY:#{escape_text(name)}",
        "DTSTART:#{format_utc(start_at)}",
        "DTEND:#{format_utc(end_at)}",
        "END:VEVENT"
      ]
    else
      nil
    end
  end

  defp format_utc(unix) do
    unix
    |> DateTime.from_unix!()
    |> DateTime.to_iso8601()
    |> String.replace(["-", ":"], "")
  end

  # Escape reserved characters per RFC 5545 text value rules.
  defp escape_text(text) when is_binary(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace("\n", "\\n")
    |> String.replace(",", "\\,")
    |> String.replace(";", "\\;")
  end
end
