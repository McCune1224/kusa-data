defmodule KusaData.DataCase do
  @moduledoc "SQL sandbox case for repository-backed context tests."

  use ExUnit.CaseTemplate

  using do
    quote do
      alias KusaData.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import KusaData.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(KusaData.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
