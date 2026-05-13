defmodule PhoenixPageMeta.Components.MetaTags do
  @moduledoc """
  HEEx component that renders SEO meta tags from a PageMeta struct.

  Render in your root layout:

      <head>
        <PhoenixPageMeta.Components.MetaTags.default page_meta={@page_meta} />
        <.live_title>{@page_title}</.live_title>
      </head>

  Renders: description, Open Graph (`og:type`, `og:url`, `og:title`,
  `og:description`, `og:image`, `og:image:alt`, `og:site_name`, `og:locale`,
  `og:locale:alternate`), Twitter Card (`twitter:card`, `twitter:title`,
  `twitter:description`, `twitter:image`, `twitter:site`), JSON-LD,
  canonical URL, and hreflang alternate links.

  ## URL handling

  URL fields (`og_image`, `canonical_path`, `path`) are normalized:
  - URLs starting with `http://` or `https://` are rendered as-is
  - Relative paths are prefixed with the project's `base_url/0`

  This means you can store relative paths in your struct (`og_image:
  "/images/foo.png"`) and they get correctly absolutized at render time.

  The component dispatches `base_url/0` and `lang_path/2` calls to the
  PageMeta struct's own module (`page_meta.__struct__`). No global config —
  the struct itself carries the dispatch target.
  """

  use Phoenix.Component

  @doc """
  Renders SEO meta tags from a PageMeta struct.

  All optional fields are read with `Map.get/2`, so a project's PageMeta
  struct does not need to define every standard field — only the ones it uses.
  Required fields (`:title`, `:path`) are accessed directly.

  Hreflang alternate links are rendered when `:supported_locales` is set on
  the page. `og:locale` and `og:locale:alternate` are rendered when `:locale`
  is set.
  """
  attr :page_meta, :any, required: true

  def default(assigns) when is_struct(assigns.page_meta) do
    assigns = assign_meta_fields(assigns)

    ~H"""
    <meta :if={@noindex} name="robots" content="noindex, follow" />
    <meta :if={@description} name="description" content={escape_meta(@description)} />
    <meta property="og:type" content={@og_type} />
    <meta property="og:url" content={@canonical_url} />
    <meta property="og:title" content={@page_meta.title} />
    <meta
      :if={@description}
      property="og:description"
      content={escape_meta(@description)}
    />
    <meta :if={@site_name} property="og:site_name" content={@site_name} />
    <meta :if={@locale} property="og:locale" content={@locale} />
    <meta
      :for={alt <- @locale_alternates}
      property="og:locale:alternate"
      content={alt}
    />
    <meta :if={@og_image} property="og:image" content={@og_image} />
    <meta
      :if={@og_image}
      property="og:image:alt"
      content={@og_image_alt}
    />
    <meta
      name="twitter:card"
      content={if @og_image, do: "summary_large_image", else: "summary"}
    />
    <meta name="twitter:title" content={@page_meta.title} />
    <meta
      :if={@description}
      name="twitter:description"
      content={escape_meta(@description)}
    />
    <meta :if={@og_image} name="twitter:image" content={@og_image} />
    <meta :if={@twitter_site} name="twitter:site" content={@twitter_site} />
    <script
      :if={@json_ld}
      type="application/ld+json"
      phx-no-curly-interpolation
    >
      <%= Phoenix.HTML.raw(Jason.encode!(@json_ld)) %>
    </script>
    <link
      :for={loc <- @supported_locales}
      rel="alternate"
      href={@base_url <> @app_module.lang_path(@page_meta, loc)}
      hreflang={loc}
    />
    <link
      :if={@supported_locales != []}
      rel="alternate"
      href={@base_url <> @app_module.lang_path(@page_meta, List.first(@supported_locales))}
      hreflang="x-default"
    />
    <link rel="canonical" href={@canonical_url} />
    """
  end

  defp assign_meta_fields(assigns) do
    page_meta = assigns.page_meta
    app_module = page_meta.__struct__
    base_url = app_module.base_url()

    canonical_path = Map.get(page_meta, :canonical_path) || page_meta.path
    canonical_url = resolve_url(base_url, canonical_path)

    og_image = resolve_url(base_url, Map.get(page_meta, :og_image))

    locale = Map.get(page_meta, :locale)
    supported_locales = Map.get(page_meta, :supported_locales) || []

    locale_alternates =
      if locale,
        do: Enum.reject(supported_locales, &(&1 == locale)) |> Enum.map(&to_string/1),
        else: []

    assigns
    |> assign(:app_module, app_module)
    |> assign(:base_url, base_url)
    |> assign(:canonical_url, canonical_url)
    |> assign(:description, Map.get(page_meta, :description))
    |> assign(:og_image, og_image)
    |> assign(:og_image_alt, Map.get(page_meta, :og_image_alt) || page_meta.title)
    |> assign(:og_type, Map.get(page_meta, :og_type) || "website")
    |> assign(:json_ld, Map.get(page_meta, :json_ld))
    |> assign(:noindex, Map.get(page_meta, :noindex, false))
    |> assign(:supported_locales, supported_locales)
    |> assign(:site_name, Map.get(page_meta, :site_name))
    |> assign(:twitter_site, Map.get(page_meta, :twitter_site))
    |> assign(:locale, locale && to_string(locale))
    |> assign(:locale_alternates, locale_alternates)
  end

  # URL fields starting with http(s):// are rendered as-is. Relative paths
  # are prefixed with base_url so SEO tags carry absolute URLs as required
  # by Open Graph and canonical specs.
  defp resolve_url(_base_url, nil), do: nil
  defp resolve_url(_base_url, "http://" <> _ = url), do: url
  defp resolve_url(_base_url, "https://" <> _ = url), do: url
  defp resolve_url(base_url, path), do: base_url <> path

  defp escape_meta(text) do
    text |> String.replace("\"", "'") |> String.slice(0, 160)
  end
end
