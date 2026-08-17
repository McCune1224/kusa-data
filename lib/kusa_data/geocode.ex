defmodule KusaData.Geocode do
  @moduledoc """
  Zip/postal code → coordinates lookup.

  US/UK codes resolve through Zippopotam.us first; anything else (or an
  unknown code) falls back to Open-Meteo's postal-code geocoding. Results are
  cached for a week — postal codes don't move. Places use string keys to stay
  consistent with JSON-cached values.
  """

  @zippopotamus "https://api.zippopotam.us"
  @open_meteo "https://geocoding-api.open-meteo.com/v1/search"
  @cache_ttl 7 * 24 * 60 * 60

  @us_zip ~r/^\d{5}$/

  alias KusaData.Cache

  @type place :: %{
          optional(String.t()) => term()
        }

  @spec lookup(String.t()) :: {:ok, place(), :hit | :miss | :bypass} | {:error, term()}
  def lookup(zip) do
    zip = String.trim(zip)

    Cache.fetch("geo:zip:#{String.downcase(zip)}", @cache_ttl, fn -> lookup_fresh(zip) end)
  end

  defp lookup_fresh(zip) do
    case zippopotamus(zip) do
      {:ok, place} -> {:ok, place}
      :not_found -> open_meteo(zip)
    end
  end

  defp zippopotamus(zip) do
    country = if Regex.match?(@us_zip, zip), do: "us", else: "gb"
    url = "#{@zippopotamus}/#{country}/#{URI.encode(zip)}"

    case transport().get(url, []) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        case body do
          %{"places" => [place | _]} ->
            {:ok,
             %{
               "lat" => to_float(place["latitude"]),
               "lng" => to_float(place["longitude"]),
               "city" => place["place name"],
               "state" => place["state abbreviation"] || place["state"],
               "country_code" => String.upcase(body["country abbreviation"] || "US")
             }}

          _ ->
            :not_found
        end

      {:ok, %{status: 404}} ->
        :not_found

      {:error, _reason} ->
        :not_found
    end
  end

  defp open_meteo(zip) do
    url = "#{@open_meteo}?postalcode=#{URI.encode(zip)}&count=1&language=en&format=json"

    case transport().get(url, []) do
      {:ok, %{status: 200, body: %{"results" => [place | _]}}} ->
        {:ok,
         %{
           "lat" => to_float(place["latitude"]),
           "lng" => to_float(place["longitude"]),
           "city" => place["name"],
           "state" => place["admin1"],
           "country_code" => place["country_code"]
         }}

      {:ok, %{status: 200, body: %{"results" => []}}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp to_float(value) when is_number(value), do: value
  defp to_float(value) when is_binary(value), do: String.to_float(value)
  defp to_float(_), do: 0.0

  defp transport do
    Application.get_env(:kusa_data, KusaData.GraphQL.Client, [])
    |> Keyword.get(:transport, KusaData.GraphQL.ReqTransport)
  end
end
