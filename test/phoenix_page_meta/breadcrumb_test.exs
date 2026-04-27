defmodule PhoenixPageMeta.BreadcrumbTest do
  use ExUnit.Case, async: true

  alias TestApp.PageMeta, as: TestPageMeta
  alias PhoenixPageMeta.Breadcrumb

  describe "build/1" do
    test "single page returns one entry that is both first? and last?" do
      page_meta = %TestPageMeta{title: "Home", path: "/"}

      assert [
               %Breadcrumb{
                 title: "Home",
                 path: "/",
                 first?: true,
                 last?: true,
                 page_meta: ^page_meta
               }
             ] = Breadcrumb.build(page_meta)
    end

    test "walks parent chain root-first; flags first? on first, last? on last" do
      root = %TestPageMeta{title: "Home", path: "/"}
      section = %TestPageMeta{title: "Locations", path: "/locations", parent: root}

      page = %TestPageMeta{
        title: "Boquete Tree Trek",
        path: "/locations/btt",
        parent: section
      }

      assert [
               %Breadcrumb{title: "Home", path: "/", first?: true, last?: false},
               %Breadcrumb{
                 title: "Locations",
                 path: "/locations",
                 first?: false,
                 last?: false
               },
               %Breadcrumb{
                 title: "Boquete Tree Trek",
                 path: "/locations/btt",
                 first?: false,
                 last?: true
               }
             ] = Breadcrumb.build(page)
    end

    test "uses :breadcrumb_title when set, falls back to :title" do
      root = %TestPageMeta{title: "Home", breadcrumb_title: "Start", path: "/"}

      page = %TestPageMeta{
        title: "Some Long Title",
        path: "/x",
        parent: root
      }

      assert [
               %Breadcrumb{title: "Start"},
               %Breadcrumb{title: "Some Long Title"}
             ] = Breadcrumb.build(page)
    end

    test ":page_meta carries the original struct so projects can read extras" do
      root = %TestPageMeta{title: "Home", path: "/", icon: :home}
      page = %TestPageMeta{title: "x", path: "/x", parent: root}

      [root_breadcrumb, _] = Breadcrumb.build(page)

      assert root_breadcrumb.page_meta.icon == :home
    end

    test "raises when a parent has nil path" do
      bad_parent =
        %TestPageMeta{title: "Bad", path: "placeholder"} |> Map.put(:path, nil)

      page = %TestPageMeta{title: "x", path: "/x", parent: bad_parent}

      assert_raise ArgumentError, ~r/missing :path/, fn ->
        Breadcrumb.build(page)
      end
    end

    test ":skip_breadcrumb pages are filtered, parent becomes the last? entry" do
      underlying = %TestPageMeta{title: "Locations", path: "/locations"}

      modal = %TestPageMeta{
        title: "Edit Location",
        path: "/locations/123/edit",
        parent: underlying,
        skip_breadcrumb: true
      }

      assert [
               %Breadcrumb{
                 title: "Locations",
                 path: "/locations",
                 first?: true,
                 last?: true
               }
             ] = Breadcrumb.build(modal)
    end

    test "rejects non-PageMeta structs" do
      assert_raise FunctionClauseError, fn ->
        Breadcrumb.build(%{title: "x", path: "/x"})
      end
    end
  end

  describe "MyAppWeb.PageMeta.breadcrumbs/1 wrapper (injected by use)" do
    test "delegates to Breadcrumb.build/1" do
      page_meta = %TestPageMeta{title: "Home", path: "/"}
      assert TestPageMeta.breadcrumbs(page_meta) == Breadcrumb.build(page_meta)
    end
  end
end
