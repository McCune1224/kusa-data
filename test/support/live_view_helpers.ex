defmodule KusaData.Test.LiveViewHelpers do
  @moduledoc """
  Small helpers for LiveView tests whose pages load data asynchronously over a
  background task. Polls until the expected element appears (bounded), which
  makes tests deterministic without brittle sleeps.
  """

  import ExUnit.Assertions
  import Phoenix.LiveViewTest

  @doc "Polls `render/1` until `selector` matches or `attempts` is exhausted."
  def wait_has_element(view, selector, attempts \\ 200) do
    if has_element?(view, selector) do
      true
    else
      if attempts > 0 do
        render(view)
        Process.sleep(5)
        wait_has_element(view, selector, attempts - 1)
      else
        false
      end
    end
  end

  @doc "Renders until the page no longer shows a loading skeleton."
  def wait_loaded(view, attempts \\ 200) do
    if render(view) =~ "skeleton" do
      if attempts > 0 do
        Process.sleep(5)
        wait_loaded(view, attempts - 1)
      else
        flunk("page did not finish loading")
      end
    else
      :ok
    end
  end
end
