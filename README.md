# PhoenixPageMeta

Per-page metadata for Phoenix LiveView apps: breadcrumbs, active-link state, SEO meta tag rendering. One struct per page, one render in the layout, no per-project re-implementation of the same logic in three different places.

## Why

Every Phoenix app I write ends up with the same trio: breadcrumb logic somewhere, active-link helpers duplicated across sidebar/nav/layout components, and a layout's worth of meta tags hand-built per project. PhoenixPageMeta standardises all three around a single struct that each LiveView declares once.

The struct lives explicitly in your project — full visibility, no macro that hides what fields you have. The macro injects only the wiring around it (behaviour, helpers, validation).

## Installation

```elixir
def deps do
  [{:phoenix_page_meta, "~> 0.1"}]
end
```

With [Igniter](https://hex.pm/packages/igniter), the installer sets up the PageMeta struct, root.html.heex meta tags, and LiveView wiring automatically:

```sh
mix igniter.install phoenix_page_meta
```

## Setup

One file. No `config.exs` entry.

```elixir
defmodule MyAppWeb.PageMeta do
  use PhoenixPageMeta

  @enforce_keys [:title, :path]
  defstruct [
    :title,
    :path,
    :breadcrumb_title,
    :parent,
    :description,
    :og_image,
    :og_image_alt,
    :json_ld,
    :canonical_path,
    :icon,
    :skip_breadcrumb,
    :locale,
    og_type: "website",
    noindex: false,
    supported_locales: [:en, :es],
    site_name: "MyApp",
    twitter_site: "@myapp"
  ]
end
```

`use PhoenixPageMeta` injects:
- `@behaviour PhoenixPageMeta.Site`
- `breadcrumbs/1` and `active?/2,3` wrappers that pattern-match `MyAppWeb.PageMeta`
- Default `base_url/0` (auto-detects `MyAppWeb.Endpoint.url()` from the namespace)
- Default `lang_path/2` (locale-prefix swap)
- `@after_compile` validation that `:title`, `:path`, `:parent` exist on the struct

Both defaults are `defoverridable` if your project deviates.

### `use` options

```elixir
use PhoenixPageMeta, base_url: "https://example.com"        # explicit string
use PhoenixPageMeta, base_url: &MyAppWeb.Endpoint.url/0     # explicit function capture
use PhoenixPageMeta                                          # auto-guess MyAppWeb.Endpoint
```

### Wire LiveView

In `MyAppWeb.live_view/0`:

```elixir
def live_view do
  quote do
    use Phoenix.LiveView, layout: {MyAppWeb.Layouts, :app}
    @behaviour PhoenixPageMeta.LiveView
    import PhoenixPageMeta.LiveView, only: [assign_page_meta: 1]
  end
end
```

## Usage

In each LiveView, implement `page_meta/2` and call `assign_page_meta/1` after data is loaded:

```elixir
defmodule MyAppWeb.LocationLive.Show do
  use MyAppWeb, :live_view

  @impl PhoenixPageMeta.LiveView
  def page_meta(socket, :show) do
    location = socket.assigns.location
    %MyAppWeb.PageMeta{
      title: location.name,
      path: ~p"/locations/#{location.slug}",
      description: location.summary,
      parent: %MyAppWeb.PageMeta{title: "Locations", path: ~p"/locations"}
    }
  end

  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:location, load_location(params))
     |> assign_page_meta()}
  end
end
```

In your root layout, render the meta tags:

```heex
<head>
  <PhoenixPageMeta.Components.MetaTags.default page_meta={@page_meta} />
  <.live_title>{@page_title}</.live_title>
</head>
```

In nav components, use `MyAppWeb.PageMeta.active?/2`:

```heex
<.link navigate={~p"/locations"} class={MyAppWeb.PageMeta.active?(@page_meta, ~p"/locations") && "active"}>
  Locations
</.link>
```

For breadcrumbs, use the slot-based component (handles `aria-label`, `aria-current`, divider placement):

```heex
<PhoenixPageMeta.Components.Breadcrumbs.list page_meta={@page_meta}>
  <:link :let={breadcrumb}>
    <.link navigate={breadcrumb.path} class="hover:underline truncate">
      <.icon :if={breadcrumb.page_meta.icon} name={breadcrumb.page_meta.icon} class="size-4" />
      {breadcrumb.title}
    </.link>
  </:link>
  <:current :let={breadcrumb}>
    <span class="font-medium truncate">{breadcrumb.title}</span>
  </:current>
  <:divider>
    <span class="text-base-content/30">/</span>
  </:divider>
</PhoenixPageMeta.Components.Breadcrumbs.list>
```

## Module structure

```
PhoenixPageMeta                          # __using__ macro, active?/2,3 (lib-level)
PhoenixPageMeta.Breadcrumb               # struct + build/1
PhoenixPageMeta.Components.Breadcrumbs   # list/1 component
PhoenixPageMeta.Components.MetaTags      # default/1 component (SEO)
PhoenixPageMeta.Site                     # behaviour: base_url/0, lang_path/2
PhoenixPageMeta.LiveView                 # behaviour: page_meta/2 + assign_page_meta/1
```

The components dispatch site-wide callbacks (`base_url`, `lang_path`) via `page_meta.__struct__` — no global config needed.

## Standard fields

| Field | Type | Notes |
|---|---|---|
| `:title` | `String.t()` | required |
| `:path` | `String.t()` | required |
| `:breadcrumb_title` | `String.t() \| nil` | falls back to `:title` in breadcrumbs |
| `:parent` | `t() \| nil` | parent page; walked for breadcrumbs (required field for the `@after_compile` check) |
| `:description` | `String.t() \| nil` | meta description, og:description, twitter:description |
| `:og_image` | `String.t() \| nil` | OG and Twitter image. Relative paths are auto-prefixed with `base_url`; absolute URLs (`http://`/`https://`) are rendered as-is |
| `:og_image_alt` | `String.t() \| nil` | alt text for og:image; falls back to `:title` |
| `:og_type` | `String.t()` | suggested default `"website"` |
| `:json_ld` | `map() \| nil` | rendered as `<script type="application/ld+json">` |
| `:canonical_path` | `String.t() \| nil` | overrides `:path` for canonical URL |
| `:noindex` | `boolean()` | suggested default `false` |
| `:locale` | `atom() \| nil` | current page's locale; renders `og:locale` |
| `:supported_locales` | `[atom()] \| nil` | hreflang tags + `og:locale:alternate` |
| `:site_name` | `String.t() \| nil` | renders `og:site_name`. Typically a project-wide defstruct default |
| `:twitter_site` | `String.t() \| nil` | renders `twitter:site` (e.g. `"@handle"`). Typically a project-wide defstruct default |
| `:skip_breadcrumb` | `boolean() \| nil` | when `true`, this page is filtered out of the breadcrumb (modals, overlays) |

`MetaTags.default` reads optional fields with `Map.get/2`, so your struct only needs the fields you actually use. Add project-specific fields freely (e.g. `:icon`, `:twitter_handle`, `:modal`).

## License

MIT
