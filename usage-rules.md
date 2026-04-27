# phoenix_page_meta usage rules

Rules apply to `phoenix_page_meta ~> 0.1`.

Per-page metadata for Phoenix LiveView apps: breadcrumbs, active-link state,
SEO meta tag rendering. Each LiveView declares one `%MyAppWeb.PageMeta{}` per
action; the package handles the rest.

## The shape

You always have **two modules**:

1. **`MyAppWeb.PageMeta`** (project-local) — `use PhoenixPageMeta` + explicit
   `defstruct`. The macro injects behaviour, helpers, default callbacks, and
   field validation.
2. **Each LiveView** — implements `PhoenixPageMeta.LiveView` callback
   `page_meta/2`, calls `assign_page_meta/1` after data is loaded.

```elixir
defmodule MyAppWeb.PageMeta do
  use PhoenixPageMeta

  @enforce_keys [:title, :path]
  defstruct [
    :title, :path, :breadcrumb_title, :parent, :description,
    :og_image, :json_ld, :canonical_path, :icon, :skip_breadcrumb,
    og_type: "website",
    noindex: false,
    supported_locales: [:en, :es]
  ]
end
```

No `config.exs` entry. No `Application` setup.

## What `use PhoenixPageMeta` injects

- `@behaviour PhoenixPageMeta.Site`
- `breadcrumbs(page_meta)` — wrapper that pattern-matches `MyAppWeb.PageMeta`,
  delegates to `PhoenixPageMeta.Breadcrumb.build/1`
- `active?(page_meta, link_path)` and `/3` — same pattern
- `base_url/0` — default returns the configured `:base_url` option (or auto-
  detected `MyAppWeb.Endpoint.url()`). `defoverridable`.
- `lang_path/2` — default does locale-prefix swap (`/en/foo` → `/de/foo`).
  `defoverridable`.
- `@after_compile` validation — fails compile if `:title`, `:path`, `:parent`
  are not on the struct.

## `use` options

```elixir
use PhoenixPageMeta, base_url: "https://example.com"
use PhoenixPageMeta, base_url: &MyAppWeb.Endpoint.url/0
use PhoenixPageMeta                                       # auto-guess endpoint
```

The auto-guess swaps the last segment of the namespace with `Endpoint`
(`MyAppWeb.PageMeta` → `MyAppWeb.Endpoint`). Works for standard Phoenix
layouts. Pass explicitly for umbrellas or non-standard structures.

## Module structure

```
PhoenixPageMeta                          # __using__ macro, active?/2,3 (lib-level)
PhoenixPageMeta.Breadcrumb               # struct + build/1
PhoenixPageMeta.Components.Breadcrumbs   # list/1 component
PhoenixPageMeta.Components.MetaTags      # default/1 component
PhoenixPageMeta.Site                     # behaviour: base_url/0, lang_path/2
PhoenixPageMeta.LiveView                 # behaviour: page_meta/2 + assign_page_meta/1
```

Components dispatch `base_url/0` and `lang_path/2` via `page_meta.__struct__` —
no global config.

## Standard fields

`:title` and `:path` are required (`@enforce_keys`). `:parent` is required by
the `@after_compile` validation (used to walk breadcrumbs). Standard
renderable fields: `:breadcrumb_title`, `:description`, `:og_image`,
`:og_image_alt`, `:og_type`, `:json_ld`, `:canonical_path`, `:noindex`,
`:locale`, `:supported_locales`, `:site_name`, `:twitter_site`,
`:skip_breadcrumb`.

URL fields (`og_image`, `canonical_path`, `path`) accept either absolute URLs
(`https://...`) or relative paths (`/foo`). Relative paths are auto-prefixed
with `base_url` at render time. So `og_image: "/images/og.png"` in your
defstruct default produces `<meta property="og:image"
content="https://example.com/images/og.png" />`.

`:site_name` and `:twitter_site` are typically project-wide defstruct
defaults (e.g. `site_name: "MyApp"`, `twitter_site: "@myapp"`); rarely
overridden per page.

`MetaTags.default` reads optional fields with `Map.get/2`, so your struct only
needs the fields you use. Add project-specific fields freely (e.g. `:icon`,
`:twitter_handle`, `:modal`).

