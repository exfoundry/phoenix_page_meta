defmodule PhoenixPageMeta.Components.Breadcrumbs do
  @moduledoc """
  Slot-based breadcrumb component.

  Owns the `<nav aria-label="Breadcrumb">` wrapper, the `<ol>`/`<li>`
  structure, the divider placement (between items, never after the last),
  and the `aria-current="page"` marker on the current page. Styling is
  supplied via three slots, each receiving a `%PhoenixPageMeta.Breadcrumb{}`.

  When the resulting trail is empty (e.g. all pages have `:skip_breadcrumb`
  set), nothing is rendered.

      <PhoenixPageMeta.Components.Breadcrumbs.list page_meta={@page_meta}>
        <:link :let={breadcrumb}>
          <.link navigate={breadcrumb.path}>{breadcrumb.title}</.link>
        </:link>
        <:current :let={breadcrumb}>
          <span class="font-medium">{breadcrumb.title}</span>
        </:current>
        <:divider>/</:divider>
      </PhoenixPageMeta.Components.Breadcrumbs.list>
  """

  use Phoenix.Component

  @doc """
  Renders an accessible breadcrumb trail from a PageMeta struct.

  ## Slots

    * `:link` — rendered for every ancestor (not the current page). Receives
      a `%PhoenixPageMeta.Breadcrumb{}`.
    * `:current` — rendered for the current page. Receives a
      `%PhoenixPageMeta.Breadcrumb{}`.
    * `:divider` — rendered between items. No argument.
  """
  attr(:page_meta, :any, required: true)
  attr(:rest, :global, doc: "Additional HTML attributes (e.g. `class`) applied to the `<nav>`.")

  slot(:link, required: true)
  slot(:current, required: true)
  slot(:divider, required: true)

  def list(assigns) when is_struct(assigns.page_meta) do
    assigns = assign(assigns, :breadcrumbs, PhoenixPageMeta.Breadcrumb.build(assigns.page_meta))

    ~H"""
    <nav :if={@breadcrumbs != []} aria-label="Breadcrumb" {@rest}>
      <ol>
        <%= for breadcrumb <- @breadcrumbs do %>
          <li>
            <%= if breadcrumb.last? do %>
              <span aria-current="page">{render_slot(@current, breadcrumb)}</span>
            <% else %>
              {render_slot(@link, breadcrumb)}
              {render_slot(@divider)}
            <% end %>
          </li>
        <% end %>
      </ol>
    </nav>
    """
  end
end
