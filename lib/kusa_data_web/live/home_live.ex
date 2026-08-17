defmodule KusaDataWeb.HomeLive do
  use KusaDataWeb, :live_view

  alias KusaData.Links
  alias KusaData.Tournaments

  @default_radius "50mi"
  @radii ~w(25mi 50mi 100mi 200mi)

  @impl true
  def mount(_params, _session, socket) do
    form = to_form(%{"zip" => "", "radius" => @default_radius})
    link_form = to_form(%{"link" => ""})

    {:ok,
     socket
     |> assign(
       nav: :tournaments,
       form: form,
       link_form: link_form,
       mode: :upcoming,
       place: nil,
       total: 0,
       next_page: nil,
       zip: nil,
       radius: @default_radius,
       error: nil,
       loading: true,
       page: 1,
       radii: @radii
     )
     |> stream_configure(:tournaments, dom_id: fn t -> "tournament-#{t["id"]}" end)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    zip = params["zip"] && String.trim(params["zip"])
    radius = params["radius"] || @default_radius

    socket =
      assign(socket,
        mode: if(zip in [nil, ""], do: :upcoming, else: :nearby),
        zip: zip,
        radius: radius,
        loading: true,
        page: 1,
        next_page: nil
      )

    socket = spawn_load(socket, zip, radius, 1, true)
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

          case socket.assigns.mode do
            :upcoming ->
              socket
              |> assign(place: nil)
              |> stream(:tournaments, data["tournaments"], reset: reset)

            :nearby ->
              socket
              |> assign(place: Map.get(data, "place"))
              |> stream(:tournaments, data["tournaments"], reset: reset)
          end

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

  defp spawn_load(socket, zip, radius, page, reset) do
    ref = make_ref()
    parent = self()

    Task.start(fn ->
      send(parent, {:load_result, ref, load_page(zip, radius, page)})
    end)

    assign(socket, load_ref: ref, page: page, reset: reset)
  end

  defp load_page(zip, radius, page) do
    if zip in [nil, ""] do
      Tournaments.upcoming(page)
    else
      Tournaments.nearby(zip, radius, page)
    end
  end

  defp next_page(page, total) do
    if page * 24 < total, do: page + 1, else: nil
  end

  @impl true
  def handle_event("nearby-search", %{"zip" => zip, "radius" => radius}, socket) do
    zip = String.trim(zip)

    if zip == "" do
      {:noreply,
       socket
       |> push_patch(to: ~p"/")
       |> assign(form: to_form(%{"zip" => "", "radius" => radius}))}
    else
      {:noreply, push_patch(socket, to: ~p"/?zip=#{zip}&radius=#{radius}")}
    end
  end

  @impl true
  def handle_event("radius-change", %{"radius" => radius}, socket) do
    form = to_form(%{"zip" => input_value(socket.assigns.form, :zip), "radius" => radius})
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("link-jump", %{"link" => link}, socket) do
    case Links.parse(link) do
      {:ok, %{event: event}} when event != nil ->
        {:noreply, push_navigate(socket, to: ~p"/event/#{event}")}

      {:ok, %{tournament: tournament}} ->
        {:noreply, push_navigate(socket, to: ~p"/tournament/#{bare_slug(tournament)}")}

      :error ->
        {:noreply, put_flash(socket, :error, "That doesn't look like a start.gg link")}
    end
  end

  @impl true
  def handle_event("load-more", _params, socket) do
    page = socket.assigns.next_page

    if page do
      socket = spawn_load(socket, socket.assigns.zip, socket.assigns.radius, page, false)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp input_value(form, field) do
    Phoenix.HTML.Form.input_value(form, field) || ""
  end

  defp place_city(nil), do: "you"
  defp place_city(%{"city" => nil}), do: "you"
  defp place_city(%{"city" => city}), do: city

  defp radius_label(:upcoming, _radius), do: "worldwide"
  defp radius_label(:nearby, radius), do: "within #{radius}"

  defp format_count(0), do: "No events"
  defp format_count(1), do: "1 event"
  defp format_count(total), do: "#{total} events"

  defp event_count(tournament), do: length(tournament["events"] || [])

  defp plural(1), do: ""
  defp plural(_), do: "s"

  defp date_badge(tournament) do
    timezone = tournament["timezone"] || "UTC"

    case tournament["startAt"] do
      nil -> "TBA"
      unix -> short_date(unix, timezone)
    end
  end

  defp location_label(tournament) do
    city = tournament["city"]
    state = tournament["addrState"]
    country = tournament["countryCode"]

    cond do
      city && state -> "#{city}, #{state}"
      city -> city
      state -> state
      country -> country
      true -> "online"
    end
  end

  defp no_results_hint(nil), do: ""
  defp no_results_hint(:not_found), do: " — double-check the postal code and try again"
  defp no_results_hint(_), do: " — try widening the radius or the start.gg API may be unhappy"
end
