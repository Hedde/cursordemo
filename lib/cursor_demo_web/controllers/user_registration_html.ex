defmodule CursorDemoWeb.UserRegistrationHTML do
  use CursorDemoWeb, :html

  embed_templates "user_registration_html/*"

  attr :form, :any, required: true
  attr :field, :atom, required: true
  def error_tag(assigns) do
    ~H"""
    <%= for error <- Keyword.get_values(@form.errors, @field) do %>
      <span class="invalid-feedback" phx-feedback-for={input_name(@form, @field)}>
        <%= translate_error(error) %>
      </span>
    <% end %>
    """
  end

  defp input_name(form, field) do
    form.name <> "[" <> to_string(field) <> "]"
  end
end
