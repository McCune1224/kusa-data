defmodule KusaData.Test.Fixtures do
  @moduledoc """
  Canned start.gg payloads for tests, shaped to match the live API
  responses the queries were verified against.
  """

  def tournament(id, overrides \\ %{}) do
    Map.merge(
      %{
        "id" => id,
        "name" => "Test Melee Weekly",
        "slug" => "tournament/test-melee-weekly",
        "city" => "Springfield",
        "addrState" => "IL",
        "countryCode" => "US",
        "startAt" => 1_784_000_000,
        "endAt" => 1_784_100_000,
        "venueName" => "The Bunker",
        "isRegistrationOpen" => true,
        "numAttendees" => 64,
        "timezone" => "America/Chicago",
        "lat" => 39.7817,
        "lng" => -89.6501,
        "events" => [%{"id" => 100_000 + id, "numEntrants" => 32}]
      },
      overrides
    )
  end

  def tournament_search_response(nodes, total) do
    %{
      "data" => %{
        "tournaments" => %{
          "nodes" => nodes,
          "pageInfo" => %{"total" => total, "totalPages" => max(1, div(total + 23, 24))}
        }
      }
    }
  end

  def tournament_detail_response(tournament) do
    %{"data" => %{"tournament" => tournament}}
  end

  def event(id, overrides \\ %{}) do
    Map.merge(
      %{
        "id" => id,
        "name" => "Melee Singles",
        "slug" => "tournament/test-melee-weekly/event/melee-singles",
        "numEntrants" => 32,
        "state" => "ACTIVE",
        "tournament" => %{
          "id" => 1,
          "name" => "Test Melee Weekly",
          "slug" => "tournament/test-melee-weekly"
        }
      },
      overrides
    )
  end

  def event_detail_response(event) do
    %{"data" => %{"event" => event}}
  end

  def entrant(id, name, seed, player_id \\ nil) do
    %{
      "id" => id,
      "name" => name,
      "seeds" => [%{"seedNum" => seed}],
      "participants" => [
        %{"user" => %{"id" => 1_000_000 + id, "player" => player_id && %{"id" => player_id}}}
      ]
    }
  end

  def seeding_response(entrants, total \\ nil) do
    total = total || length(entrants)

    %{
      "data" => %{
        "event" => %{
          "id" => 100,
          "name" => "Melee Singles",
          "entrants" => %{
            "nodes" => entrants,
            "pageInfo" => %{"total" => total, "totalPages" => 1}
          }
        }
      }
    }
  end

  def standing(id, name, placement, player_id \\ nil) do
    %{
      "placement" => placement,
      "entrant" => %{
        "id" => id,
        "name" => name,
        "participants" => [
          %{"user" => %{"id" => 1_000_000 + id, "player" => player_id && %{"id" => player_id}}}
        ]
      }
    }
  end

  def results_response(standings) do
    %{
      "data" => %{
        "event" => %{
          "id" => 100,
          "name" => "Melee Singles",
          "standings" => %{
            "nodes" => standings,
            "pageInfo" => %{"total" => length(standings), "totalPages" => 1}
          }
        }
      }
    }
  end

  def player_identity_response(player_id, gamer_tag, user_id) do
    %{
      "data" => %{
        "player" => %{"id" => player_id, "gamerTag" => gamer_tag, "user" => %{"id" => user_id}}
      }
    }
  end

  def slot(entrant_id, entrant_name, user_id) do
    %{
      "entrant" => %{
        "id" => entrant_id,
        "name" => entrant_name,
        "participants" => [%{"user" => %{"id" => user_id}}]
      }
    }
  end

  def set(
        id,
        our_entrant_id,
        their_entrant_id,
        winner_entrant_id,
        overrides \\ %{}
      ) do
    Map.merge(
      %{
        "id" => id,
        "state" => 3,
        "displayScore" => "3 - 1",
        "fullRoundText" => "Winners Round 1",
        "completedAt" => 1_784_000_000 + id,
        "event" => %{"id" => 100, "name" => "Melee Singles"},
        "slots" => [
          slot(our_entrant_id, "Mango", 10),
          slot(their_entrant_id, "Armada", 20)
        ],
        "games" => [
          %{
            "winnerId" => winner_entrant_id,
            "stage" => %{"id" => 1, "name" => "Battlefield"},
            "selections" => [
              %{
                "entrant" => %{"id" => our_entrant_id},
                "selectionType" => "CHARACTER",
                "character" => %{"id" => 12, "name" => "Luigi"}
              },
              %{
                "entrant" => %{"id" => their_entrant_id},
                "selectionType" => "CHARACTER",
                "character" => %{"id" => 14, "name" => "Marth"}
              }
            ]
          }
        ],
        "winnerId" => winner_entrant_id
      },
      overrides
    )
  end

  def player_sets_response(sets, total \\ nil) do
    total = total || length(sets)

    %{
      "data" => %{
        "player" => %{
          "id" => 1,
          "gamerTag" => "Mango",
          "sets" => %{
            "nodes" => sets,
            "pageInfo" => %{"total" => total, "totalPages" => max(1, div(total + 49, 50))}
          }
        }
      }
    }
  end

  def zippopotam_response(lat, lng, city, state) do
    %{
      "post code" => "60614",
      "country abbreviation" => "US",
      "places" => [
        %{
          "place name" => city,
          "state abbreviation" => state,
          "latitude" => "#{lat}",
          "longitude" => "#{lng}"
        }
      ]
    }
  end

  def open_meteo_response(lat, lng, city, country) do
    %{
      "results" => [
        %{"name" => city, "latitude" => lat, "longitude" => lng, "country_code" => country}
      ]
    }
  end
end
