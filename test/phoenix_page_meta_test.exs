defmodule PhoenixPageMetaTest.UnrelatedStruct do
  @moduledoc false
  defstruct [:title, :path, :parent]
end

defmodule PhoenixPageMetaTest do
  use ExUnit.Case, async: true

  alias TestApp.PageMeta, as: TestPageMeta
  alias PhoenixPageMetaTest.UnrelatedStruct

  describe "use PhoenixPageMeta" do
    test "injects breadcrumbs/1 wrapper that pattern-matches the project struct" do
      page_meta = %TestPageMeta{title: "Home", path: "/"}

      assert [%PhoenixPageMeta.Breadcrumb{title: "Home"}] =
               TestPageMeta.breadcrumbs(page_meta)
    end

    test "injects active?/2,3 wrappers that pattern-match the project struct" do
      page_meta = %TestPageMeta{title: "Home", path: "/"}
      assert TestPageMeta.active?(page_meta, "/")
      assert TestPageMeta.active?(page_meta, "/", exact: true)
    end

    test "wrappers reject other structs (FunctionClauseError)" do
      assert_raise FunctionClauseError, fn ->
        TestPageMeta.breadcrumbs(%UnrelatedStruct{title: "x", path: "/x"})
      end
    end

    test "default base_url/0 returns the configured base_url string" do
      assert TestPageMeta.base_url() == "https://example.test"
    end

    test "default lang_path/2 swaps the leading locale segment" do
      page_meta = %TestPageMeta{title: "x", path: "/en/locations/123"}
      assert TestPageMeta.lang_path(page_meta, :de) == "/de/locations/123"
      assert TestPageMeta.lang_path(page_meta, "es") == "/es/locations/123"
    end
  end

  describe "active?/2,3 (lib-level)" do
    test "matches the current page exactly" do
      page_meta = %TestPageMeta{title: "x", path: "/locations"}
      assert PhoenixPageMeta.active?(page_meta, "/locations")
    end

    test "matches a parent path via prefix-with-slash" do
      page_meta = %TestPageMeta{title: "x", path: "/locations/123"}
      assert PhoenixPageMeta.active?(page_meta, "/locations")
    end

    test "does not match a path that is only a string prefix" do
      page_meta = %TestPageMeta{title: "x", path: "/location-foo"}
      refute PhoenixPageMeta.active?(page_meta, "/location")
    end

    test "exact: true matches only when paths are equal" do
      page_meta = %TestPageMeta{title: "x", path: "/locations/123"}
      assert PhoenixPageMeta.active?(page_meta, "/locations/123", exact: true)
      refute PhoenixPageMeta.active?(page_meta, "/locations", exact: true)
    end

    test "strips query strings by default" do
      page_meta = %TestPageMeta{title: "x", path: "/articles?page=2"}
      assert PhoenixPageMeta.active?(page_meta, "/articles")
      assert PhoenixPageMeta.active?(page_meta, "/articles?page=99")
    end

    test "query: true keeps query strings in the comparison" do
      page_meta = %TestPageMeta{title: "x", path: "/articles?tab=open"}

      assert PhoenixPageMeta.active?(page_meta, "/articles?tab=open",
               query: true,
               exact: true
             )

      refute PhoenixPageMeta.active?(page_meta, "/articles?tab=closed",
               query: true,
               exact: true
             )
    end
  end

  describe "__resolve_base_url__/2" do
    test "returns the string when base_url is a binary" do
      assert PhoenixPageMeta.__resolve_base_url__(SomeMod, "https://example.com") ==
               "https://example.com"
    end

    test "calls the function when base_url is a 0-arity capture" do
      assert PhoenixPageMeta.__resolve_base_url__(SomeMod, fn -> "https://x.test" end) ==
               "https://x.test"
    end

    test "raises when nil and the guessed endpoint cannot be loaded" do
      assert_raise RuntimeError, ~r/could not auto-detect/, fn ->
        PhoenixPageMeta.__resolve_base_url__(NonExistentApp.PageMeta, nil)
      end
    end
  end

  describe "__guess_endpoint__/1" do
    test "swaps the last segment of the module path with Endpoint" do
      assert PhoenixPageMeta.__guess_endpoint__(MyAppWeb.PageMeta) == MyAppWeb.Endpoint
      assert PhoenixPageMeta.__guess_endpoint__(Foo.Bar.PageMeta) == Foo.Bar.Endpoint
    end
  end

  describe "__default_lang_path__/2" do
    test "swaps the leading locale segment" do
      pm = %TestPageMeta{title: "x", path: "/en/locations/123"}
      assert PhoenixPageMeta.__default_lang_path__(pm, :de) == "/de/locations/123"
    end

    test "handles single-segment paths" do
      pm = %TestPageMeta{title: "x", path: "/en"}
      assert PhoenixPageMeta.__default_lang_path__(pm, :es) == "/es"
    end

    test "handles root path" do
      pm = %TestPageMeta{title: "x", path: "/"}
      assert PhoenixPageMeta.__default_lang_path__(pm, :en) == "/en"
    end
  end
end
