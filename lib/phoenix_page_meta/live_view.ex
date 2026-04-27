defmodule PhoenixPageMeta.LiveView do
  @moduledoc """
  Behaviour and helper for using PhoenixPageMeta from a LiveView.

  In `MyAppWeb.live_view/0`, add the behaviour and import:

      def live_view do
        quote do
          use Phoenix.LiveView, layout: {MyAppWeb.Layouts, :app}
          @behaviour PhoenixPageMeta.LiveView
          import PhoenixPageMeta.LiveView, only: [assign_page_meta: 1]
        end
      end

  In each LiveView, implement `page_meta/2` and call `assign_page_meta/1` at
  the end of `mount/3` or `handle_params/3` (after any data needed for the
  meta has been assigned):

      @impl PhoenixPageMeta.LiveView
      def page_meta(socket, :show) do
        location = socket.assigns.location
        %MyAppWeb.PageMeta{
          title: location.name,
          path: ~p"/locations/\#{location.slug}"
        }
      end

      def handle_params(params, _uri, socket) do
        {:noreply,
         socket
         |> assign(:location, load_location(params))
         |> assign_page_meta()}
      end

  After `assign_page_meta/1`, the socket has `:page_meta` and `:page_title`
  assigned, ready for use in layouts and the `MetaTags` component.
  """

  @doc """
  Returns the page metadata struct for the given socket and live action.

  Implementations are free to read any assign that has been set before
  `assign_page_meta/1` is called.
  """
  @callback page_meta(socket :: Phoenix.LiveView.Socket.t(), action :: atom()) :: struct()

  @doc """
  Calls `page_meta/2` on the socket's view module and assigns the result as
  `:page_meta`, plus `:page_title` from the struct's `:title`.
  """
  def assign_page_meta(socket) do
    page_meta = socket.view.page_meta(socket, socket.assigns.live_action)

    socket
    |> Phoenix.Component.assign(:page_meta, page_meta)
    |> Phoenix.Component.assign(:page_title, page_meta.title)
  end
end
