defmodule KusaData.GraphQL.SetDetails do
  @moduledoc """
  Hand-written query builders for on-demand set detail fetches — the game-level
  data (stages, character selections, per-game scores) intentionally **not**
  stored in Postgres. Callers paginate with small pages: each set expands into
  several games and selections, which counts against the start.gg 1000-object
  response budget.
  """

  @doc """
  Returns `{document, variables}` for one page of a player's sets, including
  event context, slots (entrant + user identity) and games with stage and
  character selections. `player_id` is the start.gg **player** id (not user id).
  """
  @spec player_sets_query(non_neg_integer, pos_integer, pos_integer) :: {String.t(), map}
  def player_sets_query(player_id, page, per_page) do
    {"""
     query PlayerSets($playerId: ID!, $page: Int!, $perPage: Int!) {
       player(id: $playerId) {
         id
         gamerTag
         sets(page: $page, perPage: $perPage) {
           nodes {
             id
             state
             displayScore
             fullRoundText
             completedAt
             event {
               id
               name
             }
             slots {
               entrant {
                 id
                 name
                 participants {
                   user {
                     id
                   }
                 }
               }
             }
             games {
               orderNum
               winnerId
               entrant1Score
               entrant2Score
               stage {
                 id
                 name
               }
               selections {
                 entrant {
                   id
                 }
                 selectionType
                 character {
                   id
                   name
                 }
               }
             }
           }
           pageInfo {
             total
             totalPages
           }
         }
       }
     }
     """, %{playerId: player_id, page: page, perPage: per_page}}
  end
end
