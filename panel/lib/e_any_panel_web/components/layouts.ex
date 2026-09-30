defmodule EAnyPanelWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use EAnyPanelWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :dashboard, :boolean, default: false
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if @dashboard do %>
      {render_slot(@inner_block)}
    <% else %>
    <div class="eany-public">
      <header class="eany-public-header">
        <a href={~p"/"} class="eany-wordmark" aria-label="e-any.online ana sayfa">e-any.online</a>
        <.theme_toggle />
      </header>
      <main id="main-content" class="eany-public-content">
        {render_slot(@inner_block)}
      </main>
    </div>

    <% end %>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="Bağlantı kesildi"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Yeniden bağlanılıyor
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Sunucuya ulaşılamıyor"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Yeniden bağlanılıyor
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="eany-theme" role="group" aria-label="Görünüm">
      <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system" title="Sistem görünümü" aria-label="Sistem görünümü">
        <.icon name="hero-computer-desktop-micro" class="size-4" />
      </button>
      <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light" title="Açık görünüm" aria-label="Açık görünüm">
        <.icon name="hero-sun-micro" class="size-4" />
      </button>
      <button type="button" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark" title="Koyu görünüm" aria-label="Koyu görünüm">
        <.icon name="hero-moon-micro" class="size-4" />
      </button>
    </div>
    """
  end
end
