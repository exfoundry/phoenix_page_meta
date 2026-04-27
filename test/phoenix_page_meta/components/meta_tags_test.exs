defmodule PhoenixPageMeta.Components.MetaTagsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias TestApp.PageMeta, as: TestPageMeta

  defp render_meta_tags(page_meta) do
    PhoenixPageMeta.Components.MetaTags.default(%{
      page_meta: page_meta,
      __changed__: nil
    })
    |> rendered_to_string()
  end

  describe "default/1" do
    test "renders title, og:type, og:url, canonical with endpoint url" do
      html = render_meta_tags(%TestPageMeta{title: "Hello", path: "/hello"})

      assert html =~ ~s(<meta property="og:type" content="website">)
      assert html =~ ~s(<meta property="og:url" content="https://example.test/hello">)
      assert html =~ ~s(<meta property="og:title" content="Hello">)
      assert html =~ ~s(<link rel="canonical" href="https://example.test/hello">)
    end

    test "uses canonical_path when set" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "Hello",
          path: "/hello?page=2",
          canonical_path: "/hello"
        })

      assert html =~ ~s(<link rel="canonical" href="https://example.test/hello">)
      assert html =~ ~s(<meta property="og:url" content="https://example.test/hello">)
    end

    test "renders noindex meta only when set" do
      html = render_meta_tags(%TestPageMeta{title: "x", path: "/x", noindex: true})
      assert html =~ ~s(<meta name="robots" content="noindex, follow">)
    end

    test "omits description tags when description is nil" do
      html = render_meta_tags(%TestPageMeta{title: "x", path: "/x"})
      refute html =~ ~s(name="description")
      refute html =~ ~s(property="og:description")
    end

    test "renders description tags when set" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "x",
          path: "/x",
          description: "Hello world"
        })

      assert html =~ ~s(<meta name="description" content="Hello world">)
      assert html =~ ~s(<meta property="og:description" content="Hello world">)
      assert html =~ ~s(<meta name="twitter:description" content="Hello world">)
    end

    test "relative og_image is prefixed with base_url" do
      html = render_meta_tags(%TestPageMeta{title: "x", path: "/x", og_image: "/img.png"})
      assert html =~ ~s(<meta property="og:image" content="https://example.test/img.png">)
      assert html =~ ~s(<meta name="twitter:image" content="https://example.test/img.png">)
      assert html =~ ~s(<meta name="twitter:card" content="summary_large_image">)
    end

    test "absolute og_image (https) is rendered as-is" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "x",
          path: "/x",
          og_image: "https://cdn.example.com/img.png"
        })

      assert html =~ ~s(<meta property="og:image" content="https://cdn.example.com/img.png">)
      refute html =~ "https://example.test/https://"
    end

    test "absolute og_image (http) is rendered as-is" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "x",
          path: "/x",
          og_image: "http://cdn.example.com/img.png"
        })

      assert html =~ ~s(<meta property="og:image" content="http://cdn.example.com/img.png">)
    end

    test "og:image:alt falls back to title when og_image_alt is nil" do
      html =
        render_meta_tags(%TestPageMeta{title: "Page title", path: "/x", og_image: "/img.png"})

      assert html =~ ~s(<meta property="og:image:alt" content="Page title">)
    end

    test "og:image:alt uses og_image_alt when set" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "Page title",
          path: "/x",
          og_image: "/img.png",
          og_image_alt: "Custom alt text"
        })

      assert html =~ ~s(<meta property="og:image:alt" content="Custom alt text">)
    end

    test "og:image:alt is omitted when no og_image" do
      html = render_meta_tags(%TestPageMeta{title: "x", path: "/x"})
      refute html =~ ~s(property="og:image:alt")
    end

    test "twitter:card falls back to summary when no og_image" do
      html = render_meta_tags(%TestPageMeta{title: "x", path: "/x", og_image: nil})
      assert html =~ ~s(<meta name="twitter:card" content="summary">)
    end

    test "renders json-ld script when set" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "x",
          path: "/x",
          json_ld: %{"@type" => "WebSite", "name" => "X"}
        })

      assert html =~ ~s(<script type="application/ld+json">)
      assert html =~ ~s("@type":"WebSite")
    end

    test "renders hreflang alternates and x-default when supported_locales set" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "x",
          path: "/en/hello",
          supported_locales: [:en, :es]
        })

      assert html =~
               ~s(<link rel="alternate" href="https://example.test/en/hello" hreflang="en">)

      assert html =~
               ~s(<link rel="alternate" href="https://example.test/es/hello" hreflang="es">)

      assert html =~
               ~s(<link rel="alternate" href="https://example.test/en/hello" hreflang="x-default">)
    end

    test "omits hreflang when supported_locales is nil" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "x",
          path: "/hello",
          supported_locales: nil
        })

      refute html =~ ~s(hreflang=)
    end

    test "renders og:site_name when set" do
      html =
        render_meta_tags(%TestPageMeta{title: "x", path: "/x", site_name: "Example Inc."})

      assert html =~ ~s(<meta property="og:site_name" content="Example Inc.">)
    end

    test "omits og:site_name when not set" do
      html = render_meta_tags(%TestPageMeta{title: "x", path: "/x"})
      refute html =~ ~s(property="og:site_name")
    end

    test "renders twitter:site when set" do
      html =
        render_meta_tags(%TestPageMeta{title: "x", path: "/x", twitter_site: "@example"})

      assert html =~ ~s(<meta name="twitter:site" content="@example">)
    end

    test "renders og:locale and og:locale:alternate when locale is set" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "x",
          path: "/en/hello",
          locale: :en,
          supported_locales: [:en, :es, :de]
        })

      assert html =~ ~s(<meta property="og:locale" content="en">)
      assert html =~ ~s(<meta property="og:locale:alternate" content="es">)
      assert html =~ ~s(<meta property="og:locale:alternate" content="de">)
      refute html =~ ~s(og:locale:alternate" content="en")
    end

    test "omits og:locale tags when locale is nil" do
      html =
        render_meta_tags(%TestPageMeta{
          title: "x",
          path: "/hello",
          supported_locales: [:en, :es]
        })

      refute html =~ ~s(property="og:locale")
    end
  end
end
