defmodule CursorDemoWeb.LiveCase do
  @moduledoc """
  This module defines the test case to be used by
  LiveView tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Phoenix.LiveViewTest
      import CursorDemoWeb.LiveCase

      # The default endpoint for testing
      @endpoint CursorDemoWeb.Endpoint
    end
  end

  setup tags do
    CursorDemo.DataCase.setup_sandbox(tags)
    :ok
  end
end
