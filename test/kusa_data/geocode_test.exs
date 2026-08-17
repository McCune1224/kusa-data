defmodule KusaData.GeocodeTest do
  use ExUnit.Case, async: false

  import KusaData.Test.Doubles

  alias KusaData.Geocode
  alias KusaData.Test.FakeTransport
  alias KusaData.Test.Fixtures

  use KusaData.Test.Doubles

  test "resolves US zips through Zippopotam.us" do
    FakeTransport.put(
      :url,
      "zippopotam.us/us/60614",
      Fixtures.zippopotam_response(41.9208, -87.6488, "Chicago", "IL")
    )

    assert {:ok, place, :miss} = Geocode.lookup("60614")
    assert place["lat"] == 41.9208
    assert place["lng"] == -87.6488
    assert place["city"] == "Chicago"
    assert place["state"] == "IL"
    assert place["country_code"] == "US"
  end

  test "unknown US zips fall back to Open-Meteo" do
    FakeTransport.put(:url, "zippopotam.us/us", %{status: 404})

    FakeTransport.put(
      :url,
      "geocoding-api.open-meteo.com",
      Fixtures.open_meteo_response(52.52, 13.405, "Berlin", "DE")
    )

    assert {:ok, place, :miss} = Geocode.lookup("10115")
    assert place["city"] == "Berlin"
    assert place["country_code"] == "DE"
  end

  test "unknown everywhere returns an error" do
    FakeTransport.put(:url, "zippopotam.us", %{status: 404})
    FakeTransport.put(:url, "geocoding-api.open-meteo.com", %{"results" => []})

    assert {:error, :not_found} = Geocode.lookup("00000")
  end

  test "hits the cache on the second lookup" do
    FakeTransport.put(
      :url,
      "zippopotam.us/us/60614",
      Fixtures.zippopotam_response(41.9208, -87.6488, "Chicago", "IL")
    )

    assert {:ok, _, :miss} = Geocode.lookup("60614")

    FakeTransport.put(:url, "zippopotam.us", %{status: 500})

    assert {:ok, %{"city" => "Chicago"}, :hit} = Geocode.lookup("60614")
  end
end
