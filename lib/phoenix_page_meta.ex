defmodule PhoenixPageMeta do
  @moduledoc """
  Per-page metadata for Phoenix LiveView apps: breadcrumbs, active-link state,
  SEO meta tag rendering.

  ## Setup

  In your project's PageMeta module:

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
          :json_ld,
          :canonical_path,
          :icon,
          :skip_breadcrumb,
          og_type: "website",
          noindex: false,
          supported_locales: [:en, :es]
        ]
      end

  That's it. No `config.exs` entry. The macro provides default implementations
  of `base_url/0` (auto-detected from the module's namespace, e.g.
  `MyAppWeb.PageMeta` → `MyAppWeb.Endpoint.url()`) and `lang_path/2`
  (locale-prefix swap on `:path`). Both are `defoverridable` if you need a
  different scheme.

  ## use options

    * `:base_url` — accepts a string (`"https://example.com"`) or a 0-arity
      function capture (`&MyAppWeb.Endpoint.url/0`). When omitted, the macro
      guesses the Endpoint module from your PageMeta's namespace.

  ## In LiveViews

  In `MyAppWeb.live_view/0`:

      def live_view do
        quote do
          use Phoenix.LiveView, layout: ...
          @behaviour PhoenixPageMeta.LiveView
          import PhoenixPageMeta.LiveView, only: [assign_page_meta: 1]
        end
      end

  In each LiveView:

      defmodule MyAppWeb.SomeLive do
        use MyAppWeb, :live_view

        @impl PhoenixPageMeta.LiveView
        def page_meta(_socket, _action) do
          %MyAppWeb.PageMeta{title: "Hello", path: "/hello"}
        end

        def mount(_params, _session, socket) do
          {:ok, assign_page_meta(socket)}
        end
      end

  See `PhoenixPageMeta.Breadcrumb`, `PhoenixPageMeta.Components.Breadcrumbs`,
  `PhoenixPageMeta.Components.MetaTags`, `PhoenixPageMeta.Site`, and
  `PhoenixPageMeta.LiveView`.
  """

  @required_struct_fields [:title, :path, :parent]

  @doc """
  Injects the PhoenixPageMeta wiring into a project PageMeta module.

  Adds `@behaviour PhoenixPageMeta.Site`, default implementations of
  `base_url/0` and `lang_path/2` (both `defoverridable`), wrappers for
  `breadcrumbs/1` and `active?/2,3` that match the project struct, and an
  `@after_compile` hook that validates the struct has the required fields.
  """
  defmacro __using__(opts) do
    base_url_opt = Keyword.get(opts, :base_url)

    quote do
      @behaviour PhoenixPageMeta.Site
      @phoenix_page_meta_base_url unquote(Macro.escape(base_url_opt))

      @doc """
      Builds a breadcrumb trail. See `PhoenixPageMeta.Breadcrumb.build/1`.
      """
      def breadcrumbs(page_meta) when is_struct(page_meta, __MODULE__) do
        PhoenixPageMeta.Breadcrumb.build(page_meta)
      end

      @doc """
      Returns true if the link path matches this page or one of its ancestors.
      See `PhoenixPageMeta.active?/3`.
      """
      def active?(page_meta, link_path) when is_struct(page_meta, __MODULE__) do
        PhoenixPageMeta.active?(page_meta, link_path)
      end

      def active?(page_meta, link_path, opts) when is_struct(page_meta, __MODULE__) do
        PhoenixPageMeta.active?(page_meta, link_path, opts)
      end

      @impl PhoenixPageMeta.Site
      def base_url do
        PhoenixPageMeta.__resolve_base_url__(__MODULE__, @phoenix_page_meta_base_url)
      end

      @impl PhoenixPageMeta.Site
      def lang_path(page_meta, locale) when is_struct(page_meta, __MODULE__) do
        PhoenixPageMeta.__default_lang_path__(page_meta, locale)
      end

      defoverridable base_url: 0, lang_path: 2

      @after_compile {PhoenixPageMeta, :__validate_struct__}
    end
  end

  @doc """
  Returns true if the given link path matches the current page or one of its
  ancestor paths.

  ## Options

    * `:exact` — when `true`, only matches the current page exactly. Default `false`.
    * `:query` — when `true`, query strings are part of the comparison. When
      `false` (default), they are stripped from both sides before matching.

  ## Matching rules

  Without `:exact`, a link is active if its path equals the current path or is
  a prefix followed by `/`. So `/locations` matches `/locations` and
  `/locations/123`, but not `/location-foo`.

  Most projects call this via the project module's wrapper (e.g.
  `MyAppWeb.PageMeta.active?/2,3`), which restricts the input type via
  `%MyAppWeb.PageMeta{}` pattern. The lib-level function accepts any struct.
  """
  def active?(page_meta, link_path, opts \\ [])

  def active?(page_meta, link_path, opts)
      when is_struct(page_meta) and is_binary(link_path) and is_list(opts) do
    keep_query? = Keyword.get(opts, :query, false)
    exact? = Keyword.get(opts, :exact, false)
    current = page_meta.path

    {current, link_path} =
      if keep_query?,
        do: {current, link_path},
        else: {strip_query(current), strip_query(link_path)}

    cond do
      exact? -> current == link_path
      current == link_path -> true
      true -> String.starts_with?(current, link_path <> "/")
    end
  end

  @doc false
  def __validate_struct__(env, bytecode) do
    # Force-load the freshly compiled module so we can introspect its struct.
    case Code.ensure_loaded(env.module) do
      {:module, _} -> :ok
      {:error, _} -> :code.load_binary(env.module, String.to_charlist(env.file), bytecode)
    end

    unless function_exported?(env.module, :__struct__, 0) do
      raise CompileError,
        file: env.file,
        line: env.line,
        description:
          "PhoenixPageMeta: #{inspect(env.module)} must defstruct (with at least #{inspect(@required_struct_fields)})."
    end

    fields = env.module.__struct__() |> Map.keys()
    missing = @required_struct_fields -- fields

    if missing != [] do
      raise CompileError,
        file: env.file,
        line: env.line,
        description:
          "PhoenixPageMeta: #{inspect(env.module)} is missing required struct fields: #{inspect(missing)}. Add them to defstruct."
    end

    :ok
  end

  @doc false
  def __resolve_base_url__(_module, url) when is_binary(url), do: url
  def __resolve_base_url__(_module, fun) when is_function(fun, 0), do: fun.()

  def __resolve_base_url__(page_meta_module, nil) do
    guessed = __guess_endpoint__(page_meta_module)

    cond do
      not Code.ensure_loaded?(guessed) ->
        raise """
        PhoenixPageMeta could not auto-detect a base URL for #{inspect(page_meta_module)}.

        Tried `#{inspect(guessed)}` (sibling of your PageMeta module), but it
        could not be loaded.

        Pass it explicitly:

            use PhoenixPageMeta, base_url: "https://example.com"
            # or
            use PhoenixPageMeta, base_url: &#{inspect(guessed)}.url/0
        """

      not function_exported?(guessed, :url, 0) ->
        raise """
        PhoenixPageMeta found #{inspect(guessed)} but it does not export `url/0`.

        Pass `base_url:` explicitly to `use PhoenixPageMeta`.
        """

      true ->
        guessed.url()
    end
  end

  @doc false
  def __guess_endpoint__(page_meta_module) do
    page_meta_module
    |> Module.split()
    |> List.delete_at(-1)
    |> Kernel.++(["Endpoint"])
    |> Module.concat()
  end

  @doc false
  def __default_lang_path__(page_meta, locale) when is_struct(page_meta) do
    case String.split(page_meta.path, "/", trim: true) do
      [_old_locale | rest] -> "/" <> Enum.join([to_string(locale) | rest], "/")
      [] -> "/" <> to_string(locale)
    end
  end

  defp strip_query(path) do
    case :binary.split(path, "?") do
      [path, _] -> path
      [path] -> path
    end
  end
end
