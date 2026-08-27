defmodule KusaData.Tournaments do
  @moduledoc """
  Tournament browsing over a normalized query contract.

  `browse/1` takes a query map describing one page of results:

      %{
        mode: :upcoming | :past | :search | :region,
        page: 1,
        from: "2026-01-01" | nil,          # ISO date lower bound (:past)
        to: "2026-01-31" | nil,            # ISO date upper bound (:past)
        q: "genesis" | nil,                # name/city/venue search (:search, :past)
        results_only: false,               # keep tournaments with a completed event
        games: ["melee"] | :all,           # selected game slugs
        zip: nil, radius: nil,             # postal-radius browse (mode :upcoming)
        country: nil, state: nil           # region browse (mode :region)
      }

  Every page is cached under a key derived from the full normalized query, so
  one filter can never be served from another filter's cache entry. Melee is
  the default game selection; `games: :all` omits the upstream game
  restriction entirely.
  """

  @per_page 24
  @radii ["25mi", "50mi", "100mi", "200mi"]

  alias KusaData.Cache
  alias KusaData.Events
  alias KusaData.Games
  alias KusaData.Geocode
  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries

  @type radius :: String.t()
  @type result :: %{tournaments: list(map()), total: non_neg_integer(), page: pos_integer()}
  @type browse_mode :: :upcoming | :past | :search | :region

  @default_query %{
    mode: :upcoming,
    page: 1,
    from: nil,
    to: nil,
    q: nil,
    results_only: false,
    games: ["melee"],
    zip: nil,
    radius: nil,
    country: nil,
    state: nil
  }

  @spec radii() :: [radius()]
  def radii, do: @radii

  @doc "One page of tournaments matching the normalized query."
  @spec browse(map()) :: {:ok, result(), :hit | :miss | :bypass} | {:error, term()}
  def browse(query \\ %{}) do
    query = normalize_query(query)
    Cache.fetch(cache_key(query), @per_page * 60, fn -> run_browse(query) end)
  end

  @doc "Upcoming Melee tournaments worldwide (compat wrapper over `browse/1`)."
  @spec upcoming(pos_integer()) :: {:ok, result(), :hit | :miss | :bypass} | {:error, term()}
  def upcoming(page \\ 1), do: browse(%{mode: :upcoming, page: page})

  @doc "Upcoming tournaments within `radius` of `zip` (compat wrapper over `browse/1`)."
  @spec nearby(String.t(), radius(), pos_integer()) ::
          {:ok, result(), :hit | :miss | :bypass} | {:error, term()}
  def nearby(zip, radius, page \\ 1),
    do: browse(%{mode: :upcoming, zip: zip, radius: radius, page: page})

  @doc """
  Available browse regions, derived from recent tournament payloads.

  Returns `{:ok, [%{country: ..., state: ...|nil, tournaments: n}]}` grouped by
  country and state, best-attended first. State is never fabricated: missing
  state codes collapse into the country-level entry.
  """
  @spec regions() :: {:ok, [map()], :hit | :miss | :bypass} | {:error, term()}
  def regions do
    Cache.fetch("regions:index", 6 * 60 * 60, fn ->
      case recent_for_regions() do
        {:ok, nodes} -> {:ok, build_regions(nodes)}
        error -> error
      end
    end)
  end

  @doc "Tournament detail with its events (all games) and their game identity."
  @spec by_slug(String.t()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def by_slug(slug) do
    Cache.fetch("tournament:#{slug}", 10 * 60, fn ->
      with {:ok, data} <- Client.query(Queries.tournament_detail(slug)),
           %{"tournament" => %{} = tournament} <- data do
        {:ok, tournament}
      else
        %{"tournament" => nil} -> {:error, :not_found}
        _ -> {:error, :unexpected_response}
      end
    end)
  end

  @doc "Clears cached browse pages for a location so the next browse is fresh."
  @spec invalidate(String.t(), radius()) :: :ok
  def invalidate(zip, radius) do
    Enum.each(1..5, fn page ->
      Cache.delete(cache_key(%{mode: :upcoming, zip: zip, radius: radius, page: page}))
    end)

    :ok
  end

  @doc """
  Full tournament export: the tournament plus per-event analytics
  (seeds, results, sets, and the bracket analysis). Cached under
  `export:<slug>` so repeated downloads reuse one computation.
  """
  @spec export(String.t()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def export(slug) do
    Cache.fetch("export:#{slug}", 10 * 60, fn ->
      with {:ok, tournament, _} <- by_slug(slug) do
        events =
          (tournament["events"] || [])
          |> Enum.reduce_while({:ok, []}, fn event, {:ok, acc} ->
            case Events.analytics(event["id"]) do
              {:ok, analytics, _} -> {:cont, {:ok, [analytics | acc]}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
          end)

        case events do
          {:ok, analytics} ->
            {:ok, %{"tournament" => tournament, "events" => Enum.reverse(analytics)}}

          {:error, _reason} = error ->
            error
        end
      end
    end)
  end

  defp run_browse(%{mode: :search, q: q}) when q in [nil, ""] do
    {:ok, empty_page(1)}
  end

  defp run_browse(%{mode: :search, q: q} = query) when is_binary(q) do
    trimmed = String.trim(q)

    if String.length(trimmed) < 2 do
      {:ok, empty_page(query.page)}
    else
      with {:ok, filter} <- build_filter(%{query | q: trimmed}) do
        with {:ok, data} <-
               Client.query(
                 Queries.tournament_search(filter, query.page, @per_page, games_ids(query))
               ) do
          {:ok, parse_page(data, query.page)}
        end
      end
    end
  end

  defp run_browse(%{mode: :region, country: country}) when country in [nil, ""] do
    {:ok, empty_page(1)}
  end

  defp run_browse(%{zip: zip} = query) when is_binary(zip) and zip != "" do
    with {:ok, place, _status} <- Geocode.lookup(zip) do
      coordinates = "#{place["lat"]},#{place["lng"]}"
      filter = Queries.nearby_filter(coordinates, query.radius, games_ids(query))

      with {:ok, data} <-
             Client.query(
               Queries.tournament_search(filter, query.page, @per_page, games_ids(query))
             ) do
        {:ok, Map.put(parse_page(data, query.page), "place", place)}
      end
    else
      {:error, _reason} = error -> error
    end
  end

  defp run_browse(%{results_only: true} = query) do
    collect_results(query, 1, [])
  end

  defp run_browse(query) do
    with {:ok, filter} <- build_filter(query) do
      with {:ok, data} <-
             Client.query(
               Queries.tournament_search(filter, query.page, @per_page, games_ids(query))
             ) do
        {:ok, parse_page(data, query.page)}
      end
    end
  end

  defp build_filter(%{mode: :upcoming} = query),
    do: {:ok, Queries.upcoming_filter(games_ids(query))}

  defp build_filter(%{mode: :past} = query), do: {:ok, Queries.past_filter(query)}

  defp build_filter(%{mode: :search} = query), do: {:ok, Queries.search_filter(query)}

  defp build_filter(%{mode: :region} = query), do: {:ok, Queries.region_filter(query)}

  # Fetches upstream pages until the requested page is filled with
  # results-ready tournaments (past/search/region with `results_only`).
  defp collect_results(query, upstream_page, acc) do
    with {:ok, filter} <- build_filter(query),
         {:ok, data} <-
           Client.query(
             Queries.tournament_search(filter, upstream_page, @per_page, games_ids(query))
           ) do
      nodes = data["tournaments"]["nodes"] || []
      total_pages = data["tournaments"]["pageInfo"]["totalPages"] || 1
      acc = acc ++ Enum.filter(nodes, &results_ready?/1)

      needed = query.page * @per_page

      if length(acc) >= needed or upstream_page >= total_pages or nodes == [] do
        {:ok,
         %{
           "tournaments" => Enum.slice(acc, (query.page - 1) * @per_page, @per_page),
           "total" => length(acc),
           "page" => query.page
         }}
      else
        collect_results(query, upstream_page + 1, acc)
      end
    end
  end

  # A tournament is "results-ready" when at least one of its events reports a
  # completed state. Missing state is treated as not results-ready rather than
  # guessing from other fields.
  defp results_ready?(tournament) do
    Enum.any?(tournament["events"] || [], fn event ->
      event["state"] in [3, "COMPLETED"]
    end)
  end

  defp parse_page(%{"tournaments" => %{"nodes" => nodes, "pageInfo" => page_info}}, page) do
    %{
      "tournaments" => nodes,
      "total" => page_info["total"] || 0,
      "page" => page
    }
  end

  defp empty_page(page), do: %{"tournaments" => [], "total" => 0, "page" => page}

  defp games_ids(%{games: :all}), do: nil
  defp games_ids(%{games: games}), do: Games.ids_for_slugs(games)

  defp normalize_query(query) do
    Map.merge(
      @default_query,
      Map.new(query, fn {key, value} -> {key, normalize_field(key, value)} end)
    )
  end

  defp normalize_field(:mode, value) when value in [:upcoming, :past, :search, :region],
    do: value

  defp normalize_field(:mode, value) when value in ["upcoming", "past", "search", "region"] do
    String.to_existing_atom(value)
  end

  defp normalize_field(:mode, _), do: :upcoming

  defp normalize_field(:page, value) when is_integer(value) and value >= 1, do: value

  defp normalize_field(:page, value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> max(number, 1)
      _ -> 1
    end
  end

  defp normalize_field(:page, _), do: 1

  defp normalize_field(:games, :all), do: :all
  defp normalize_field(:games, "all"), do: :all

  defp normalize_field(:games, value) when is_list(value),
    do: value |> Enum.map(&to_string/1) |> Enum.uniq() |> Enum.sort()

  defp normalize_field(:games, value) when is_binary(value), do: [value]
  defp normalize_field(:games, _), do: ["melee"]

  defp normalize_field(:results_only, value), do: value in [true, "true", "1", 1]

  defp normalize_field(:zip, value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      zip -> zip
    end
  end

  defp normalize_field(_, value), do: value

  defp cache_key(query) do
    query = normalize_query(query)

    canonical = %{
      "mode" => query.mode,
      "page" => query.page,
      "from" => query.from,
      "to" => query.to,
      "q" => query.q,
      "results_only" => query.results_only,
      "games" => if(query.games == :all, do: "all", else: query.games),
      "zip" => query.zip,
      "radius" => query.radius,
      "country" => query.country,
      "state" => query.state
    }

    "browse:" <> Jason.encode!(canonical)
  end

  defp recent_for_regions do
    after_date = DateTime.utc_now() |> DateTime.add(-90 * 86_400, :second) |> DateTime.to_unix()

    with {:ok, data} <-
           Client.query(
             Queries.tournament_search(Queries.recent_filter(after_date, nil), 1, 200, nil)
           ) do
      {:ok, data["tournaments"]["nodes"] || []}
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
end
