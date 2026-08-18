defmodule KusaData.Games do
  @moduledoc """
  Normalized game registry.

  Melee (start.gg videogame id `1`) is the seeded default so the app works
  before any upstream data has been seen. Additional games are derived from
  the `videogame` fields returned by start.gg (event payloads or the
  `Videogames` list query) via `normalize/1` / `sync/0` — never from more
  hard-coded numeric ids.

  The registry lives in a named ETS table (created lazily so tests and
  standalone scripts can use the module without supervision), so `/game/:slug`
  lookups and `videogameIds` filter construction share one source of truth.
  """

  @table __MODULE__
  @default_slug "melee"
  @sync_ttl 24 * 60 * 60

  alias KusaData.Cache
  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries

  @melee %{
    slug: "melee",
    videogame_id: 1,
    name: "Super Smash Bros. Melee",
    short_name: "Melee"
  }

  @type game :: %{
          slug: String.t(),
          videogame_id: integer(),
          name: String.t(),
          short_name: String.t()
        }

  @doc "The default game (Melee) used when a URL or query has no game selection."
  @spec default() :: game()
  def default, do: @melee

  @doc "Every known game, sorted by name."
  @spec all() :: [game()]
  def all do
    ensure_table!()
    @table |> :ets.tab2list() |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.name)
  end

  @doc "Looks a game up by its canonical slug. Returns `nil` for unknown slugs."
  @spec by_slug(String.t()) :: game() | nil
  def by_slug(slug) when is_binary(slug) do
    ensure_table!()

    case :ets.lookup(@table, canonical_slug(slug)) do
      [{_key, game}] -> game
      [] -> nil
    end
  end

  @doc "Looks a game up by its start.gg videogame id. Returns `nil` if unknown."
  @spec by_id(integer()) :: game() | nil
  def by_id(id) when is_integer(id) do
    ensure_table!()

    case :ets.match_object(@table, {:_, %{videogame_id: id}}) do
      [{_key, game} | _] -> game
      [] -> nil
    end
  end

  @doc "Canonical slug for a start.gg videogame id, or `nil` if unknown."
  @spec slug_for_id(integer()) :: String.t() | nil
  def slug_for_id(id) do
    case by_id(id) do
      %{slug: slug} -> slug
      nil -> nil
    end
  end

  @doc "Converts a list of slugs into start.gg videogame ids, skipping unknown slugs."
  @spec ids_for_slugs([String.t()]) :: [integer()]
  def ids_for_slugs(slugs) when is_list(slugs) do
    slugs
    |> Enum.flat_map(fn slug ->
      case by_slug(slug) do
        %{videogame_id: id} -> [id]
        nil -> []
      end
    end)
    |> Enum.uniq()
  end

  @doc """
  Normalizes a start.gg `videogame` payload (`%{"id", "name", "slug"}`) into a
  game record, registering it in the registry so later slug lookups resolve.
  """
  @spec normalize(map()) :: game()
  def normalize(%{"id" => id, "name" => name} = videogame) when is_integer(id) do
    slug = slug_from(videogame)

    game = %{
      slug: slug,
      videogame_id: id,
      name: name,
      short_name: short_name_from(videogame, slug)
    }

    register(game)
    game
  end

  def normalize(_), do: nil

  @doc """
  Refreshes the registry from the start.gg `Videogames` list query.

  The raw list is cached in Redis; every known game is (re-)registered in the
  ETS registry on each call so a cache hit also keeps local lookups warm.
  Returns the number of games known, or an error tuple if upstream is down.
  """
  @spec sync() :: {:ok, non_neg_integer()} | {:error, term()}
  def sync do
    case Cache.fetch("games:registry", @sync_ttl, &fetch_videogames/0) do
      {:ok, nodes, _status} ->
        Enum.each(nodes, &normalize/1)
        {:ok, length(all())}

      {:error, _reason} = error ->
        error
    end
  end

  @doc "Registers a game record (mainly for tests and seeding)."
  @spec register(game()) :: :ok
  def register(%{slug: slug} = game) when is_binary(slug) do
    ensure_table!()
    :ets.insert(@table, {slug, game})
    :ok
  end

  defp fetch_videogames do
    with {:ok, data} <- Client.query(Queries.videogames()) do
      case data["videogames"]["nodes"] do
        nodes when is_list(nodes) -> {:ok, nodes}
        _ -> {:error, :unexpected_response}
      end
    end
  end

  defp slug_from(%{"slug" => slug}) when is_binary(slug) do
    slug
    |> String.trim()
    |> String.trim_leading("/")
    |> String.replace_prefix("game/", "")
    |> canonical_slug()
  end

  defp slug_from(_), do: nil

  defp short_name_from(%{"abbreviation" => abbr}, _slug) when is_binary(abbr) and abbr != "" do
    abbr
  end

  defp short_name_from(_videogame, slug), do: slug

  defp canonical_slug(slug) when is_binary(slug) do
    slug
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> @default_slug
      s -> s
    end
  end

  defp canonical_slug(_), do: @default_slug

  defp ensure_table! do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _ ->
        :ok
    end

    case :ets.lookup(@table, @default_slug) do
      [] -> :ets.insert(@table, {@default_slug, @melee})
      _ -> :ok
    end

    :ok
  end
end
