defmodule PhoenixPageMeta.Site do
  @moduledoc """
  Behaviour for site-wide PageMeta callbacks.

  Implemented by the project's PageMeta module (e.g. `MyAppWeb.PageMeta`).
  Both callbacks have sensible defaults injected by `use PhoenixPageMeta`,
  so you only implement them if your project deviates from the convention.

  ## Default implementations (via `use PhoenixPageMeta`)

    * `base_url/0` — returns the configured `:base_url` option (string or
      function-of-arity-0). When omitted, guesses the Endpoint from the
      module's namespace (e.g. `MyAppWeb.PageMeta` → `MyAppWeb.Endpoint.url()`).
    * `lang_path/2` — locale-prefix swap on `:path` (e.g. `/en/foo` → `/de/foo`).

  Both are `defoverridable` — provide your own implementation if needed:

      defmodule MyAppWeb.PageMeta do
        use PhoenixPageMeta

        @enforce_keys [:title, :path]
        defstruct [...]

        @impl PhoenixPageMeta.Site
        def lang_path(%__MODULE__{} = page_meta, locale) do
          # Custom routing scheme — e.g. query string instead of path prefix
          page_meta.path <> "?lang=" <> to_string(locale)
        end
      end
  """

  @doc """
  Returns the absolute base URL of the site (e.g. `"https://example.com"`).
  Used to build canonical and og:url tags.
  """
  @callback base_url() :: String.t()

  @doc """
  Returns the localized path for a page in a given locale. Used to render
  hreflang alternate links. Only called when a page has `:supported_locales`
  set.
  """
  @callback lang_path(page_meta :: struct(), locale :: atom()) :: String.t()
end
