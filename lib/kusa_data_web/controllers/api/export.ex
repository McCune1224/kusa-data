defmodule KusaDataWeb.API.Export do
  @moduledoc """
  Shared JSON/CSV rendering for the read-only export endpoints.

  JSON returns the normalized maps the contexts already produce. CSV uses
  deterministic column order, UTF-8, and a header row. Unknown event ids or
  invalid export formats produce structured JSON errors (404/422).
  """

  import Plug.Conn

  @spec render(Plug.Conn.t(), String.t(), [String.t()], [map()]) :: Plug.Conn.t()
  def render(conn, "csv", columns, rows) do
    csv(conn, columns, rows)
  end

  def render(conn, format, _columns, rows) when format in ["json", nil] do
    json(conn, rows)
  end

  def render(conn, _format, _columns, _rows) do
    error(conn, 422, "invalid export format (use ?format=json or ?format=csv)")
  end

  @spec json(Plug.Conn.t(), term()) :: Plug.Conn.t()
  def json(conn, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(payload))
  end

  @spec csv(Plug.Conn.t(), [String.t()], [map()]) :: Plug.Conn.t()
  def csv(conn, columns, rows) do
    conn
    |> put_resp_content_type("text/csv; charset=utf-8")
    |> put_resp_header("content-disposition", "attachment; filename=#{filename(conn)}")
    |> send_resp(200, KusaData.CSV.encode(columns, Enum.map(rows, &pick(&1, columns))))
  end

  @spec error(Plug.Conn.t(), pos_integer(), String.t()) :: Plug.Conn.t()
  def error(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{"error" => message}))
  end

  defp pick(row, columns) do
    Enum.map(columns, fn column ->
      Map.get(row, column, Map.get(row, String.to_atom(column)))
    end)
  end

  defp filename(conn) do
    case conn.path_info do
      ["api", "tournaments", slug, "export"] -> "#{slug}-export.csv"
      ["api", "events", identifier, resource] -> "#{resource}-#{identifier}.csv"
      _ -> "export.csv"
    end
  end
end
