defmodule KusaData.GraphQL.RateLimiterTest do
  use ExUnit.Case, async: true

  alias KusaData.GraphQL.RateLimiter

  setup do
    limiter =
      start_supervised!({RateLimiter, name: :test_limiter, limit: 2, window_ms: 30})

    %{limiter: limiter}
  end

  test "allows up to the limit immediately", %{limiter: limiter} do
    assert :ok = RateLimiter.wait(limiter)
    assert :ok = RateLimiter.wait(limiter)
  end

  test "blocks callers beyond the limit until a slot frees", %{limiter: limiter} do
    assert :ok = RateLimiter.wait(limiter)
    assert :ok = RateLimiter.wait(limiter)

    test_pid = self()
    spawn(fn -> send(test_pid, {:waited, RateLimiter.wait(limiter)}) end)

    refute_receive {:waited, _}, 20

    assert_receive {:waited, :ok}, 500
  end

  test "serves queued waiters FIFO", %{limiter: limiter} do
    assert :ok = RateLimiter.wait(limiter)
    assert :ok = RateLimiter.wait(limiter)

    test_pid = self()

    Enum.each(1..3, fn n ->
      spawn(fn -> send(test_pid, {:waited, n, RateLimiter.wait(limiter)}) end)
    end)

    assert_receive {:waited, 1, :ok}, 500
    assert_receive {:waited, 2, :ok}, 100
    assert_receive {:waited, 3, :ok}, 100
  end
end
