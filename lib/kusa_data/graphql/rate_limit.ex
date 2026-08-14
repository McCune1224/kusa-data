defmodule KusaData.GraphQL.RateLimit do
  @moduledoc """
  Pure sliding-window rate-limit math (start.gg allows 80 requests per 60s).
  Deterministic and unit-testable; the GenServer (`RateLimiter`) owns the state.
  """

  @doc """
  Given timestamps (newest-first, ms), returns `:ok` if under `limit` within
  `window_ms`, or `{:wait, ms}` for how long the caller must wait before a slot
  frees up.
  """
  @spec check([non_neg_integer], non_neg_integer, pos_integer, pos_integer) ::
          :ok | {:wait, non_neg_integer}
  def check(timestamps, now, limit, window_ms) do
    in_window = Enum.filter(timestamps, fn t -> now - t < window_ms end)

    if length(in_window) < limit do
      :ok
    else
      oldest = Enum.min(in_window)
      {:wait, window_ms - (now - oldest)}
    end
  end
end
