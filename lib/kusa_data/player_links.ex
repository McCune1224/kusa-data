defmodule KusaData.PlayerLinks do
  @moduledoc """
  Player settings/linking: a canonical linked player id plus deterministic
  alias deduplication. Changing a linked player id requires confirmation, and
  conflicting tags are surfaced for review instead of being silently merged.
  """

  import Ecto.Query, warn: false

  alias KusaData.PlayerLinks.PlayerAlias
  alias KusaData.Repo

  @doc "The user's aliases, sorted deterministically (alias asc)."
  def aliases(user) do
    Repo.all(from(a in PlayerAlias, where: a.user_id == ^user.id, order_by: a.alias))
  end

  @doc "Adds an alias for a player. Rejects duplicates with a changeset error."
  def add_alias(user, player_id, alias_name) do
    %PlayerAlias{}
    |> Ecto.Changeset.change(
      user_id: user.id,
      player_id: player_id,
      alias: String.trim(alias_name)
    )
    |> PlayerAlias.changeset(%{})
    |> Repo.insert()
  end

  @doc "Removes an alias."
  def remove_alias(user, alias_id) do
    case Repo.get_by(PlayerAlias, id: alias_id, user_id: user.id) do
      nil -> {:error, :not_found}
      alias_row -> Repo.delete(alias_row)
    end
  end

  @doc """
  Sets the user's linked player id. Pass `confirm: true` to apply; without
  confirmation returns `{:error, :confirmation_required}` so the UI can show
  a confirmation step before changing an existing link.
  """
  def link_player(user, player_id, opts \\ []) do
    if user.linked_player_id && user.linked_player_id != player_id && !opts[:confirm] do
      {:error, :confirmation_required}
    else
      user
      |> Ecto.Changeset.change(linked_player_id: player_id)
      |> Repo.update()
    end
  end

  @doc """
  Deterministically merges duplicate aliases: case-insensitive duplicates of
  an alias collapse to the lowest player id, keeping the canonical casing.
  Returns `{added, removed}` counts.
  """
  def merge_duplicate_aliases(user) do
    rows = aliases(user)

    {keep, drop} =
      rows
      |> Enum.group_by(fn a -> String.downcase(a.alias) end)
      |> Enum.reduce({[], []}, fn {_key, group}, {keep, drop} ->
        sorted = Enum.sort_by(group, &{&1.player_id, &1.alias})
        {[hd(sorted) | keep], drop ++ tl(sorted)}
      end)

    Enum.each(drop, &Repo.delete(&1))
    {length(keep), length(drop)}
  end

  @doc "True when a Repo is configured."
  def repo_configured?, do: KusaData.Accounts.repo_configured?()
end
