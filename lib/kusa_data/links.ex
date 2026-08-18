defmodule KusaData.Links do
  @moduledoc """
  Strict canonical parser for start.gg / smash.gg tournament links.

  Accepts:

    * full URLs: `https://www.start.gg/tournament/genesis-x/event/melee-singles`
    * scheme-less host forms: `start.gg/tournament/foo`
    * bare slugs: `tournament/foo`, `tournament/foo/event/bar`
    * optional query strings and fragments
    * trailing path segments after the tournament/event slug

  Returns `%{tournament: ..., event: ... | nil}` with canonical
  `tournament/...` slugs. Non-tournament paths, foreign hosts, and garbage are
  rejected with `:error` — no silent guessing.
  """

  @hosts ["start.gg", "www.start.gg", "smash.gg", "www.smash.gg"]
  @schemes [nil, "http", "https"]

  @type parsed :: %{tournament: String.t(), event: String.t() | nil}

  @spec parse(String.t()) :: {:ok, parsed()} | :error
  def parse(input) when is_binary(input) do
    input
    |> String.trim()
    |> URI.parse()
    |> route()
  end

  def parse(_), do: :error

  defp route(%URI{host: host, path: path} = uri) when is_binary(host) and is_binary(path) do
    if host in @hosts and uri.scheme in @schemes do
      parse_tournament_path(path)
    else
      :error
    end
  end

  defp route(%URI{scheme: nil, path: path}) when is_binary(path) do
    case String.split(path, "/", trim: true) do
      [host | _] when host in @hosts ->
        path |> String.split("/", parts: 2) |> List.last() |> parse_tournament_path()

      _ ->
        parse_tournament_path(path)
    end
  end

  defp route(_), do: :error

  defp parse_tournament_path(nil), do: :error

  defp parse_tournament_path(path) do
    case String.split(path, "/", trim: true) do
      ["tournament", slug | rest] when is_binary(slug) and slug != "" ->
        tournament = "tournament/#{slug}"

        case rest do
          ["event", event_slug | _] when is_binary(event_slug) and event_slug != "" ->
            {:ok, %{tournament: tournament, event: "#{tournament}/event/#{event_slug}"}}

          _ ->
            {:ok, %{tournament: tournament, event: nil}}
        end

      _ ->
        :error
    end
  end
end
