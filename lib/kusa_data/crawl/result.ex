defmodule KusaData.Crawl.Result do
  @moduledoc "Outcome of one crawl slice."

  defstruct tournaments: 0, sets_applied: 0, skipped_tournaments: 0, players: 0

  @type t :: %__MODULE__{
          tournaments: non_neg_integer,
          sets_applied: non_neg_integer,
          skipped_tournaments: non_neg_integer,
          players: non_neg_integer
        }
end
