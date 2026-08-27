defmodule KusaDataWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://phoenix-live-view.hexdocs.pm/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: KusaDataWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash
        id="welcome-back"
        kind={:info}
        phx-mounted={show("#welcome-back") |> JS.remove_attribute("hidden")}
        hidden
      >
        Welcome Back!
      </.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation and phx support.

  Pass `navigate`, `patch` or `href` to render a link button; everything else
  renders a real `<button>`. Icons from the hero set can be attached with
  `icon` (leading) or `icon_right` (trailing).

  ## Examples

      <.btn>Save</.btn>
      <.btn phx-click="save" variant="primary">Save</.btn>
      <.btn variant="secondary" icon_right="hero-arrow-right" patch={~p"/x"}>Continue</.btn>
  """
  attr :rest, :global,
    include: ~w(href navigate patch method download name value disabled target rel)

  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary secondary ghost), default: "secondary"
  attr :size, :string, values: ~w(sm md lg), default: "md"
  attr :type, :string, default: "button", doc: "native button type (use \"submit\" inside forms)"
  attr :icon, :string, default: nil
  attr :icon_right, :string, default: nil
  attr :aria, :string, default: nil

  slot :inner_block, required: true

  def btn(%{rest: rest} = assigns) do
    size = %{
      "sm" => "h-9 gap-1.5 px-3 text-[13px]",
      "md" => "h-11 gap-2 px-4 text-sm",
      "lg" => "h-12 gap-2 px-6 text-[15px]"
    }

    variant = %{
      "primary" =>
        "bg-[#a3e635] text-[#08070b] hover:bg-[#b8f05a] tracking-[-0.02em] font-semibold",
      "secondary" =>
        "border border-[rgba(255,255,255,0.08)] bg-[#121116]/80 text-[#f5f3ff] hover:border-[rgba(255,255,255,0.14)] hover:bg-[#1a1920]/80 hover:text-white",
      "ghost" => "text-[#9a95b0] hover:bg-[rgba(255,255,255,0.06)] hover:text-[#f5f3ff]"
    }

    icon_size = %{"sm" => "size-4", "md" => "size-4", "lg" => "size-4"}

    assigns =
      assign(assigns,
        size_class: size[assigns.size],
        variant_class: variant[assigns.variant],
        icon_size: icon_size[assigns.size]
      )

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link
        class={[
          "inline-flex select-none items-center justify-center whitespace-nowrap rounded-lg font-medium transition-colors active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50",
          @size_class,
          @variant_class,
          @class
        ]}
        aria-label={@aria}
        {@rest}
      >
        <.icon :if={@icon} name={@icon} class={@icon_size} />
        {render_slot(@inner_block)}
        <.icon :if={@icon_right} name={@icon_right} class={@icon_size} />
      </.link>
      """
    else
      ~H"""
      <button
        type={@type}
        class={[
          "inline-flex select-none items-center justify-center whitespace-nowrap rounded-lg font-medium transition-colors active:scale-[0.98] disabled:pointer-events-none disabled:opacity-50",
          @size_class,
          @variant_class,
          @class
        ]}
        aria-label={@aria}
        {@rest}
      >
        <.icon :if={@icon} name={@icon} class={@icon_size} />
        {render_slot(@inner_block)}
        <.icon :if={@icon_right} name={@icon_right} class={@icon_size} />
      </button>
      """
    end
  end

  @doc """
  Renders a status badge with an optional leading dot.

  ## Examples

      <.badge tone="accent" dot>Registration open</.badge>
      <.badge tone="neutral">3-2</.badge>
  """
  attr :tone, :string,
    values: ~w(neutral accent emerald amber rose outline),
    default: "neutral"

  attr :dot, :boolean, default: false
  attr :class, :any, default: nil

  slot :inner_block

  def badge(assigns) do
    tones = %{
      "neutral" => %{pill: "bg-stone-800/70 text-stone-300", dot: "bg-stone-400"},
      "accent" => %{pill: "bg-lime-400/15 text-lime-200", dot: "bg-lime-400"},
      "emerald" => %{pill: "bg-emerald-500/15 text-emerald-200", dot: "bg-emerald-400"},
      "amber" => %{pill: "bg-amber-500/15 text-amber-200", dot: "bg-amber-400"},
      "rose" => %{pill: "bg-rose-500/15 text-rose-200", dot: "bg-rose-400"},
      "outline" => %{pill: "border border-stone-600 text-stone-400", dot: "bg-stone-500"}
    }

    tone = tones[assigns.tone]
    assigns = assign(assigns, pill_class: tone.pill, dot_class: tone.dot)

    ~H"""
    <span class={[
      "inline-flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1 font-mono text-xs font-medium",
      @pill_class,
      @class
    ]}>
      <span :if={@dot} class={["size-1.5 rounded-full", @dot_class]} aria-hidden="true"></span>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders a bordered surface card. With `hover`, an acid-lime rule slides in
  on the left edge.

  ## Examples

      <.card hover>...</.card>
  """
  attr :class, :any, default: nil
  attr :hover, :boolean, default: false
  attr :id, :string, default: nil

  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "rounded-[20px] border border-[var(--border)] bg-[var(--surface)]/80 backdrop-blur-sm",
        @hover &&
          "rule-hover transition-colors hover:border-[var(--border2)] hover:bg-[var(--surface2)]/80",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a skeleton shimmer block. Sizes come from `class`.

  ## Examples

      <.skeleton class="h-4 w-24" />
  """
  attr :class, :any, default: "h-3 w-24 rounded"

  def skeleton(assigns) do
    ~H"""
    <div class={["skeleton", @class]} aria-hidden="true"></div>
    """
  end

  @doc """
  Renders a stat line: small label over an emphatic value.

  ## Examples

      <.stat label="Win rate" value="62.5%" />
  """
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :sub, :string, default: nil
  attr :value_class, :any, default: nil

  def stat(assigns) do
    ~H"""
    <div class="rounded-xl border border-stone-800 bg-stone-900/50 px-5 py-5">
      <div class="text-xs font-medium uppercase tracking-[0.12em] text-stone-400">{@label}</div>
      <div class={[
        "mt-2 font-mono text-3xl font-semibold tracking-tight text-stone-100 tabular-nums",
        @value_class
      ]}>
        {@value}
      </div>
      <div :if={@sub} class="mt-1 text-sm text-stone-400">{@sub}</div>
    </div>
    """
  end

  @doc """
  Renders an empty/error state with an icon and title.

  ## Examples

      <.empty_state icon="hero-magnifying-glass" title="No results">
        <:body>Try a different tag.</:body>
        <:action><.btn variant="primary">Reset</.btn></:action>
      </.empty_state>
  """
  attr :icon, :string, default: "hero-inbox"
  attr :title, :string, required: true

  slot :body
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center rounded-xl border border-dashed border-stone-800 px-6 py-16 text-center">
      <.icon name={@icon} class="size-6 text-stone-600" />
      <h3 class="mt-3 text-base font-medium text-stone-200">{@title}</h3>
      <div :if={@body != []} class="mt-1 max-w-sm text-[15px] text-stone-400">
        {render_slot(@body)}
      </div>
      <div :if={@action != []} class="mt-5">
        {render_slot(@action)}
      </div>
    </div>
    """
  end

  @doc """
  Renders an initial-letter avatar disc.

  ## Examples

      <.avatar name="Mango" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-9 text-sm"

  def avatar(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex shrink-0 select-none items-center justify-center rounded-full border border-stone-700/80 bg-stone-800/80 font-medium text-stone-300",
        @class
      ]}
      aria-hidden="true"
    >
      {initial(@name)}
    </span>
    """
  end

  defp initial(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.slice(0, 1)
    |> String.upcase()
  end

  defp initial(_), do: "?"

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://phoenix-html.hexdocs.pm/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-2">
      <label for={@id} class="inline-flex cursor-pointer items-center gap-2">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={
            @class || "size-4 rounded border-stone-700 bg-stone-950 text-lime-400 accent-lime-400"
          }
          {@rest}
        />
        <span class="text-sm text-zinc-300">{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns =
      assign(assigns,
        default_class:
          "w-full rounded-lg border border-stone-700/70 bg-stone-950 px-4 py-3 text-[15px] text-stone-100 placeholder-stone-500 outline-none transition focus:border-lime-400/50 focus:ring-2 focus:ring-lime-400/15",
        error_danger_class: "border-rose-500/60 focus:border-rose-500/70 focus:ring-rose-500/20"
      )

    ~H"""
    <div class="mb-2">
      <label for={@id}>
        <span :if={@label} class="mb-1 block text-xs font-semibold text-zinc-400">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || @default_class, @errors != [] && (@error_class || @error_danger_class)]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    assigns =
      assign(assigns,
        default_class:
          "w-full rounded-lg border border-stone-700/70 bg-stone-950 px-4 py-3 text-[15px] text-stone-100 placeholder-stone-500 outline-none transition focus:border-lime-400/50 focus:ring-2 focus:ring-lime-400/15",
        error_danger_class: "border-rose-500/60 focus:border-rose-500/70 focus:ring-rose-500/20"
      )

    ~H"""
    <div class="mb-2">
      <label for={@id}>
        <span :if={@label} class="mb-1 block text-xs font-semibold text-zinc-400">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[@class || @default_class, @errors != [] && (@error_class || @error_danger_class)]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    assigns =
      assign(assigns,
        default_class:
          "w-full rounded-lg border border-stone-700/70 bg-stone-950 px-4 py-3 text-[15px] text-stone-100 placeholder-stone-500 outline-none transition focus:border-lime-400/50 focus:ring-2 focus:ring-lime-400/15",
        error_danger_class: "border-rose-500/60 focus:border-rose-500/70 focus:ring-rose-500/20"
      )

    ~H"""
    <div class="mb-2">
      <label for={@id}>
        <span :if={@label} class="mb-1 block text-xs font-semibold text-zinc-400">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[@class || @default_class, @errors != [] && (@error_class || @error_danger_class)]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex items-center gap-2 text-sm text-rose-400">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(KusaDataWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(KusaDataWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
