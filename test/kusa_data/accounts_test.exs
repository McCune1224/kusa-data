defmodule KusaData.AccountsTest do
  use KusaData.DataCase, async: false
  use KusaData.Test.Doubles
  alias KusaData.Accounts
  alias KusaData.Accounts.User
  alias KusaData.Bookmarks
  alias KusaData.Leagues
  alias KusaData.PlayerLinks
  alias KusaData.Repo
  alias KusaData.Test.FakeTransport

  defp user(email \\ "player@example.com") do
    {:ok, user} = Accounts.register_user(%{email: email, password: "correct horse battery"})
    user
  end

  test "registers, authenticates, creates renewable sessions, and logs out" do
    user = user("UPPER@example.com")
    assert user.email == "upper@example.com"

    assert {:ok, authenticated} =
             Accounts.authenticate_by_email_password("UPPER@example.com", "correct horse battery")

    assert authenticated.id == user.id

    assert {:ok, _session, token} = Accounts.create_session(user)
    assert Accounts.get_user_by_session_token(token).id == user.id
    assert :ok = Accounts.delete_session(token)
    assert Accounts.get_user_by_session_token(token) == nil
  end

  test "reset tokens are one-use and expire" do
    user = user()
    assert {:ok, token} = Accounts.generate_reset_token(user)
    assert {:ok, updated} = Accounts.reset_password(token, "new password works")
    assert User.valid_password?(updated, "new password works")
    assert {:error, :expired_or_invalid} = Accounts.reset_password(token, "another password")

    user = Repo.get!(User, user.id)
    assert {:ok, expired_token} = Accounts.generate_reset_token(user)
    expired = DateTime.add(DateTime.utc_now(), -901, :second)
    Repo.update_all(from(u in User, where: u.id == ^user.id), set: [reset_sent_at: expired])

    assert {:error, :expired_or_invalid} =
             Accounts.reset_password(expired_token, "new password works")
  end

  test "bookmarks are idempotent and scoped to the user" do
    user = user()
    assert {:ok, first} = Bookmarks.bookmark(user, "tournament/genesis", %{"name" => "Genesis"})
    assert {:ok, second} = Bookmarks.bookmark(user, "tournament/genesis", %{"name" => "Changed"})
    assert first.id == second.id
    assert length(Bookmarks.for_user(user)) == 1
    assert Bookmarks.bookmarked?(user, "tournament/genesis")
    assert :ok = Bookmarks.unbookmark(user, "tournament/genesis")
    refute Bookmarks.bookmarked?(user, "tournament/genesis")
  end

  test "aliases require deterministic review before changing linked player" do
    user = user()
    assert {:ok, _} = PlayerLinks.link_player(user, 100)

    assert {:error, :confirmation_required} =
             PlayerLinks.link_player(Repo.get!(User, user.id), 200)

    assert {:ok, _} = PlayerLinks.link_player(Repo.get!(User, user.id), 200, confirm: true)
    assert {:ok, _} = PlayerLinks.add_alias(user, 200, "Mango")
    assert {:ok, _} = PlayerLinks.add_alias(user, 100, "mango")
    assert {1, 1} = PlayerLinks.merge_duplicate_aliases(Repo.get!(User, user.id))
    assert Enum.map(PlayerLinks.aliases(user), & &1.player_id) == [100]
  end

  test "league seasons validate their window and owner permissions" do
    user = user()
    assert {:ok, league} = Leagues.create_league(user, %{name: "Local Circuit"})
    assert {:ok, member} = Leagues.add_member(league, 100, "Mango")
    assert member.player_id == 100

    assert {:ok, season} =
             Leagues.create_season(league, %{
               name: "Spring",
               start_at: ~U[2026-01-01 00:00:00Z],
               end_at: ~U[2026-03-01 00:00:00Z]
             })

    assert season.name == "Spring"

    assert {:error, changeset} =
             Leagues.create_season(league, %{
               name: "Broken",
               start_at: ~U[2026-03-01 00:00:00Z],
               end_at: ~U[2026-01-01 00:00:00Z]
             })

    assert Keyword.has_key?(changeset.errors, :end_at)
  end

  test "league import auto-links ids and reports unresolved tags" do
    user = user("league-import@example.com")
    assert {:ok, league} = Leagues.create_league(user, %{name: "Import League"})

    tournament =
      KusaData.Test.Fixtures.tournament(4, %{
        "slug" => "tournament/import-test",
        "events" => [KusaData.Test.Fixtures.event(100)]
      })

    FakeTransport.put(
      :query,
      "TournamentDetail",
      KusaData.Test.Fixtures.tournament_detail_response(tournament)
    )

    FakeTransport.put(
      :query,
      "EventDetail",
      KusaData.Test.Fixtures.event_detail_response(KusaData.Test.Fixtures.event(100))
    )

    FakeTransport.put(
      :query,
      "EventSeeding",
      KusaData.Test.Fixtures.seeding_response([
        KusaData.Test.Fixtures.entrant(1, "Unknown Tag", 1),
        KusaData.Test.Fixtures.entrant(2, "Known Tag", 2, 100)
      ])
    )

    FakeTransport.put(
      :query,
      "EventResults",
      KusaData.Test.Fixtures.results_response([
        KusaData.Test.Fixtures.standing(1, "Unknown Tag", 1),
        KusaData.Test.Fixtures.standing(2, "Known Tag", 2, 100)
      ])
    )

    FakeTransport.put(:query, "EventSets", KusaData.Test.Fixtures.event_sets_response([]))

    assert {:ok, result} = Leagues.import_tournament_with_links(league, "tournament/import-test")
    assert result["added"] == 1
    assert result["unresolved"] == ["Unknown Tag"]
    assert result["conflicts"] == 0
  end
end
