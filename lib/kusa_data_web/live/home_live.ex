defmodule KusaDataWeb.HomeLive do
  use KusaDataWeb, :live_view

  alias KusaData.Links
  alias KusaData.Tournaments

  @default_radius "50mi"
  @radii ~w(25mi 50mi 100mi 200mi)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       nav: :tournaments,
       mode: :upcoming,
       q: nil,
       from: nil,
       to: nil,
       results_only: false,
       zip: nil,
       radius: @default_radius,
       game: nil,
       place: nil,
       total: 0,
       next_page: nil,
       error: nil,
       loading: true,
       page: 1,
       radii: @radii,
       known_games: KusaData.Games.all()
     )
     |> assign_forms()
     |> stream_configure(:tournaments, dom_id: fn t -> "tournament-#{t["id"]}" end)
     |> stream(:tournaments, [])}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    mode = mode_from(params)
    zip = blank_to_nil(params["zip"])
    radius = params["radius"] || @default_radius
    q = blank_to_nil(params["q"])
    from = valid_iso_or_nil(params["from"])
    to = valid_iso_or_nil(params["to"])
    results_only = params["results_only"] in [true, "true", "1"]
    game = valid_game(params["game"])

    socket =
      socket
      |> assign(
        mode: mode,
        zip: zip,
        radius: radius,
        q: q,
        from: from,
        to: to,
        results_only: results_only,
        game: game,
        place: nil,
        loading: true,
        page: 1,
        next_page: nil
      )
      |> assign_forms()
      |> spawn_load(1, true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_result, ref, result}, %{assigns: %{load_ref: ref}} = socket) do
    page = socket.assigns.page
    reset = socket.assigns.reset

    socket =
      case result do
        {:ok, data, _status} ->
          socket =
            socket
            |> assign(error: nil, loading: false)
            |> assign(total: data["total"], next_page: next_page(page, data["total"]))

          socket
          |> assign(place: Map.get(data, "place"))
          |> stream(:tournaments, data["tournaments"], reset: reset)

        {:error, reason} ->
          socket
          |> assign(total: 0, next_page: nil, error: reason, loading: false)
          |> stream(:tournaments, [], reset: true)
      end

    {:noreply, assign(socket, load_ref: nil)}
  end

  def handle_info({:load_result, _ref, _result}, socket) do
    {:noreply, socket}
  end

  defp spawn_load(socket, page, reset) do
    ref = make_ref()
    parent = self()
    query = build_query(socket.assigns, page)

    Task.start(fn ->
      send(parent, {:load_result, ref, Tournaments.browse(query)})
    end)

    assign(socket, load_ref: ref, page: page, reset: reset)
  end

  defp build_query(assigns, page) do
    base = %{page: page, games: games_param(assigns.game)}

    case assigns.mode do
      :upcoming ->
        Map.merge(base, %{mode: :upcoming, zip: assigns.zip, radius: assigns.radius})

      :past ->
        Map.merge(base, %{
          mode: :past,
          from: assigns.from,
          to: assigns.to,
          q: assigns.q,
          results_only: assigns.results_only
        })

      :search ->
        Map.merge(base, %{mode: :search, q: assigns.q})
    end
  end

  # nil means the backend default (Melee); "all" widens to every game.
  defp games_param(nil), do: nil
  defp games_param("all"), do: :all
  defp games_param(slug), do: slug

  defp valid_game(nil), do: nil
  defp valid_game("all"), do: "all"

  defp valid_game(slug) when is_binary(slug) do
    if KusaData.Games.by_slug(slug), do: slug, else: nil
  end

  defp valid_game(_), do: nil

  defp next_page(page, total) do
    if page * 24 < total, do: page + 1, else: nil
  end

  @impl true
  def handle_event("nearby-search", %{"zip" => zip, "radius" => radius}, socket) do
    zip = String.trim(zip)

    if zip == "" do
      {:noreply, push_patch(socket, to: browse_path(:upcoming, []))}
    else
      {:noreply, push_patch(socket, to: browse_path(:upcoming, zip: zip, radius: radius))}
    end
  end

  @impl true
  def handle_event("radius-change", %{"radius" => radius}, socket) do
    form = to_form(%{"zip" => input_value(socket.assigns.nearby_form, :zip), "radius" => radius})
    {:noreply, assign(socket, nearby_form: form)}
  end

  @impl true
  def handle_event(
        "past-search",
        %{"from" => from, "to" => to, "q" => q, "results_only" => ro},
        socket
      ) do
    from = valid_iso_or_nil(from)
    to = valid_iso_or_nil(to)
    q = blank_to_nil(q)
    results_only = ro in [true, "true", "1"]

    {:noreply,
     push_patch(socket,
       to:
         browse_path(:past,
           from: from,
           to: to,
           q: q,
           results_only: results_only
         )
     )}
  end

  @impl true
  def handle_event("search-input", %{"q" => q}, socket) do
    q = blank_to_nil(q)
    {:noreply, push_patch(socket, to: browse_path(:search, q: q))}
  end

  @impl true
  def handle_event("link-jump", %{"link" => link}, socket) do
    case Links.parse(link) do
      {:ok, %{event: event}} when event != nil ->
        {:noreply, push_navigate(socket, to: ~p"/event/#{event}")}

      {:ok, %{tournament: tournament}} ->
        {:noreply, push_navigate(socket, to: ~p"/tournament/#{bare_slug(tournament)}")}

      :error ->
        {:noreply, put_flash(socket, :error, "That is not a start.gg link")}
    end
  end

  @impl true
  def handle_event("load-more", _params, socket) do
    page = socket.assigns.next_page

    if page do
      {:noreply, spawn_load(socket, page, false)}
    else
      {:noreply, socket}
    end
  end

  defp assign_forms(socket) do
    assigns = socket.assigns

    assign(socket,
      nearby_form:
        to_form(%{
          "zip" => assigns.zip || "",
          "radius" => assigns.radius || @default_radius
        }),
      past_form:
        to_form(%{
          "from" => assigns.from || "",
          "to" => assigns.to || "",
          "q" => assigns.q || "",
          "results_only" => if(assigns.results_only, do: "true", else: "false")
        }),
      search_form: to_form(%{"q" => assigns.q || ""}),
      link_form: to_form(%{"link" => ""})
    )
  end

  defp mode_from(%{"mode" => "past"}), do: :past
  defp mode_from(%{"mode" => "search"}), do: :search
  defp mode_from(_), do: :upcoming

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp valid_iso_or_nil(nil), do: nil

  defp valid_iso_or_nil(value) do
    case Date.from_iso8601(value) do
      {:ok, _date} -> value
      _ -> nil
    end
  end

  defp browse_path(mode, params) do
    params =
      if mode == :upcoming do
        params
      else
        [{:mode, mode} | params]
      end

    query =
      params
      |> Enum.reject(fn {_k, v} -> v in [nil, ""] end)
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode_www_form(to_string(v))}" end)
      |> Enum.join("&")

    if query == "", do: "/", else: "/?" <> query
  end

  defp input_value(form, field) do
    Phoenix.HTML.Form.input_value(form, field) || ""
  end

  defp place_city(nil), do: "you"
  defp place_city(%{"city" => nil}), do: "you"
  defp place_city(%{"city" => city}), do: city

  defp format_count(0), do: "No events"
  defp format_count(1), do: "1 event"
  defp format_count(total), do: "#{total} events"

  defp mode_title(:upcoming), do: "Upcoming tournaments"
  defp mode_title(:past), do: "Past tournaments"
  defp mode_title(:search), do: "Tournament search"

  defp game_chip_path(%{mode: :upcoming} = assigns, game),
    do: browse_path(:upcoming, zip: assigns.zip, radius: assigns.radius, game: game)

  defp game_chip_path(%{mode: :past} = assigns, game),
    do:
      browse_path(
        :past,
        from: assigns.from,
        to: assigns.to,
        q: assigns.q,
        results_only: assigns.results_only && "true",
        game: game
      )

  defp game_chip_path(%{mode: :search} = assigns, game),
    do: browse_path(:search, q: assigns.q, game: game)

  # The Melee backend default renders as no explicit param.
  defp active_game?(game, nil), do: game == KusaData.Games.default().slug
  defp active_game?(game, current), do: game == current

  defp game_label(nil), do: nil

  defp game_label("all"), do: "all games"

  defp game_label(slug) do
    case KusaData.Games.by_slug(slug) do
      %{short_name: name} -> name
      nil -> slug
    end
  end

  defp mode_subtitle(%{mode: :upcoming, zip: zip, place: place}) when zip != nil,
    do: "Melee near #{place_city(place)}"

  defp mode_subtitle(%{mode: :upcoming}), do: "Melee worldwide, next up first"

  defp mode_subtitle(%{mode: :past, from: from, to: to}) when from != nil and to != nil,
    do: "#{from} → #{to}"

  defp mode_subtitle(%{mode: :past, from: from}) when from != nil, do: "from #{from} onward"
  defp mode_subtitle(%{mode: :past}), do: "Finished brackets, newest first"
  defp mode_subtitle(%{mode: :search, q: q}) when q != nil, do: "matching “#{q}”"
  defp mode_subtitle(%{mode: :search}), do: "type to search the archive"

  defp empty_hint(%{mode: :search}), do: " — try a different name, city, or venue"
  defp empty_hint(%{mode: :past}), do: " — try widening the date range"

  defp empty_hint(%{mode: :upcoming, error: :not_found}),
    do: " — double-check the postal code and try again"

  defp empty_hint(%{mode: :upcoming}),
    do: " — try widening the radius or the start.gg API may be unhappy"

  defp tab_class(active?) do
    base =
      "flex items-center gap-1.5 px-4 py-2 text-sm font-medium transition-colors rounded-none"

    if active? do
      "#{base} bg-lime-400 text-stone-950"
    else
      "#{base} text-stone-400 hover:bg-stone-800/60 hover:text-stone-100"
    end
  end

  defp quick_ranges do
    today = Date.utc_today()
    this_month = Date.beginning_of_month(today)
    last_month = Date.add(this_month, -1) |> Date.beginning_of_month()
    three_months = Date.add(this_month, -3) |> Date.beginning_of_month()

    [
      {"This month", Date.to_iso8601(this_month), Date.to_iso8601(today)},
      {"Last month", Date.to_iso8601(last_month), Date.to_iso8601(Date.add(this_month, -1))},
      {"Last 3 months", Date.to_iso8601(three_months), Date.to_iso8601(today)}
    ]
  end
end
