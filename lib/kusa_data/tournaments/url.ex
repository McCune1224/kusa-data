defmodule KusaData.Tournaments.Url do
  @moduledoc """
  Normalizes pasted start.gg URLs into tournament/event slugs. Pure.

  Accepts `start.gg` and `www.start.gg` hosts, with or without a scheme,
  and every common trailing segment (`details`, `standings`, `brackets`, …).
  Returns `%{tournament_slug: String.t(), event_slug: String.t() | nil,
  canonical: String.t()}` or `nil` for anything else.
  """

  @recognized_trailing ~w(details standings seeding schedule sets results streams rules players attendees brackets)

  @type normalized :: %{
          tournament_slug: String.t(),
          event_slug: String.t() | nil,
          canonical: String.t()
        }

  @spec normalize(String.t()) :: normalized | nil
  def normalize(value) do
    with uri when not is_nil(uri) <- parse(value),
         true <- valid_host?(uri),
         [_, slug | suffix] <- path_segments(uri),
         true <- slug != "",
         {:ok, event_slug, trailing} <- split_suffix(suffix),
         true <- valid_trailing?(trailing) do
      %{
        tournament_slug: slug,
        event_slug: event_slug,
        canonical: canonical(slug, event_slug)
      }
    else
      _ -> nil
    end
  end

  defp parse(value) do
    input = String.trim(value)
    if input == "", do: nil, else: URI.parse((has_scheme?(input) && input) || "https://" <> input)
  end

  defp has_scheme?(value), do: Regex.match?(~r/^[a-z][a-z\d+.-]*:\/\//i, value)

  defp valid_host?(%URI{host: host, scheme: scheme}) do
    scheme in ["http", "https"] and host in ["start.gg", "www.start.gg"]
  end

  defp path_segments(%URI{path: path}) do
    path
    |> String.split("/", trim: true)
    |> case do
      ["tournament" | rest] -> ["tournament" | rest]
      _ -> []
    end
  end

  # After the slug: [] | ["events" | rest] | ["event", event_slug | rest] | rest
  defp split_suffix([]), do: {:ok, nil, []}

  defp split_suffix(["events" | rest]), do: {:ok, nil, rest}

  defp split_suffix(["event", event_slug | rest]) do
    if event_slug == "", do: :error, else: {:ok, event_slug, rest}
  end

  defp split_suffix(rest), do: {:ok, nil, rest}

  defp valid_trailing?([]), do: true

  defp valid_trailing?([head | _]), do: head in @recognized_trailing

  defp canonical(slug, nil), do: "https://www.start.gg/tournament/#{slug}"

  defp canonical(slug, event_slug),
    do: "https://www.start.gg/tournament/#{slug}/event/#{event_slug}"
end
