defmodule KusaDataWeb.CoreComponents do
  @moduledoc """
  Refined-dark UI primitives shared across every LiveView and controller.
  Single restrained accent (emerald); calm near-black canvas.
  """
  use Phoenix.Component
  use Gettext, backend: KusaDataWeb.Gettext

  @doc """
  Renders a button.

    <.button>Save</.button>
    <.button variant="secondary">Cancel</.button>
    <.button variant="danger" size="sm">Delete</.button>
  """
  attr :type, :string, default: nil
  attr :variant, :any, default: :primary
  attr :size, :any, default: :md
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled form name value id aria-* data-*)
  slot :inner_block, required: true

  def button(assigns) do
    assigns =
      assign(assigns,
        variant: normalize_atom(assigns.variant, :primary),
        size: normalize_atom(assigns.size, :md)
      )

    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center gap-2 rounded-card font-semibold tracking-tight",
        "transition-all duration-150 ease-out active:scale-[0.98] disabled:cursor-not-allowed disabled:opacity-50",
        @size == :sm && "px-3 py-1.5 text-sm",
        @size == :md && "px-4 py-2 text-sm",
        @size == :lg && "px-5 py-2.5 text-base",
        @variant == :primary &&
          "bg-accent text-accent-ink shadow-sm hover:bg-accent-strong hover:shadow-[0_0_0_4px_var(--color-accent-soft)]",
        @variant == :secondary &&
          "border border-line-2 bg-surface-2 text-ink hover:border-accent-line hover:text-accent",
        @variant == :ghost && "text-muted hover:bg-surface-2 hover:text-ink",
        @variant == :danger &&
          "border border-danger/40 bg-danger-soft text-danger hover:bg-danger/20",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a compact icon button.
  """
  attr :type, :string, default: "button"
  attr :label, :string, default: nil
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled aria-* data-* id)
  slot :inner_block, required: true

  def icon_button(assigns) do
    ~H"""
    <button
      type={@type}
      aria-label={@label}
      title={@label}
      class={[
        "inline-flex size-9 items-center justify-center rounded-full border border-line bg-surface-2 text-muted",
        "transition-colors hover:border-accent-line hover:text-accent disabled:opacity-50",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a text input with label and error support.
  """
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :class, :string, default: ""
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :value, :any, default: nil
  attr :label, :string, default: nil
  attr :placeholder, :string, default: nil
  attr :required, :boolean, default: false

  attr :rest, :global,
    include: ~w(disabled readonly maxlength minlength step autocomplete pattern)

  def input(assigns) do
    assigns =
      assign(assigns, :errors, field_errors(assigns[:field] || nil, assigns[:errors]))
      |> assign(:value, resolve_value(assigns[:field], assigns[:value]))

    ~H"""
    <div class="flex flex-col gap-1.5">
      <.label for={@id}>{@label}</.label>
      <input
        type={@type}
        id={@id}
        name={@name}
        value={@value}
        placeholder={@placeholder}
        required={@required}
        class={[
          "w-full rounded-card border bg-surface px-3 py-2 text-sm text-ink placeholder:text-faint",
          "transition-colors focus:outline-none focus:ring-2",
          Enum.any?(@errors) && "border-danger/60 focus:ring-danger/30",
          !Enum.any?(@errors) && "border-line focus:border-accent-line focus:ring-accent/25",
          @class
        ]}
        {@rest}
      />
      <%= for error <- @errors do %>
        <p class="text-xs text-danger">{error}</p>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a select with label and error support.
  """
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :class, :string, default: ""
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :label, :string, default: nil
  attr :prompt, :string, default: nil
  attr :options, :list, default: []
  attr :selected, :any, default: nil
  attr :rest, :global, include: ~w(disabled required multiple size)

  def select(assigns) do
    assigns =
      assign(assigns, :errors, field_errors(assigns[:field] || nil, assigns[:errors]))

    ~H"""
    <div class="flex flex-col gap-1.5">
      <.label for={@id}>{@label}</.label>
      <select
        id={@id}
        name={@name}
        class={[
          "w-full rounded-card border border-line bg-surface px-3 py-2 text-sm text-ink",
          "transition-colors focus:border-accent-line focus:outline-none focus:ring-2 focus:ring-accent/25",
          @class
        ]}
        {@rest}
      >
        <%= if @prompt do %>
          <option value="">{@prompt}</option>
        <% end %>
        <%= for {label, value} <- @options do %>
          <option value={value} selected={value == @selected}>{label}</option>
        <% end %>
      </select>
      <%= for error <- @errors do %>
        <p class="text-xs text-danger">{error}</p>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a checkbox with label.
  """
  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :label, :string, default: nil
  attr :checked, :boolean, default: false
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(disabled required value)

  def checkbox(assigns) do
    ~H"""
    <label class="flex cursor-pointer items-center gap-2.5 text-sm text-muted">
      <input
        type="checkbox"
        id={@id}
        name={@name}
        checked={@checked}
        class="size-4 rounded border-line-2 bg-surface text-accent accent-accent focus:ring-2 focus:ring-accent/30"
        {@rest}
      />
      {@label}
    </label>
    """
  end

  @doc "Renders a label."
  attr :for, :string, default: nil
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="text-xs font-semibold uppercase tracking-[0.08em] text-muted">
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  A surface card / panel.
  """
  attr :class, :string, default: ""
  attr :id, :string, default: nil
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "rounded-card border border-line bg-surface",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  A badge / pill for statuses and tags.
  """
  attr :variant, :any, default: :default
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def badge(assigns) do
    assigns = assign(assigns, :variant, normalize_atom(assigns.variant, :default))

    ~H"""
    <span class={[
      "inline-flex items-center gap-1 rounded-pill px-2.5 py-0.5 text-xs font-semibold",
      @variant == :default && "bg-surface-2 text-muted",
      @variant == :accent && "bg-accent-soft text-accent",
      @variant == :danger && "bg-danger-soft text-danger",
      @variant == :muted && "bg-surface-2 text-faint",
      @variant == :outline && "border border-line-2 text-muted",
      @class
    ]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  An empty state with icon, title, and optional description/action.
  """
  attr :icon, :string, default: "hero-information-circle"
  attr :title, :string, required: true
  attr :description, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block

  def empty(assigns) do
    ~H"""
    <div class={["flex flex-col items-center justify-center gap-3 px-6 py-16 text-center", @class]}>
      <.icon name={@icon} class="size-10 text-faint" />
      <p class="text-base font-semibold text-ink">{@title}</p>
      <%= if @description do %>
        <p class="max-w-md text-sm text-muted">{@description}</p>
      <% end %>
      <%= if @inner_block do %>
        <div class="mt-2">{render_slot(@inner_block)}</div>
      <% end %>
    </div>
    """
  end

  @doc """
  A labeled statistic tile.
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :sub, :string, default: nil
  attr :class, :string, default: ""

  def stat(assigns) do
    ~H"""
    <div class={["rounded-card border border-line bg-surface px-4 py-3", @class]}>
      <p class="text-xs font-medium uppercase tracking-[0.08em] text-muted">{@label}</p>
      <p class="mt-1 font-display text-2xl font-semibold text-ink">{@value}</p>
      <%= if @sub do %>
        <p class="text-xs text-faint">{@sub}</p>
      <% end %>
    </div>
    """
  end

  @doc """
  A table wrapper with consistent dark styling.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def table(assigns) do
    ~H"""
    <div class={["overflow-x-auto rounded-card border border-line", @class]}>
      <table class="w-full border-collapse text-sm">
        {render_slot(@inner_block)}
      </table>
    </div>
    """
  end

  @doc """
  A flash message. Used by Layouts.flash_group.
  """
  attr :id, :string, default: nil
  attr :kind, :atom, required: true, values: [:info, :error]
  attr :title, :string, default: nil
  attr :flash, :map, default: %{}, doc: "the flash map"
  attr :hidden, :boolean, default: false
  attr :rest, :global, include: ~w(phx-disconnected phx-connected)

  def flash(assigns) do
    assigns = assign(assigns, :flash_kind, "flash-#{assigns.kind}")

    ~H"""
    <div
      id={@id || @flash_kind}
      class={[
        "fixed inset-x-0 top-4 z-[60] mx-auto flex max-w-md items-start gap-3 rounded-card border px-4 py-3 shadow-lg",
        @kind == :info && "border-accent-line bg-surface-2 text-ink",
        @kind == :error && "border-danger/50 bg-danger-soft text-ink",
        @hidden && "hidden"
      ]}
      {@rest}
    >
      <.icon
        name={(@kind == :error && "hero-exclamation-triangle") || "hero-information-circle"}
        class="mt-0.5 size-5 text-accent"
      />
      <div class="text-sm">
        <%= if @title do %>
          <p class="font-semibold">{@title}</p>
        <% end %>
        <p class={["text-muted", @title && "text-xs"]}>{Phoenix.Flash.get(@flash, @kind)}</p>
      </div>
    </div>
    """
  end

  defp field_errors(nil, nil), do: []
  defp field_errors(nil, errors), do: List.wrap(errors)
  defp field_errors(%Phoenix.HTML.FormField{} = field, _), do: field.errors

  defp resolve_value(nil, value), do: value
  defp resolve_value(%Phoenix.HTML.FormField{} = field, _value), do: field.value

  defp normalize_atom(value, _default) when is_atom(value), do: value
  defp normalize_atom(value, _default) when is_binary(value), do: String.to_atom(value)
  defp normalize_atom(_value, default), do: default

  @doc """
  Renders a heroicon. Pass the full class name, e.g. `name="hero-x-mark"`.
  The icon is a CSS mask tinted with `currentColor`, so color it with a
  `text-*` utility.
  """
  attr :name, :string, required: true
  attr :class, :string, default: ""

  def icon(assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end
end
