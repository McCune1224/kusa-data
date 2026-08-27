defmodule KusaData.Atlas do
  @moduledoc """
  Static geographic scaffolding for the Atlas map and shared graph helpers.

  The Melee scene is organized around regions, not precise venues, so the map
  is a stylized set of region bubbles positioned by a static centroid table
  rather than a cartographic tile layer. Coordinates are approximate state
  centroids and exist only to place bubbles; they are never shown as literal
  latitude/longitude to the user.

  Atlas now renders as a blocky ranked grid + table primary view. The centroid
  table is retained for minimap and legacy fallback, but the hot path no longer
  blocks the LiveView with 12 serial GraphQL fetches.
  """

  alias KusaData.Tournaments

  @centroids %{
    "US-AL" => {32.8, -86.8},
    "US-AK" => {64.2, -149.5},
    "US-AZ" => {34.2, -111.7},
    "US-AR" => {34.8, -92.4},
    "US-CA" => {36.7, -119.4},
    "US-CO" => {39.0, -105.5},
    "US-CT" => {41.6, -72.7},
    "US-DE" => {39.0, -75.5},
    "US-FL" => {27.8, -81.7},
    "US-GA" => {32.6, -83.6},
    "US-HI" => {21.3, -157.8},
    "US-ID" => {44.4, -114.6},
    "US-IL" => {40.0, -89.7},
    "US-IN" => {39.9, -86.6},
    "US-IA" => {42.0, -93.5},
    "US-KS" => {38.5, -98.4},
    "US-KY" => {37.8, -85.3},
    "US-LA" => {31.0, -91.8},
    "US-ME" => {45.4, -69.2},
    "US-MD" => {39.0, -76.7},
    "US-MA" => {42.2, -71.5},
    "US-MI" => {43.3, -84.6},
    "US-MN" => {46.4, -94.7},
    "US-MS" => {32.7, -89.7},
    "US-MO" => {38.5, -92.4},
    "US-MT" => {46.9, -110.4},
    "US-NE" => {41.5, -99.8},
    "US-NV" => {38.9, -117.0},
    "US-NH" => {43.7, -71.6},
    "US-NJ" => {40.2, -74.5},
    "US-NM" => {34.4, -106.1},
    "US-NY" => {42.2, -75.5},
    "US-NC" => {35.6, -79.4},
    "US-ND" => {47.5, -100.5},
    "US-OH" => {40.4, -82.9},
    "US-OK" => {35.6, -97.5},
    "US-OR" => {44.0, -120.5},
    "US-PA" => {41.0, -77.5},
    "US-RI" => {41.7, -71.4},
    "US-SC" => {34.0, -81.0},
    "US-SD" => {44.4, -100.2},
    "US-TN" => {35.9, -86.4},
    "US-TX" => {31.3, -99.0},
    "US-UT" => {39.3, -111.7},
    "US-VT" => {44.1, -72.9},
    "US-VA" => {37.5, -78.8},
    "US-WA" => {47.4, -121.5},
    "US-WV" => {38.6, -80.6},
    "US-WI" => {44.6, -89.9},
    "US-WY" => {43.0, -107.5},
    "US-DC" => {38.9, -77.0}
  }

  @doc """
  Approximate centroid `{lat, lng}` for a `{country, state}` pair, or `nil`
  when the region is not in the static table. Only US states are mapped today;
  extend `@centroids` to cover more scenes.
  """
  @spec centroid(term(), term()) :: {float(), float()} | nil
  def centroid(country, state) when is_binary(country) and is_binary(state) do
    Map.get(@centroids, "#{country}-#{state}")
  end

  def centroid(_, _), do: nil

  @doc """
  Region bubbles for the map, each merged with its centroid so the front-end
  can place it without any geocoding. Regions whose `{country, state}` is not
  in the centroid table are dropped (they cannot be positioned).

  For the 2026 season view the map aggregates the full calendar year
  2026-01-01 to 2026-12-31 so Atlas shows the entire season, not just the
  last 90 days. This call is bounded (8s) and falls back to `Tournaments.regions/0`
  so the LiveView never blocks on 12 serial fetches.
  """
  @spec map_data() :: [map()]
  def map_data do
    full_year_result =
      try do
        full_year_2026_regions()
      rescue
        _ -> {:error, :no_cache}
      catch
        :exit, _ -> {:error, :no_cache}
      end

    case full_year_result do
      {:ok, regions, _status} ->
        to_bubbles(regions)

      _ ->
        case Tournaments.regions() do
          {:ok, regions, _status} ->
            regions
            |> Enum.map(fn region ->
              Map.put(region, :centroid, centroid(region["country"], region["state"]))
            end)
            |> Enum.reject(fn region -> region.centroid == nil end)
            |> Enum.map(fn region ->
              {lat, lng} = region.centroid

              %{
                "country" => region["country"],
                "state" => region["state"],
                "label" => region_label(region),
                "attendees" => region["attendees"],
                "tournaments" => region["tournaments"],
                "lat" => lat,
                "lng" => lng
              }
            end)

          _ ->
            []
        end
    end
  end

  defp to_bubbles(regions) do
    regions
    |> Enum.map(fn region ->
      Map.put(region, :centroid, centroid(region["country"], region["state"]))
    end)
    |> Enum.reject(fn region -> region.centroid == nil end)
    |> Enum.map(fn region ->
      {lat, lng} = region.centroid

      %{
        "country" => region["country"],
        "state" => region["state"],
        "label" => region_label(region),
        "attendees" => region["attendees"],
        "tournaments" => region["tournaments"],
        "lat" => lat,
        "lng" => lng
      }
    end)
  end

  defp full_year_2026_regions do
    KusaData.Cache.fetch("regions:2026", 6 * 60 * 60, fn ->
      task = Task.async(fn -> fetch_all_2026(1, []) end)

      case Task.yield(task, 8_000) || Task.shutdown(task, :brutal_kill) do
        {:ok, {:ok, nodes}} -> {:ok, build_regions(nodes)}
        {:ok, {:error, _} = err} -> err
        {:ok, _} -> {:error, :unexpected}
        nil -> {:error, :timeout}
      end
    end)
  end

  defp fetch_all_2026(page, acc) when page > 12 do
    {:ok, acc}
  end

  defp fetch_all_2026(page, acc) do
    case Tournaments.browse(%{
           mode: :past,
           from: "2026-01-01",
           to: "2026-12-31",
           games: :all,
           page: page
         }) do
      {:ok, %{"tournaments" => nodes, "total" => total}, _status} ->
        new_acc = acc ++ (nodes || [])

        cond do
          nodes == [] -> {:ok, new_acc}
          length(new_acc) >= total -> {:ok, new_acc}
          true -> fetch_all_2026(page + 1, new_acc)
        end

      {:error, _} = error ->
        if acc == [] do
          error
        else
          {:ok, acc}
        end
    end
  end

  defp build_regions(nodes) do
    nodes
    |> Enum.group_by(fn node -> {node["countryCode"], node["addrState"]} end)
    |> Enum.map(fn {{country, state}, entries} ->
      %{
        "country" => country,
        "state" => state,
        "tournaments" => length(entries),
        "attendees" => Enum.reduce(entries, 0, fn e, acc -> acc + (e["numAttendees"] || 0) end)
      }
    end)
    |> Enum.reject(&is_nil(&1["country"]))
    |> Enum.sort_by(fn entry -> {entry["attendees"], entry["country"], entry["state"]} end, :desc)
  end

  defp region_label(%{"state" => state}) when is_binary(state) and state != "", do: state
  defp region_label(%{"country" => country}), do: country
end
