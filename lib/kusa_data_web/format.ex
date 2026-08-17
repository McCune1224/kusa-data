defmodule KusaDataWeb.Format do
  @moduledoc """
  Presentation helpers for dates and numbers used across LiveViews.
  """

  @doc "Formats a unix timestamp as `Aug 14, 2026` in the given timezone."
  def date(unix, timezone \\ "UTC")
  def date(nil, _timezone), do: "—"

  def date(unix, timezone) when is_integer(unix) do
    with {:ok, datetime} <- DateTime.from_unix(unix) do
      case DateTime.shift_zone(datetime, timezone) do
        {:ok, shifted} -> Calendar.strftime(shifted, "%b %d, %Y")
        _ -> Calendar.strftime(datetime, "%b %d, %Y")
      end
    else
      _ -> "—"
    end
  end

  @doc "Formats a unix timestamp as a short weekday/date, e.g. `Sat Aug 16`."
  def short_date(unix, timezone \\ "UTC")
  def short_date(nil, _timezone), do: "—"

  def short_date(unix, timezone) when is_integer(unix) do
    with {:ok, datetime} <- DateTime.from_unix(unix) do
      case DateTime.shift_zone(datetime, timezone) do
        {:ok, shifted} -> Calendar.strftime(shifted, "%a %b %d")
        _ -> Calendar.strftime(datetime, "%a %b %d")
      end
    else
      _ -> "—"
    end
  end

  @doc "How far away a unix timestamp is, as a short relative string."
  def relative_time(nil), do: "—"

  def relative_time(unix) when is_integer(unix) do
    diff = unix - System.os_time(:second)

    if diff < 0, do: "ended #{magnitude(-diff)}", else: "in #{magnitude(diff)}"
  end

  defp magnitude(seconds) do
    cond do
      seconds < 60 -> "less than a minute"
      seconds < 3600 -> "#{div(seconds, 60)}m"
      seconds < 86_400 -> "#{div(seconds, 3600)}h"
      seconds < 604_800 -> "#{div(seconds, 86_400)}d"
      true -> "#{div(seconds, 604_800)}w"
    end
  end

  @doc "Renders a percent like `62.5`."
  def percent(value) when is_number(value), do: "#{value}%"
  def percent(_), do: "—"

  @doc """
  Strips the `tournament/` prefix start.gg prepends to slugs, so they can be
  used cleanly in URLs like `/tournament/templee-38`.
  """
  def bare_slug("tournament/" <> rest), do: rest
  def bare_slug(slug), do: slug
end
