defmodule KusaData.Test.Doubles do
  @moduledoc """
  Shared setup for starting the in-memory test doubles.
  """

  import ExUnit.Callbacks

  defmacro __using__(_opts) do
    quote do
      setup do
        start_supervised!(KusaData.Test.FakeTransport)
        start_supervised!(KusaData.Test.FakeRedis)
        :ok
      end
    end
  end
end
