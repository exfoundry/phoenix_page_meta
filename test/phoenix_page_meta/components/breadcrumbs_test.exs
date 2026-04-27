defmodule PhoenixPageMeta.Components.BreadcrumbsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  use Phoenix.Component

  alias TestApp.PageMeta, as: TestPageMeta

  describe "list/1" do
    defp render_breadcrumbs(page_meta) do
      assigns = %{page_meta: page_meta}

      ~H"""
      <PhoenixPageMeta.Components.Breadcrumbs.list page_meta={@page_meta}>
        <:link :let={breadcrumb}>
          <a href={breadcrumb.path}>{breadcrumb.title}</a>
        </:link>
        <:current :let={breadcrumb}>
          <b>{breadcrumb.title}</b>
        </:current>
        <:divider><span>/</span></:divider>
      </PhoenixPageMeta.Components.Breadcrumbs.list>
      """
      |> rendered_to_string()
    end

    test "renders nav with aria-label and aria-current on the last item" do
      root = %TestPageMeta{title: "Home", path: "/"}
      page = %TestPageMeta{title: "Locations", path: "/locations", parent: root}

      html = render_breadcrumbs(page)

      assert html =~ ~s(<nav aria-label="Breadcrumb">)
      assert html =~ ~s(<a href="/">Home</a>)
      assert html =~ ~s(<span>/</span>)
      assert html =~ ~s(aria-current="page")
      assert html =~ ~s(<b>Locations</b>)
    end

    test "single page is current, no divider" do
      page = %TestPageMeta{title: "Home", path: "/"}

      html = render_breadcrumbs(page)

      assert html =~ ~s(aria-current="page")
      assert html =~ ~s(<b>Home</b>)
      refute html =~ ~s(<span>/</span>)
    end

    test "renders nothing when the trail is empty" do
      page = %TestPageMeta{title: "Solo Modal", path: "/x", skip_breadcrumb: true}

      html = render_breadcrumbs(page)

      refute html =~ ~s(<nav)
    end

    test "exposes :page_meta in slot args for project-specific fields" do
      assigns = %{page_meta: %TestPageMeta{title: "Home", path: "/", icon: :home}}

      html =
        ~H"""
        <PhoenixPageMeta.Components.Breadcrumbs.list page_meta={@page_meta}>
          <:link :let={breadcrumb}>
            <a href={breadcrumb.path}>{breadcrumb.title}</a>
          </:link>
          <:current :let={breadcrumb}>
            <span data-icon={breadcrumb.page_meta.icon}>{breadcrumb.title}</span>
          </:current>
          <:divider>/</:divider>
        </PhoenixPageMeta.Components.Breadcrumbs.list>
        """
        |> rendered_to_string()

      assert html =~ ~s(data-icon="home")
    end

    test "passes :rest globals (e.g. class) to <nav>" do
      assigns = %{page_meta: %TestPageMeta{title: "Home", path: "/"}}

      html =
        ~H"""
        <PhoenixPageMeta.Components.Breadcrumbs.list page_meta={@page_meta} class="my-nav-class">
          <:link :let={b}>
            <a href={b.path}>{b.title}</a>
          </:link>
          <:current :let={b}><span>{b.title}</span></:current>
          <:divider>/</:divider>
        </PhoenixPageMeta.Components.Breadcrumbs.list>
        """
        |> rendered_to_string()

      assert html =~ ~s(class="my-nav-class")
    end
  end
end
