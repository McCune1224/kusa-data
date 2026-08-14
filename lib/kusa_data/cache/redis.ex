defmodule KusaData.Cache.Redis do
  @moduledoc """
  The Redix connection behind `KusaData.Cache`. Started under the application
  supervisor when `REDIS_URL` is configured (`:kusa_data, KusaData.Cache, :url`);
  `command/1` returns `{:error, :redis_unavailable}` when it isn't, so callers
  degrade to uncached fetches instead of crashing.
  """

  @conn KusaData.Cache.RedisConn

  @doc """
  Builds the supervised `Redix` child spec for a `redis://`-style URL.
  """
  @spec child_spec(String.t()) :: {Redix, keyword}
  def child_spec(url) do
    uri = URI.parse(url)

    opts =
      []
      |> put_if(uri.host, :host)
      |> put_if(uri.port, :port)
      |> put_userinfo(uri.userinfo)
      |> put_database(uri.path)

    {Redix, Keyword.put(opts, :name, @conn)}
  end

  defp put_if(opts, nil, _key), do: opts
  defp put_if(opts, value, key), do: Keyword.put(opts, key, value)

  defp put_userinfo(opts, nil), do: opts

  defp put_userinfo(opts, userinfo) do
    [user, pass] = String.split(userinfo, ":", parts: 2)
    opts |> Keyword.put(:username, user) |> Keyword.put(:password, pass)
  end

  defp put_database(opts, path) when path in [nil, "", "/"], do: opts
  defp put_database(opts, "/" <> db), do: Keyword.put(opts, :database, db)

  @spec command(list) :: {:ok, term} | {:error, term}
  def command(commands) do
    case Process.whereis(@conn) do
      nil -> {:error, :redis_unavailable}
      conn -> Redix.command(conn, commands)
    end
  end
end
