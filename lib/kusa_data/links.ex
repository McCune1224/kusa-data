defmodule KusaData.Links do
  @moduledoc """
  Parses start.gg tournament/event URLs or bare slugs into canonical slugs.

  Accepts:

    * `https://www.start.gg/tournament/genesis-x/event/melee-singles`
    * `start.gg/tournament/foo` (no scheme, optional trailing bits)
    * bare slugs: `tournament/foo`, `tournament/foo/event/bar`
    * the legacy `smash.gg` host
  """

  @hosts ["start.gg", "www.start.gg", "smash.gg", "www.smash.gg"]

  @type parsed :: %{tournament: String.t(), event: String.t() | nil}

  @spec parse(String.t()) :: {:ok, parsed()} | :error
  def parse(input) do
    input
    |> String.trim()
    |> strip_scheme_and_host()
    |> String.trim("/")
    |> String.split("?", parts: 2)
    |> hd()
    |> String.trim("/")
    |> slugify()
  end

  defp strip_scheme_and_host(input) do
    case URI.parse(input) do
      %URI{host: host, path: path} when host in @hosts -> path || ""
      _ -> input
    end
  end

  defp slugify(""), do: :error

  defp slugify("tournament/" <> rest) do
    case String.split(rest, "/") do
      [tournament, "event", event | _] ->
        {:ok,
         %{
           tournament: "tournament/#{tournament}",
           event: "tournament/#{tournament}/event/#{event}"
         }}

      [tournament | _] ->
        {:ok, %{tournament: "tournament/#{tournament}", event: nil}}
    end
  end

  defp slugify(_), do: :error
end
