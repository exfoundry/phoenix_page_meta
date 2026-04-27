# Changelog

## [0.1.0] - 2026-04-27

### Added
- `use PhoenixPageMeta` macro — single line of setup in `MyAppWeb.PageMeta`. Injects `@behaviour PhoenixPageMeta.Site`, `breadcrumbs/1` and `active?/2,3` wrappers (pattern-matched to the project struct), default `base_url/0` and `lang_path/2` (both `defoverridable`), and `@after_compile` field validation.
- `PhoenixPageMeta.Breadcrumb` — struct (`:title`, `:path`, `:first?`, `:last?`, `:page_meta`) + `build/1` (walks `:parent` chain, filters `:skip_breadcrumb`).
- `PhoenixPageMeta.Components.Breadcrumbs.list/1` — slot-based HEEx component owning `<nav aria-label>`, `aria-current="page"`, and divider placement. Accepts `:rest` globals (e.g. `class`).
- `PhoenixPageMeta.Components.MetaTags.default/1` — HEEx component rendering description, Open Graph (`og:type`, `og:url`, `og:title`, `og:description`, `og:image`, `og:image:alt`, `og:site_name`, `og:locale`, `og:locale:alternate`), Twitter Card (`twitter:card`, `twitter:title`, `twitter:description`, `twitter:image`, `twitter:site`), JSON-LD, canonical, and hreflang alternate tags. Reads optional fields with `Map.get/2`.
- URL fields (`og_image`, `canonical_path`) auto-prefixed with `base_url` when relative. Absolute URLs (`http://`/`https://`) rendered as-is.
- New struct fields recognised by `MetaTags`: `:site_name` (renders `og:site_name`), `:twitter_site` (renders `twitter:site`), `:og_image_alt` (renders `og:image:alt`, falls back to `:title`), `:locale` (renders `og:locale` and derives `og:locale:alternate` from the rest of `:supported_locales`).
- `PhoenixPageMeta.active?/2,3` — link path matching against the current page (`exact:` and `query:` opts), with slash-boundary prefix matching.
- `PhoenixPageMeta.Site` — behaviour for site-wide callbacks (`base_url/0`, `lang_path/2`).
- `PhoenixPageMeta.LiveView` — behaviour for the per-LiveView `page_meta/2` callback, plus `assign_page_meta/1` helper.
- Components dispatch site-wide callbacks via `page_meta.__struct__` — no global config.
- `:base_url` option on `use` accepts a string or a 0-arity function capture. When omitted, the macro guesses `MyAppWeb.Endpoint.url()` from the namespace.
- `:lang_path/2` default does locale-prefix swap; override for non-prefix locale schemes.
