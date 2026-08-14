# Seed the known games (currently Melee only). Run with:
#
#     mix run priv/repo/seeds.exs
#
# Idempotent: existing games (by key or videogame_id) are left untouched.

alias KusaData.{Game, Repo}

defmodule KusaData.Seeds do
  def seed_games do
    games = [
      %{key: "melee", name: "Super Smash Bros. Melee", videogame_id: 1}
    ]

    Enum.each(games, fn attrs ->
      case Repo.get_by(Game, key: attrs.key) do
        nil -> Repo.insert!(Game.changeset(%Game{}, attrs))
        _game -> :ok
      end
    end)

    :ok
  end
end

KusaData.Seeds.seed_games()
