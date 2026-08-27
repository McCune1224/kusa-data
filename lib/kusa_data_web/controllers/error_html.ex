defmodule KusaDataWeb.ErrorHTML do
  use KusaDataWeb, :html

  @doc """
  Standalone HTML error pages (no Layouts.app — that expects LiveView assigns
  such as @current_user / @flash). Phoenix calls render/2 with a template name
  like "404" or "500" when the request accepts HTML.
  """

  def render("404", assigns) do
    ~H"""
    <div
      id="error-404"
      class="flex min-h-screen flex-col items-center justify-center bg-canvas px-6 text-ink"
    >
      <div class="flex flex-col items-center gap-6 text-center">
        <h1 class="font-display text-8xl font-bold tracking-tight text-ink">404</h1>
        <p class="max-w-md text-lg text-muted">
          The page you're looking for doesn't exist or may have moved.
        </p>
        <.link
          navigate={~p"/"}
          class="rounded-none border border-accent bg-accent px-5 py-2.5 text-sm font-semibold text-accent-ink transition-colors hover:border-accent-strong hover:bg-accent-strong"
        >
          Home
        </.link>
      </div>
    </div>
    """
  end

  def render("500", assigns) do
    ~H"""
    <div
      id="error-500"
      class="flex min-h-screen flex-col items-center justify-center bg-canvas px-6 text-ink"
    >
      <div class="flex flex-col items-center gap-6 text-center">
        <h1 class="font-display text-8xl font-bold tracking-tight text-ink">500</h1>
        <p class="max-w-md text-lg text-muted">
          Something went wrong on our end. Please try again in a moment.
        </p>
        <.link
          navigate={~p"/"}
          class="rounded-none border border-accent bg-accent px-5 py-2.5 text-sm font-semibold text-accent-ink transition-colors hover:border-accent-strong hover:bg-accent-strong"
        >
          Home
        </.link>
      </div>
    </div>
    """
  end

  def render(_, assigns) do
    ~H"""
    <div
      id="error-page"
      class="flex min-h-screen flex-col items-center justify-center bg-canvas px-6 text-ink"
    >
      <div class="flex flex-col items-center gap-6 text-center">
        <h1 class="font-display text-8xl font-bold tracking-tight text-ink">Oops</h1>
        <p class="max-w-md text-lg text-muted">
          We couldn't find what you were looking for.
        </p>
        <.link
          navigate={~p"/"}
          class="rounded-none border border-accent bg-accent px-5 py-2.5 text-sm font-semibold text-accent-ink transition-colors hover:border-accent-strong hover:bg-accent-strong"
        >
          Home
        </.link>
      </div>
    </div>
    """
  end
end
