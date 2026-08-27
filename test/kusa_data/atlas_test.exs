defmodule KusaData.AtlasTest do
  use ExUnit.Case, async: false
  use KusaData.Test.Doubles

  describe "centroid/2" do
    test "returns the static centroid for a known US state" do
      assert KusaData.Atlas.centroid("US", "CA") == {36.7, -119.4}
      assert KusaData.Atlas.centroid("US", "NY") == {42.2, -75.5}
    end

    test "returns nil for unknown or malformed regions" do
      assert KusaData.Atlas.centroid("US", "ZZ") == nil
      assert KusaData.Atlas.centroid(nil, nil) == nil
    end
  end

  describe "map_data/0" do
    test "returns a list even when no regions resolve" do
      assert is_list(KusaData.Atlas.map_data())
    end

    test "each entry carries a label and a resolvable centroid" do
      for region <- KusaData.Atlas.map_data() do
        assert is_binary(region["label"])
        assert is_number(region["lat"])
        assert is_number(region["lng"])
      end
    end
  end
end
