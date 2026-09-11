defmodule KusaData.Events do
  @moduledoc """
  Per-event bracket data: entrants with their seeds, and final standings.

  Seedings and results are cached with short TTLs (they move while a bracket
  runs) and support explicit invalidation via `clear_cache/1` for the
  "refresh" button in the UI.
  """

  @per_page 200
  @max_pages 10

  alias KusaData.Cache
  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries
  alias KusaData.Stats.BracketEngine

  @type page_collection :: %{
          nodes: list(map()),
          total: non_neg_integer(),
          total_pages: pos_integer()
        }

  @doc "Event header by numeric id or full slug (`tournament/x/event/y`)."
  @spec get(integer() | String.t()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def get(nil), do: {:error, :not_found}

  def get(identifier) do
    Cache.fetch("event:#{identifier}", 5 * 60, fn ->
      with {:ok, data} <- Client.query(Queries.event_detail(identifier)),
           %{"event" => %{} = event} <- data do
        {:ok, event}
      else
        %{"event" => nil} -> {:error, :not_found}
        _ -> {:error, :unexpected_response}
      end
    end)
  end

  @doc "All entrants with seed numbers, sorted by seed."
  @spec seeding(integer()) :: {:ok, [map()], :hit | :miss | :bypass} | {:error, term()}
  def seeding(event_id) do
    Cache.fetch("seeds:#{event_id}", 5 * 60, fn ->
      with {:ok, pages} <- fetch_all(event_id, :entrants) do
        seeds =
          pages
          |> Enum.flat_map(fn page -> page["nodes"] end)
          |> Enum.map(fn entrant ->
            %{
              "id" => entrant["id"],
              "name" => entrant["name"],
              "seed" => entrant["seeds"] |> List.first() |> map_seed(),
              "player_id" => player_id_from(entrant)
            }
          end)
          |> Enum.sort_by(& &1["seed"])

        {:ok, seeds}
      end
    end)
  end

  @doc "Final placements for an event, best first."
  @spec results(integer()) :: {:ok, [map()], :hit | :miss | :bypass} | {:error, term()}
  def results(event_id) do
    Cache.fetch("results:#{event_id}", 5 * 60, fn ->
      with {:ok, pages} <- fetch_all(event_id, :standings) do
        standings =
          pages
          |> Enum.flat_map(fn page -> page["nodes"] end)
          |> Enum.map(fn standing ->
            %{
              "placement" => standing["placement"],
              "entrant_id" => standing["entrant"]["id"],
              "name" => standing["entrant"]["name"],
              "player_id" => player_id_from(standing["entrant"])
            }
          end)
          |> Enum.sort_by(& &1["placement"])

        {:ok, standings}
      end
    end)
  end

  @doc "All recorded sets for an event (winners, scores, rounds, completed time)."
  @spec sets(integer()) :: {:ok, [map()], :hit | :miss | :bypass} | {:error, term()}
  def sets(event_id) do
    Cache.fetch("sets:#{event_id}", 5 * 60, fn ->
      with {:ok, pages} <- fetch_all(event_id, :sets) do
        all_sets =
          pages
          |> Enum.flat_map(fn page -> page["nodes"] end)
          |> Enum.map(fn set ->
            %{
              "id" => set["id"],
              "state" => set["state"],
              "winner_id" => set["winnerId"],
              "display_score" => set["displayScore"],
              "round" => set["fullRoundText"],
              "completed_at" => set["completedAt"],
              "slots" =>
                (set["slots"] || [])
                |> Enum.map(fn slot ->
                  %{"entrant_id" => slot["entrant"]["id"], "name" => slot["entrant"]["name"]}
                end)
            }
          end)
          |> Enum.sort_by(& &1["id"])

        {:ok, all_sets}
      end
    end)
  end

  @doc """
  Full bracket analytics for an event: seeds + results + sets joined by the
  `BracketEngine`. Cached with the same TTL and invalidation as the raw
  collections, so the UI and the export API share one computation.

  Accepts optional pre-fetched data to avoid redundant cache lookups and API
  calls when the caller already has one or more of the dependencies.
  """
  @spec analytics(integer(), keyword()) :: {:ok, map(), :hit | :miss | :bypass} | {:error, term()}
  def analytics(event_id, opts \\ []) do
    Cache.fetch("analytics:#{event_id}", 5 * 60, fn ->
      with {:ok, seeds, _} <- maybe_seeding(event_id, opts),
           {:ok, standings, _} <- maybe_results(event_id, opts),
           {:ok, event_sets, _} <- sets(event_id),
           {:ok, event, _} <- maybe_get(event_id, opts) do
        {:ok,
         %{
           "event" => event,
           "seeds" => seeds,
           "results" => standings,
           "sets" => event_sets,
           "analysis" => BracketEngine.analyze(seeds, standings, event_sets, context(event))
         }}
      end
    end)
  end

  defp maybe_get(event_id, opts) do
    case Keyword.fetch(opts, :event) do
      {:ok, event} -> {:ok, event, :bypass}
      :error -> get(event_id)
    end
  end

  defp maybe_results(event_id, opts) do
    case Keyword.fetch(opts, :results) do
      {:ok, results} -> {:ok, results, :bypass}
      :error -> results(event_id)
    end
  end

  defp maybe_seeding(event_id, opts) do
    case Keyword.fetch(opts, :seeds) do
      {:ok, seeds} -> {:ok, seeds, :bypass}
      :error -> seeding(event_id)
    end
  end

  @doc "Drops cached seeds/results/sets/analytics/brackets so the next fetch is fresh."
  @spec clear_cache(integer()) :: :ok
  def clear_cache(event_id) do
    Cache.delete("seeds:#{event_id}")
    Cache.delete("results:#{event_id}")
    Cache.delete("sets:#{event_id}")
    Cache.delete("analytics:#{event_id}")
    KusaData.Brackets.clear_cache(event_id)
    :ok
  end

  defp context(event) do
    tournament = event["tournament"] || %{}

    %{
      "event_id" => event["id"],
      "event_name" => event["name"],
      "event_slug" => event["slug"],
      "tournament_slug" => tournament["slug"],
      "tournament_name" => tournament["name"],
      "start_at" => event["startAt"] || tournament["startAt"]
    }
  end

  defp fetch_all(event_id, collection) do
    query_fn = fn page -> page_query(event_id, collection, page) end

    with {:ok, first} <- Client.query(query_fn.(1)) do
      page_info = page_info(first, collection)
      total_pages = min(page_info["totalPages"] || 1, @max_pages)

      remaining =
        if total_pages > 1 do
          pages = Enum.map(2..total_pages, & &1)
          fetch_remaining(event_id, collection, pages)
        else
          {:ok, []}
        end

      case remaining do
        {:ok, rest} -> {:ok, [parse(first, collection) | rest]}
        error -> error
      end
    end
  end

  defp fetch_remaining(event_id, collection, pages) do
    pages
    |> Task.async_stream(
      fn page ->
        query = page_query(event_id, collection, page)
        Client.query(query)
      end,
      max_concurrency: 5,
      timeout: :infinity,
      ordered: false
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {:ok, data}}, {:ok, acc} ->
        {:cont, {:ok, [parse(data, collection) | acc]}}

      {:ok, {:error, reason}}, _acc ->
        {:halt, {:error, reason}}

      {:error, reason}, _acc ->
        {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, pages} -> {:ok, Enum.reverse(pages)}
      error -> error
    end
  end

  defp page_query(event_id, :entrants, page), do: Queries.event_seeding(event_id, page, @per_page)

  defp page_query(event_id, :standings, page),
    do: Queries.event_results(event_id, page, @per_page)

  defp page_query(event_id, :sets, page), do: Queries.event_sets(event_id, page, @per_page)

  defp parse(data, :entrants), do: data["event"]["entrants"]
  defp parse(data, :standings), do: data["event"]["standings"]
  defp parse(data, :sets), do: data["event"]["sets"]

  defp page_info(data, collection) do
    parse(data, collection)["pageInfo"]
  end

  defp map_seed(nil), do: nil
  defp map_seed(%{"seedNum" => num}), do: num
  defp map_seed(_), do: nil

  defp player_id_from(%{"participants" => participants}) when is_list(participants) do
    Enum.find_value(participants, fn p ->
      case p do
        %{"user" => %{"player" => %{"id" => player_id}}} -> player_id
        _ -> nil
      end
    end)
  end

  defp player_id_from(_), do: nil
end
