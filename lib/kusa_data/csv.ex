defmodule KusaData.CSV do
  @moduledoc """
  Minimal RFC-4180-style CSV writer with deterministic column order and a
  header row. Values are escaped only when necessary (comma, quote, CR/LF);
  `nil` renders as an empty field. Used by the JSON/CSV export endpoints.
  """

  @spec encode([atom() | String.t()], [[term()]]) :: String.t()
  def encode(columns, rows) do
    [escape_row(columns) | Enum.map(rows, &escape_row/1)]
    |> Enum.join("\r\n")
  end

  defp escape_row(row) do
    Enum.map_join(row, ",", &escape_field/1)
  end

  defp escape_field(nil), do: ""
  defp escape_field(value) when is_integer(value), do: Integer.to_string(value)
  defp escape_field(value) when is_float(value), do: Float.to_string(value)
  defp escape_field(value) when is_boolean(value), do: if(value, do: "true", else: "false")
  defp escape_field(value) when is_atom(value), do: Atom.to_string(value)

  defp escape_field(value) when is_binary(value) do
    if String.match?(value, ~r/[",\r\n]/) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
end
