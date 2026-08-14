defmodule KusaData.GraphQL.RateLimitTest do
  use ExUnit.Case, async: true

  alias KusaData.GraphQL.RateLimit

  describe "check/4" do
    test "allows requests under the limit" do
      timestamps = [10, 9, 8]
      assert :ok = RateLimit.check(timestamps, 11, 5, 60_000)
    end

    test "blocks when at the limit and returns remaining wait" do
      # 4 requests at t=10..7 within a 5s window at now=11 → over limit 3;
      # the oldest (t=7) frees at now=5007 → wait 4996ms.
      timestamps = [10, 9, 8, 7]
      assert {:wait, 4996} = RateLimit.check(timestamps, 11, 3, 5_000)
    end

    test "expired timestamps are dropped from the count" do
      # window 5ms, now=100 → in-window are t in (95..100] = [100,99,98,97,96]
      timestamps = [100, 99, 98, 97, 96, 95]
      # 5 in window, limit 5 → the next request would exceed → block, oldest frees at 101
      assert {:wait, 1} = RateLimit.check(timestamps, 100, 5, 5)
      # 5 in window, limit 6 → room → ok
      assert :ok = RateLimit.check(timestamps, 100, 6, 5)
    end
  end
end
