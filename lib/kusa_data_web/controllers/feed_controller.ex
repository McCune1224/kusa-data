defmodule KusaDataWeb.FeedController do
  use KusaDataWeb, :controller

  alias KusaData.Tournaments

  def upcoming_json(conn, _params), do: render_json_feed(conn, :upcoming)
  def recent_json(conn, _params), do: render_json_feed(conn, :recent)
  def upcoming_rss(conn, _params), do: render_rss(conn, :upcoming)
  def recent_rss(conn, _params), do: render_rss(conn, :recent)

  defp render_json_feed(conn, mode) do
    feed = feed(mode)
    body = Jason.encode!(feed)
    conditional_send(conn, body, "application/json", etag(body))
  end

  defp render_rss(conn, mode) do
    items = feed_items(mode)

    body =
      [
        ~s(<?xml version="1.0" encoding="UTF-8"?>),
        ~s(<rss version="2.0"><channel><title>KusaData #{mode}</title><link>https://kusa-data.example</link><description>start.gg tournament feed</description>),
        Enum.map_join(items, &rss_item/1),
        "</channel></rss>"
      ]
      |> IO.iodata_to_binary()

    conditional_send(conn, body, "application/rss+xml", etag(body))
  end

  defp feed(mode) do
    %{
      "id" => "kusa-data:#{mode}",
      "mode" => Atom.to_string(mode),
      "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "items" => feed_items(mode)
    }
  end

  defp feed_items(:upcoming) do
    case Tournaments.browse(%{mode: :upcoming, page: 1, games: :all}) do
      {:ok, result, _} -> Enum.map(result["tournaments"] || [], &normalize_item/1)
      _ -> []
    end
  end

  defp feed_items(:recent) do
    case Tournaments.browse(%{mode: :past, page: 1, games: :all, results_only: true}) do
      {:ok, result, _} -> Enum.map(result["tournaments"] || [], &normalize_item/1)
      _ -> []
    end
  end

  defp normalize_item(tournament) do
    %{
      "id" => to_string(tournament["id"] || tournament["slug"]),
      "slug" => tournament["slug"],
      "name" => tournament["name"],
      "url" => "https://kusa-data.example/tournament/#{tournament["slug"]}",
      "start_at" => iso_timestamp(tournament["startAt"]),
      "end_at" => iso_timestamp(tournament["endAt"]),
      "city" => tournament["city"],
      "country_code" => tournament["countryCode"]
    }
  end

  defp rss_item(item) do
    [
      "<item><guid isPermaLink=\"false\">",
      xml(item["id"]),
      "</guid><title>",
      xml(item["name"]),
      "</title><link>",
      xml(item["url"]),
      "</link><pubDate>",
      xml(item["start_at"] || item["end_at"] || ""),
      "</pubDate><description>",
      xml(Enum.reject([item["city"], item["country_code"]], &is_nil/1) |> Enum.join(", ")),
      "</description></item>"
    ]
  end

  defp conditional_send(conn, body, content_type, etag) do
    if get_req_header(conn, "if-none-match") == [etag] do
      conn
      |> put_resp_header("etag", etag)
      |> send_resp(304, "")
    else
      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("etag", etag)
      |> send_resp(200, body)
    end
  end

  defp etag(body), do: "\"#{:crypto.hash(:sha256, body) |> Base.encode16(case: :lower)}\""
  defp iso_timestamp(nil), do: nil

  defp iso_timestamp(value) when is_integer(value),
    do: DateTime.from_unix!(value) |> DateTime.to_iso8601()

  defp iso_timestamp(value) when is_binary(value), do: value
  defp iso_timestamp(_), do: nil
  defp xml(nil), do: ""
  defp xml(value), do: value |> to_string() |> Plug.HTML.html_escape()
end
