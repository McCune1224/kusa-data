defmodule KusaData.Crawl.WorkerTest do
  use KusaData.DataCase, async: false

  alias KusaData.Crawl.Worker
  alias KusaData.Game

  setup do
    Application.put_env(:kusa_data, KusaData.GraphQL.RateLimiter,
      limit: 100_000,
      window_ms: 60_000
    )

    Application.put_env(:kusa_data, KusaData.Crawl, request_delay_ms: 0)

    # The slice runs in the background; pointing at a dead port guarantees a
    # fast failed request, which is all these queue-semantics tests need.
    Application.put_env(:kusa_data, KusaData.GraphQL.Client,
      endpoint: "http://127.0.0.1:1/graphql",
      token: "test-token"
    )

    :ok
  end

  defp put_game do
    Repo.insert!(%Game{key: "melee", name: "Melee", videogame_id: 1})
  end

  test "enqueues a crawl slice", %{} do
    game = put_game()
    worker = start_supervised!({Worker, name: :crawl_worker_accept_1}, restart: :temporary)
    assert {:ok, :enqueued} = Worker.perform(worker, game.id)
  end

  test "dedupes an already-queued game while it is running", %{} do
    game = put_game()
    worker = start_supervised!({Worker, name: :crawl_worker_dedupe_1}, restart: :temporary)

    assert {:ok, :enqueued} = Worker.perform(worker, game.id)
    assert {:error, :already_enqueued} = Worker.perform(worker, game.id)
  end
end