## LiveView pattern

```elixir
# In MyAppWeb.live_view/0:
quote do
  use Phoenix.LiveView, layout: ...
  @behaviour PhoenixPageMeta.LiveView
  import PhoenixPageMeta.LiveView, only: [assign_page_meta: 1]
end

# In each LiveView:
@impl PhoenixPageMeta.LiveView
def page_meta(socket, :show) do
  %MyAppWeb.PageMeta{
    title: socket.assigns.location.name,
    path: ~p"/locations/#{socket.assigns.location.slug}",
    parent: %MyAppWeb.PageMeta{title: "Locations", path: ~p"/locations"}
  }
end

def handle_params(params, _uri, socket) do
  {:noreply,
   socket
   |> assign(:location, load_location(params))
   |> assign_page_meta()}
end
```

## active?/2,3

```elixir
MyAppWeb.PageMeta.active?(page_meta, "/locations")              # prefix match, query stripped
MyAppWeb.PageMeta.active?(page_meta, "/locations", exact: true) # exact match only
MyAppWeb.PageMeta.active?(page_meta, "/x?tab=open", query: true) # raw match (filter tabs)
```

The wrapper guards on `is_struct(page_meta, MyAppWeb.PageMeta)` — wrong type =
`FunctionClauseError`.

Without `:exact`, a path is active if it equals the current path or is a
prefix followed by `/`. `/locations` is active on `/locations/123` but not on
`/location-foo`.

## breadcrumbs

`MyAppWeb.PageMeta.breadcrumbs/1` (delegates to
`PhoenixPageMeta.Breadcrumb.build/1`) walks the `:parent` chain and returns
root-first `[%PhoenixPageMeta.Breadcrumb{title, path, first?, last?, page_meta}]`.

Pages with `:skip_breadcrumb: true` are filtered out — useful for modal or
overlay routes that should not appear as breadcrumb entries.

## Layout

```heex
<head>
  <PhoenixPageMeta.Components.MetaTags.default page_meta={@page_meta} />
  <.live_title suffix=" | MyApp">{@page_title}</.live_title>
</head>
```

## Breadcrumbs component

Slot-based, owns `<nav aria-label>`, `aria-current="page"`, divider placement.
Accepts `:rest` globals on `<nav>` (e.g. `class`). Renders nothing when the
trail is empty.

```heex
<PhoenixPageMeta.Components.Breadcrumbs.list page_meta={@page_meta}>
  <:link :let={breadcrumb}>
    <.link navigate={breadcrumb.path}>
      <.icon :if={breadcrumb.page_meta.icon} name={breadcrumb.page_meta.icon} />
      {breadcrumb.title}
    </.link>
  </:link>
  <:current :let={breadcrumb}>
    <span>{breadcrumb.title}</span>
  </:current>
  <:divider>/</:divider>
</PhoenixPageMeta.Components.Breadcrumbs.list>
```

## Do

- **Always set `:path`.** Required, used by canonical, og:url, hreflang,
  active-link matching.
- **Use `:parent` for hierarchy**, not URL prefix tricks. The parent chain is
  the source of truth for breadcrumbs.
- **Call `assign_page_meta/1` last** in mount/handle_params, after all assigns
  the `page_meta/2` callback reads are set.
- **Set `:canonical_path`** when the same content lives at multiple paths
  (filtered listings, pagination).
- **Set `:skip_breadcrumb: true`** on modal/overlay routes so the breadcrumb
  reflects the underlying page.
- **Override `lang_path/2`** if your project uses a non-prefix locale scheme
  (e.g. query string, subdomain).

## Don't

- **Don't define the struct in the package.** It lives in `MyAppWeb.PageMeta`
  so all fields and defaults are visible in your code.
- **Don't add `config :phoenix_page_meta, ...`.** The package reads no config.
- **Don't render breadcrumbs by hand if you can use the component.** It owns
  the a11y bits (aria-label, aria-current) and divider placement.
- **Don't set `:supported_locales` without ensuring `lang_path/2` works for
  your paths.** The default assumes `/<locale>/...` structure.

## Configuration

None. The package reads no `config :phoenix_page_meta, ...` keys. Pass
`base_url:` to `use PhoenixPageMeta` directly when needed.
