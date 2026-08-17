defmodule KusaData.Redis do
  @moduledoc """
  Supervised Redix connection behind the cache layer.

  Started with the application only when `REDIS_URL` is configured
  (`:kusa_data, KusaData.Cache, :url`). `command/1` returns
  `{:error, :redis_unavailable}` when no connection is running so callers can
  degrade to uncached fetches instead of crashing.
  """

  @conn KusaData.Redis.Conn

  @doc "Builds a supervised Redix child spec from a `redis://`-style URL."
  @spec child_spec(String.t()) :: {Redix, keyword()}
  def child_spec(url) do
    uri = URI.parse(url)

    opts =
      []
      |> put_host(uri.host)
      |> put_port(uri.port)
      |> put_userinfo(uri.userinfo)
      |> put_database(uri.path)

    {Redix, Keyword.put(opts, :name, @conn)}
  end

  defp put_host(opts, nil), do: opts
  defp put_host(opts, host), do: Keyword.put(opts, :host, host)

  defp put_port(opts, nil), do: opts
  defp put_port(opts, port), do: Keyword.put(opts, :port, port)

  defp put_userinfo(opts, nil), do: opts

  defp put_userinfo(opts, userinfo) do
    [user, pass] = String.split(userinfo, ":", parts: 2)
    opts |> Keyword.put(:username, user) |> Keyword.put(:password, pass)
  end

  defp put_database(opts, path) when path in [nil, "", "/"], do: opts
  defp put_database(opts, "/" <> db), do: Keyword.put(opts, :database, db)

  @spec command(list()) :: {:ok, term()} | {:error, term()}
  def command(commands) do
    case Process.whereis(@conn) do
      nil -> {:error, :redis_unavailable}
      conn -> Redix.command(conn, commands)
    end
  end
end
