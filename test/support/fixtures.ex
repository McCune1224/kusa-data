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
        "events" => [
          %{
            "id" => 100_000 + id,
            "numEntrants" => 32,
            "state" => 3,
            "videogame" => %{"id" => 1, "name" => "Super Smash Bros. Melee", "slug" => "melee"}
          }
        ]
      },
      overrides
    )
  end

  def tournament_search_response(nodes, total, opts \\ []) do
    total_pages = Keyword.get(opts, :total_pages, max(1, div(total + 23, 24)))

    %{
      "data" => %{
        "tournaments" => %{
          "nodes" => nodes,
          "pageInfo" => %{"total" => total, "totalPages" => total_pages}
        }
      }
    }
  end

  @doc "A start.gg videogame payload for event game identity."
  def videogame(id, slug, name, abbreviation \\ nil) do
    %{"id" => id, "name" => name, "slug" => slug, "abbreviation" => abbreviation}
  end

  @doc "Response for the `Videogames` list query."
  def games_response(games) do
    %{
      "data" => %{
        "videogames" => %{
          "nodes" => games,
          "pageInfo" => %{"total" => length(games)}
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
        "videogame" => %{"id" => 1, "name" => "Super Smash Bros. Melee", "slug" => "melee"},
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

  def player_identity_response(player_id, gamer_tag, user_id, overrides \\ %{}) do
    Map.merge(
      %{
        "data" => %{
          "player" => %{
            "id" => player_id,
            "gamerTag" => gamer_tag,
            "prefix" => nil,
            "user" => %{
              "id" => user_id,
              "name" => nil,
              "bio" => nil,
              "location" => nil,
              "images" => []
            }
          }
        }
      },
      overrides
    )
  end

  def slot(entrant_id, entrant_name, user_id, player_id \\ nil) do
    %{
      "entrant" => %{
        "id" => entrant_id,
        "name" => entrant_name,
        "participants" => [
          %{"user" => %{"id" => user_id, "player" => player_id && %{"id" => player_id}}}
        ]
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
        "event" => %{
          "id" => 100,
          "name" => "Melee Singles",
          "videogame" => %{"id" => 1, "name" => "Super Smash Bros. Melee", "slug" => "melee"}
        },
        "slots" => [
          slot(our_entrant_id, "Mango", 10, 100),
          slot(their_entrant_id, "Armada", 20, 200)
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
            "pageInfo" => %{"total" => total, "totalPages" => max(1, div(total + 39, 40))}
          }
        }
      }
    }
  end

  @doc "Raw start.gg event set node for the `EventSets` query."
  def event_set(id, winner_id, slot_ids, overrides \\ %{}) do
    Map.merge(
      %{
        "id" => id,
        "state" => 3,
        "winnerId" => winner_id,
        "displayScore" => "3 - 1",
        "fullRoundText" => "Winners Round 1",
        "completedAt" => 1_784_000_000 + id,
        "slots" =>
          Enum.map(slot_ids, fn sid ->
            %{"entrant" => %{"id" => sid, "name" => "Entrant #{sid}"}}
          end)
      },
      overrides
    )
  end

  @doc "Slot node for the `EventBracketSets` query, with an optional prereq link."
  def bracket_slot(entrant_id, name, prereq_id \\ nil) do
    %{
      "prereqId" => prereq_id,
      "entrant" => %{"id" => entrant_id, "name" => name}
    }
  end

  @doc "Raw start.gg set node for the `EventBracketSets` query."
  def bracket_set_node(id, winner_id, slots, overrides \\ %{}) do
    Map.merge(
      %{
        "id" => id,
        "state" => 3,
        "winnerId" => winner_id,
        "displayScore" => "2 - 0",
        "fullRoundText" => "Winners Round 1",
        "round" => 1,
        "completedAt" => 1_784_000_000 + id,
        "phaseGroup" => %{
          "id" => 900,
          "displayIdentifier" => "1",
          "phase" => %{"id" => 80, "name" => "Finals"}
        },
        "slots" => slots
      },
      overrides
    )
  end

  @doc "Response for the `EventPhases` query."
  def event_phases_response(event_id, phases) do
    %{
      "data" => %{
        "event" => %{
          "id" => event_id,
          "name" => "Melee Singles",
          "phases" => phases
        }
      }
    }
  end

  @doc "A phase node with phase groups given as `{id, display_identifier}` tuples."
  def phase(id, name, groups) do
    %{
      "id" => id,
      "name" => name,
      "phaseGroups" => %{
        "nodes" =>
          Enum.map(groups, fn {group_id, label} ->
            %{"id" => group_id, "displayIdentifier" => label}
          end)
      }
    }
  end

  def bracket_sets_response(sets, total_pages \\ 1) do
    %{
      "data" => %{
        "event" => %{
          "id" => 100,
          "name" => "Melee Singles",
          "sets" => %{
            "nodes" => sets,
            "pageInfo" => %{"total" => length(sets), "totalPages" => total_pages}
          }
        }
      }
    }
  end

  def event_sets_response(sets, total \\ nil) do
    total = total || length(sets)

    %{
      "data" => %{
        "event" => %{
          "id" => 100,
          "name" => "Melee Singles",
          "sets" => %{
            "nodes" => sets,
            "pageInfo" => %{"total" => total, "totalPages" => 1}
          }
        }
      }
    }
  end

  @doc "Mapped set shape as produced by `KusaData.Events.sets/1` (for engine tests)."
  def mapped_set(id, winner_id, slot_ids, score \\ "3 - 1") do
    %{
      "id" => id,
      "winner_id" => winner_id,
      "display_score" => score,
      "round" => "Winners Round 1",
      "completed_at" => 1_784_000_000 + id,
      "slots" =>
        Enum.map(slot_ids, fn sid -> %{"entrant_id" => sid, "name" => "Entrant #{sid}"} end)
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
