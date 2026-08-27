defmodule KusaDataWeb.FeedController do
  @moduledoc """
  JSON and RSS 2.0 feeds for tournament browsing.

  `GET /feed/upcoming.json` and `GET /feed/recent.json` return the raw
  tournament list, while `GET /feed/upcoming.rss` and `GET /feed/recent.rss`
  render the same data as an RSS 2.0 channel for feed readers.
  """

  use KusaDataWeb, :controller

  alias KusaData.Tournaments
  alias KusaDataWeb.Format

  def upcoming_json(conn, _params) do
    tournaments = safe_tournaments(Tournaments.browse(%{mode: :upcoming}))
    json(conn, %{tournaments: tournaments})
  end

  def recent_json(conn, _params) do
    tournaments = safe_tournaments(Tournaments.browse(%{mode: :past, results_only: true}))
    json(conn, %{tournaments: tournaments})
  end

  def upcoming_rss(conn, _params) do
    tournaments = safe_tournaments(Tournaments.browse(%{mode: :upcoming}))
    xml = render_rss("KusaData — Upcoming Melee Tournaments", tournaments)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(:ok, xml)
  end

  def recent_rss(conn, _params) do
    tournaments = safe_tournaments(Tournaments.browse(%{mode: :past, results_only: true}))
    xml = render_rss("KusaData — Recent Melee Results", tournaments)

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(:ok, xml)
  end

  defp safe_tournaments({:ok, %{"tournaments" => tournaments}, _}), do: tournaments
  defp safe_tournaments(_), do: []

  defp render_rss(title, tournaments) do
    items =
      tournaments
      |> Enum.map(&rss_item/1)
      |> Enum.join("\n")

    link = to_string(~p"/")

    ~s|<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>#{xml_escape(title)}</title>
    <link>#{xml_escape(link)}</link>
    <description>#{xml_escape(title)}</description>
#{items}
  </channel>
</rss>
|
  end

  defp rss_item(tournament) do
    slug = Format.bare_slug(tournament["slug"])
    title = xml_escape(tournament["name"] || "")
    link = xml_escape(to_string(~p"/tournament/#{slug}"))
    pub_date = rss_date(tournament["startAt"])

    ~s|    <item>
      <title>#{title}</title>
      <link>#{link}</link>
      <pubDate>#{pub_date}</pubDate>
    </item>|
  end

  defp rss_date(nil), do: ""

  defp rss_date(unix) when is_integer(unix) do
    case DateTime.from_unix(unix) do
      {:ok, datetime} -> Calendar.strftime(datetime, "%a, %d %b %Y %H:%M:%S GMT")
      _ -> ""
    end
  end

  defp xml_escape(nil), do: ""

  defp xml_escape(value) when is_binary(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
