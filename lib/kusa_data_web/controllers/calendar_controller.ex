defmodule KusaDataWeb.CalendarController do
  use KusaDataWeb, :controller

  alias KusaData.Tournaments

  def show(conn, %{"slug" => slug}) do
    case Tournaments.by_slug(slug) do
      {:ok, tournament, _} ->
        conn
        |> put_resp_content_type("text/calendar")
        |> put_resp_header(
          "content-disposition",
          "attachment; filename=\"#{safe_filename(tournament["slug"] || slug)}.ics\""
        )
        |> send_resp(200, ics(tournament))

      {:error, :not_found} ->
        send_resp(conn, 404, "Tournament not found")

      {:error, _reason} ->
        send_resp(conn, 404, "Tournament not found")
    end
  end

  defp ics(tournament) do
    uid = "tournament-#{tournament["id"] || tournament["slug"]}@kusa-data"
    start_at = timestamp(tournament["startAt"])
    end_at = timestamp(tournament["endAt"] || tournament["startAt"])
    url = "https://www.start.gg/#{tournament["slug"]}"

    location =
      [
        tournament["venueName"],
        tournament["city"],
        tournament["addrState"],
        tournament["countryCode"]
      ]
      |> Enum.reject(&is_nil_or_blank/1)
      |> Enum.join(", ")

    [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//KusaData//Tournament Calendar//EN",
      "CALSCALE:GREGORIAN",
      "BEGIN:VEVENT",
      "UID:" <> escape(uid),
      "DTSTAMP:" <> timestamp(DateTime.utc_now()),
      if(start_at, do: "DTSTART:" <> start_at, else: nil),
      if(end_at, do: "DTEND:" <> end_at, else: nil),
      "SUMMARY:" <> escape(tournament["name"] || "Tournament"),
      if(location != "", do: "LOCATION:" <> escape(location), else: nil),
      "URL:" <> escape(url),
      "END:VEVENT",
      "END:VCALENDAR"
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\r\n")
    |> Kernel.<>("\r\n")
  end

  defp timestamp(nil), do: nil
  defp timestamp(value) when is_integer(value), do: value |> DateTime.from_unix!() |> timestamp()
  defp timestamp(%DateTime{} = value), do: Calendar.strftime(value, "%Y%m%dT%H%M%SZ")

  defp timestamp(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> timestamp(dt)
      _ -> nil
    end
  end

  defp timestamp(_), do: nil

  defp escape(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace(";", "\\;")
    |> String.replace(",", "\\,")
    |> String.replace("\r\n", "\\n")
    |> String.replace("\n", "\\n")
  end

  defp is_nil_or_blank(nil), do: true
  defp is_nil_or_blank(value), do: String.trim(to_string(value)) == ""

  defp safe_filename(value),
    do: value |> to_string() |> String.replace(~r/[^a-zA-Z0-9_-]+/, "-") |> String.trim("-")
end
