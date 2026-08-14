defmodule KusaDataWeb.Kit do
  @moduledoc """
  The single component kit — every page uses these primitives, never ad-hoc
  styling. Built on the design tokens in `assets/css/app.css` (paper palette,
  one accent). Every surface supports loading / empty / error states via
  `loading/1` and `empty_state/1`.
  """

  use Phoenix.Component
  import KusaDataWeb.CoreComponents, only: [icon: 1]

  @doc """
  A bordered surface for grouping content.

  ## Examples

      <.card>
        <p>Content</p>
      </.card>
  """
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div class={["rounded-lg border border-line bg-card p-5 shadow-xs", @class]} {@rest}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  A small pill for labels, streaks, placements.

  ## Examples

      <.badge>3-0</.badge>
      <.badge tone={:accent}>W4</.badge>
  """
  attr :tone, :atom, values: [:neutral, :accent, :success], default: :neutral
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    tone = (assigns[:tone] || :neutral) |> Atom.to_string()

    tones = %{
      "neutral" => "bg-paper-soft text-ink-muted",
      "accent" => "bg-accent-soft text-accent-strong",
      "success" => "bg-success-soft text-success"
    }

    assigns = assign(assigns, :tone_classes, Map.fetch!(tones, tone))

    ~H"""
    <span
      class={[
        "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold",
        @tone_classes,
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Buttons and button-styled links.

  ## Examples

      <.button phx-click="go" variant="primary">Go</.button>
      <.button navigate={~p"/rankings"}>Rankings</.button>
  """
  attr :variant, :string, values: ~w(primary ghost outline), default: "ghost"
  attr :size, :string, values: ~w(sm md lg), default: "md"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method download disabled)
  slot :inner_block, required: true

  def button(assigns) do
    variant = assigns[:variant] || "ghost"
    size = assigns[:size] || "md"

    base =
      "inline-flex min-h-11 items-center justify-center gap-2 rounded-md font-semibold transition-colors cursor-pointer disabled:cursor-not-allowed disabled:opacity-50"

    variants = %{
      "primary" => "bg-accent text-white hover:bg-accent-strong",
      "ghost" => "border border-line-strong bg-card text-ink hover:bg-paper-soft",
      "outline" => "border border-accent text-accent hover:bg-accent-soft"
    }

    sizes = %{
      "sm" => "px-2.5 py-1.5 text-sm",
      "md" => "px-4 py-2 text-sm",
      "lg" => "px-6 py-3 text-base"
    }

    assigns =
      assign(assigns, :classes, [
        base,
        Map.fetch!(variants, variant),
        Map.fetch!(sizes, size),
        assigns[:class]
      ])

    ~H"""
    <.link_or_button classes={@classes} rest={@rest}>{render_slot(@inner_block)}</.link_or_button>
    """
  end

  # Renders a link when navigation attrs are present, a button otherwise.
  defp link_or_button(assigns) do
    ~H"""
    <%= if @rest[:href] || @rest[:navigate] || @rest[:patch] do %>
      <.link class={@classes} {@rest}>{render_slot(@inner_block)}</.link>
    <% else %>
      <button class={@classes} {@rest}>{render_slot(@inner_block)}</button>
    <% end %>
    """
  end

  @doc """
  A grid of stat cards with a labelled value each.

  ## Examples

      <.stat_grid>
        <.stat label="W/L" value="12-4" />
        <.stat label="Elo" value="1564" />
      </.stat_grid>
  """
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def stat_grid(assigns) do
    ~H"""
    <div class={["grid grid-cols-2 gap-3 md:grid-cols-4", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :hint, :string, default: nil

  def stat(assigns) do
    ~H"""
    <div class="rounded-lg border border-line bg-card p-4">
      <p class="text-xs font-semibold uppercase tracking-widest text-ink-muted">{@label}</p>
      <p class="mt-1 font-mono text-2xl font-semibold text-ink">{@value}</p>
      <p :if={@hint} class="mt-1 text-sm text-ink-faint">{@hint}</p>
    </div>
    """
  end

  @doc """
  An overflow-safe table with a sticky header. Rows are given via a slot,
  columns are caller-styled.

  ## Examples

      <.table id="leaderboard">
        <:head>
          <th class="p-3 text-left">Player</th>
          <th class="p-3 text-right">Elo</th>
        </:head>
        <%= for row <- @rows do %>
          <tr>
            <td class="p-3">{row.player}</td>
            <td class="p-3 text-right font-mono">{row.elo}</td>
          </tr>
        <% end %>
      </.table>
  """
  attr :id, :string, required: true
  attr :class, :any, default: nil
  slot :head, required: true
  slot :inner_block, required: true

  def table(assigns) do
    ~H"""
    <div class={["overflow-x-auto rounded-lg border border-line bg-card", @class]}>
      <table class="w-full min-w-160 text-sm">
        <thead class="sticky top-0 bg-paper-soft">
          <tr class="[&_th]:border-b [&_th]:border-line [&_th]:font-semibold [&_th]:text-ink-muted">
            {render_slot(@head)}
          </tr>
        </thead>
        <tbody
          id={@id}
          class="[&_tr]:border-b [&_tr]:border-line/60 [&_tr:last-child]:border-b-0 [&_tr:nth-child(odd)]:bg-paper/40"
        >
          {render_slot(@inner_block)}
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Standard empty state: icon, title, hint. Never a bare blank area.
  """
  attr :title, :string, required: true
  attr :hint, :string, default: nil
  attr :class, :any, default: nil

  def empty_state(assigns) do
    ~H"""
    <div class={[
      "rounded-lg border border-dashed border-line-strong bg-paper/50 p-8 text-center",
      @class
    ]}>
      <p class="text-sm font-semibold text-ink">{@title}</p>
      <p :if={@hint} class="mt-1 text-sm text-ink-muted">{@hint}</p>
    </div>
    """
  end

  @doc """
  Loading state: labelled spinner — never a bare spinner.

  ## Examples

      <.loading label="Loading sets…" />
  """
  attr :label, :string, required: true
  attr :class, :any, default: nil

  def loading(assigns) do
    ~H"""
    <div class={["flex items-center gap-3 p-4 text-ink-muted", @class]} role="status">
      <.icon name="hero-arrow-path" class="size-5 animate-spin" />
      <p class="text-sm">{@label}</p>
    </div>
    """
  end
end
