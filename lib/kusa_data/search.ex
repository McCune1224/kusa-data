defmodule KusaData.Search do
  @moduledoc """
  Player search + lookup.

  Queries the crawled Postgres player index first (instant, growing coverage).
  When the index has no **exact** gamer-tag match, it falls back to a live
  start.gg participant scan of recent Melee tournaments (start.gg has no global
  player search), merging the two sources and re-ranking globally: exact gamer
  tag > prefix > substring, with a team-prefix bonus, ties by Elo descending.
  """

  alias KusaData.{Game, Player, Rating, Repo}
  alias KusaData.Search.API

  import Ecto.Query

  @rank_exact 100
  @rank_prefix 60
  @rank_substring 30
  @rank_prefix_bonus 15
  @search_window_days 90
  @search_tournament_count 25
  @search_per_tournament 10

  @doc """
  Searches for `query` within `game`. Returns a list of
  `%{user_id, gamer_tag, prefix, player_id, elo}` ranked exact > prefix >
  substring, ties by elo desc. Empty/whitespace queries return `[]`.
  """
  @spec search(Game.t(), String.t()) :: [map]
  def search(game, query) do
    q = query |> String.trim() |> String.downcase()
    if q == "", do: [], else: ranked_search(game, q)
  end

  @doc """
  Index-only search: the instant Postgres lookup with **no** live start.gg
  fallback. Meant for keystroke-time UI dropdowns, where a per-character live
  scan would blow the start.gg rate limit. Ranked exactly like `search/2`.
  """
  @spec search_index(Game.t(), String.t()) :: [map]
  def search_index(game, query) do
    q = query |> String.trim() |> String.downcase()
    if q == "", do: [], else: rank_candidates(index_candidates(game, q), q)
  end

  defp ranked_search(game, q) do
    indexed = index_candidates(game, q)

    # Only pay for a live scan when the crawled index has no exact tag match.
    live =
      if Enum.any?(indexed, &(String.downcase(&1.gamer_tag || "") == q)) do
        []
      else
        live_candidates(q)
      end

    rank_candidates(dedupe_by_user_id(indexed, live), q)
  end

  # Merges the live scan into the indexed batch, skipping user ids the index
  # already knows about. Order doesn't matter — `rank_candidates/2` re-sorts.
  defp dedupe_by_user_id(indexed, live) do
    Enum.reduce(live, indexed, fn result, acc ->
      if Enum.any?(acc, &(&1.user_id == result.user_id)) do
        acc
      else
        [result | acc]
      end
    end)
  end

  defp rank_candidates(candidates, q) do
    Enum.sort(candidates, fn a, b ->
      ranking(b, q) < ranking(a, q) or
        (ranking(b, q) == ranking(a, q) and elo_of(b) < elo_of(a))
    end)
  end

  # Crawled Postgres players (index-first), scoped to the game via `ratings`.
  defp index_candidates(game, q) do
    from(p in Player,
      join: r in Rating,
      on: r.player_id == p.id and r.game_id == ^game.id,
      where: ilike(p.gamer_tag, ^"%#{q}%") or ilike(p.prefix, ^"%#{q}%"),
      select: %{
        user_id: p.user_id,
        gamer_tag: p.gamer_tag,
        prefix: p.prefix,
        player_id: p.player_id,
        elo: r.elo
      }
    )
    |> Repo.all()
  end

  # Live start.gg fallback: scan recent tournament participants. Dedupes by
  # user id, keeping the highest-scoring match (start.gg returns them newest
  # first, which is also our tie-break order).
  defp live_candidates(q) do
    now = System.system_time(:second)
    after_date = now - @search_window_days * 86_400

    case API.recent_tournaments(after_date, @search_tournament_count) do
      {:ok, slugs} ->
        slugs
        |> Enum.reduce(%{}, &scan_tournament(&1, &2, q))
        |> Map.values()
        |> Enum.map(fn {_score, node} -> node end)
        |> Enum.reject(&is_nil(&1.user_id))

      {:error, _reason} ->
        []
    end
  end

  # Scans one tournament's participants. The API swallows its own failures
  # into `{:ok, []}`, so a failing tournament just contributes nothing.
  defp scan_tournament(slug, best, q) do
    case API.search_participants(slug, q, @search_per_tournament) do
      {:ok, nodes} -> Enum.reduce(nodes, best, &merge_node(&1, &2, q))
    end
  end

  defp merge_node(node, best, q) do
    if is_nil(node.user_id), do: best, else: upsert_best(best, node, q)
  end

  defp upsert_best(best, node, q) do
    score = ranking_live(node, q)
    existing = best[node.user_id]

    if is_nil(existing) or score > elem(existing, 0) do
      Map.put(best, node.user_id, {score, Map.put(node, :elo, 1500.0)})
    else
      best
    end
  end

  defp ranking_live(node, q) do
    ranking(%{gamer_tag: node.gamer_tag, prefix: node.prefix, elo: 1500.0}, q)
  end

  defp ranking(result, q) do
    tag = String.downcase(result.gamer_tag || "")
    prefix = String.downcase(result.prefix || "")

    tag_rank =
      cond do
        tag == q -> @rank_exact
        String.starts_with?(tag, q) -> @rank_prefix
        String.contains?(tag, q) -> @rank_substring
        true -> 0
      end

    tag_rank + if(prefix == q, do: @rank_prefix_bonus, else: 0)
  end

  defp elo_of(%{elo: elo}), do: elo
end
