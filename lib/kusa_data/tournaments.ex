defmodule KusaData.Tournaments do
  @moduledoc """
  Tournament browsing: upcoming Melee events everywhere, or nearby a postal
  code within a radius. Results are cached per query so repeated browsing
  doesn't burn start.gg quota.
  """

  @per_page 24
  @radii ["25mi", "50mi", "100mi", "200mi"]

  alias KusaData.Cache
  alias KusaData.Geocode
  alias KusaData.GraphQL.Client
  alias KusaData.GraphQL.Queries

  @type radius :: String.t()
  @type result :: %{tournaments: list(map()), total: non_neg_integer(), page: pos_integer()}

  @spec radii() :: [radius()]
  def radii, do: @radii

  @doc "Upcoming Melee tournaments worldwide."
  @spec upcoming(pos_integer()) :: {:ok, result(), :hit | :miss | :bypass} | {:error, term()}
  def upcoming(page \\ 1) do
    key = "upcoming:#{page}"

    Cache.fetch(key, 15 * 60, fn ->
      with {:ok, data} <-
             Client.query(Queries.tournament_search(Queries.upcoming_filter(), page, @per_page)) do
        {:ok, parse_page(data, page)}
      end
    end)
  end

  @doc "Upcoming Melee tournaments within `radius` of `zip`."
  @spec nearby(String.t(), radius(), pos_integer()) ::
          {:ok, result(), :hit | :miss | :bypass} | {:error, term()}
  def nearby(zip, radius, page \\ 1) do
    with {:ok, place, _status} <- Geocode.lookup(zip) do
      coordinates = "#{place["lat"]},#{place["lng"]}"
      key = "nearby:#{zip}:#{radius}:#{page}"
      filter = Queries.nearby_filter(coordinates, radius)

      Cache.fetch(key, 15 * 60, fn ->
        with {:ok, data} <- Client.query(Queries.tournament_search(filter, page, @per_page)) do
          {:ok, parse_page(data, page)}
        end
      end)
      |> wrap_place(place)
    else
      {:error, _reason} = error -> error
    end
  end

  @doc "Tournament detail with its Melee events."
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

  @doc "Clears cached pages for a location so the next browse is fresh."
  @spec invalidate(String.t(), radius()) :: :ok
  def invalidate(zip, radius) do
    Enum.each(1..5, fn page ->
      Cache.delete("nearby:#{zip}:#{radius}:#{page}")
    end)
  end

  defp parse_page(%{"tournaments" => %{"nodes" => nodes, "pageInfo" => page_info}}, page) do
    %{
      "tournaments" => nodes,
      "total" => page_info["total"] || 0,
      "page" => page
    }
  end

  defp wrap_place({:ok, value, status}, place) do
    {:ok, Map.put(value, "place", place), status}
  end

  defp wrap_place({:error, _reason} = error, _place), do: error
end
