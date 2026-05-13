defmodule Mix.Tasks.PhoenixPageMeta.Install.Docs do
  @moduledoc false

  def short_doc, do: "Sets up phoenix_page_meta in the Phoenix project"

  def example, do: "mix phoenix_page_meta.install"

  def long_doc do
    """
    #{short_doc()}

    Performs three steps:

    1. Creates `<AppWeb>.PageMeta` — the project-local struct module that
       `use PhoenixPageMeta` injects behaviour and helpers into.

    2. Injects `<PhoenixPageMeta.Components.MetaTags.default>` into
       `lib/<app_web>/components/layouts/root.html.heex`, right before the
       existing `<.live_title` element.

    3. Adds `@behaviour PhoenixPageMeta.LiveView` and
       `import PhoenixPageMeta.LiveView, only: [assign_page_meta: 1]` after
       `use Phoenix.LiveView` inside the `def live_view` macro in the main
       web module.

    4. Adds `alias <AppWeb>.PageMeta` inside the `defp html_helpers` block in
       the main web module so that templates and LiveViews can reference
       `%PageMeta{}` directly.

    All four steps are idempotent — re-running the task is safe.

    ## Example

    ```sh
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.PhoenixPageMeta.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Code.Function
    alias Igniter.Libs.Phoenix, as: PhoenixIgniter
    alias Sourceror.Zipper

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :phoenix_page_meta,
        example: __MODULE__.Docs.example()
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      web_module = PhoenixIgniter.web_module(igniter)
      heex_path = root_layout_path(web_module)

      igniter
      |> create_page_meta_module(web_module)
      |> inject_meta_tags_component(heex_path)
      |> wire_live_view(web_module)
      |> alias_page_meta_in_html_helpers(web_module)
    end

    defp root_layout_path(web_module) do
      web_dir = web_module |> inspect() |> Macro.underscore()
      "lib/#{web_dir}/components/layouts/root.html.heex"
    end

    # -------------------------------------------------------------------------
    # Step 1: Create <AppWeb>.PageMeta
    # -------------------------------------------------------------------------

    defp create_page_meta_module(igniter, web_module) do
      page_meta_module = Module.concat(web_module, PageMeta)

      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, page_meta_module)

      if exists? do
        igniter
      else
        module_body = ~S"""
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
          supported_locales: [:en]
        ]
        """

        Igniter.Project.Module.create_module(igniter, page_meta_module, module_body)
      end
    end

    # -------------------------------------------------------------------------
    # Step 2: Inject MetaTags component into root.html.heex
    # -------------------------------------------------------------------------

    @metatags_marker "PhoenixPageMeta.Components.MetaTags"
    @inject_line ~s|<PhoenixPageMeta.Components.MetaTags.default page_meta={@page_meta} />|

    defp inject_meta_tags_component(igniter, heex_path) do
      Igniter.update_file(igniter, heex_path, fn source ->
        content = Rewrite.Source.get(source, :content)

        if String.contains?(content, @metatags_marker) do
          source
        else
          case detect_live_title_indent(content) do
            nil ->
              {:warning,
               """
               phoenix_page_meta.install: Could not inject MetaTags component into #{heex_path}.
               Expected to find a `<.live_title` element inside the <head> block, but it was not found.
               Please add the following line manually inside <head>, before <.live_title:

                   #{@inject_line}
               """}

            indent ->
              Rewrite.Source.update(source, :content, insert_before_live_title(content, indent))
          end
        end
      end)
    end

    # Returns the leading whitespace of the first line that contains `<.live_title`,
    # or `nil` if no such line exists. The detected indent is reused for the injected
    # line so it matches the surrounding HEEx formatting.
    defp detect_live_title_indent(content) do
      Regex.run(~r/^(\s*)<\.live_title/m, content, capture: :all_but_first)
      |> case do
        [indent] -> indent
        nil -> nil
      end
    end

    defp insert_before_live_title(content, indent) do
      Regex.replace(
        ~r/^(\s*<\.live_title)/m,
        content,
        "#{indent}#{@inject_line}\n\\1",
        global: false
      )
    end

    # -------------------------------------------------------------------------
    # Step 3: Wire LiveView callbacks in <AppWeb> web module
    # -------------------------------------------------------------------------

    @wiring_lines """
    @behaviour PhoenixPageMeta.LiveView
    import PhoenixPageMeta.LiveView, only: [assign_page_meta: 1]
    """

    defp wire_live_view(igniter, web_module) do
      patch_web_module(igniter, web_module, &patch_live_view(&1, web_module))
    end

    defp patch_live_view(zipper, web_module) do
      with {:ok, body} <- move_to_def_quote_body(zipper, :def, :live_view) do
        if already_wired?(body) do
          {:ok, zipper}
        else
          case Igniter.Code.Module.move_to_use(body, Phoenix.LiveView) do
            {:ok, use_call} ->
              {:ok, Common.add_code(use_call, @wiring_lines, placement: :after)}

            :error ->
              {:warning,
               warning(
                 web_module,
                 "Could not locate the `use Phoenix.LiveView` line inside `def live_view`."
               )}
          end
        end
      else
        {:error, reason} -> {:warning, warning(web_module, reason)}
      end
    end

    # Idempotency check scoped to the `def live_view` body — looks for any
    # reference to `PhoenixPageMeta.LiveView` (the @behaviour or import).
    defp already_wired?(body_zipper) do
      contains_alias_to?(body_zipper, PhoenixPageMeta.LiveView)
    end

    defp warning(web_module, reason) do
      """
      phoenix_page_meta.install: #{reason} (web module: #{inspect(web_module)})
      Please add the following two lines manually after `use Phoenix.LiveView` inside
      `def live_view do ... quote do ...`:

      #{indent(@wiring_lines, "    ")}
      """
    end

    # -------------------------------------------------------------------------
    # Step 4: alias <AppWeb>.PageMeta inside defp html_helpers
    # -------------------------------------------------------------------------

    defp alias_page_meta_in_html_helpers(igniter, web_module) do
      page_meta_module = Module.concat(web_module, PageMeta)
      alias_line = "alias #{inspect(page_meta_module)}"

      patch_web_module(igniter, web_module, fn zipper ->
        patch_html_helpers(zipper, page_meta_module, alias_line)
      end)
    end

    defp patch_html_helpers(zipper, page_meta_module, alias_line) do
      with {:ok, quote_body} <- move_to_def_quote_body(zipper, :defp, :html_helpers) do
        if contains_alias_to?(quote_body, page_meta_module) do
          {:ok, quote_body}
        else
          {:ok, Common.add_code(quote_body, alias_line, placement: :after)}
        end
      else
        {:error, reason} ->
          {:warning, alias_warning(page_meta_module, alias_line, reason)}
      end
    end

    defp alias_warning(target, alias_line, reason) do
      """
      phoenix_page_meta.install: Could not add `#{alias_line}` (#{reason}). \
      (target: #{inspect(target)})
      Please add the alias manually inside `defp html_helpers` so templates and
      LiveViews can reference `%PageMeta{}` without the prefix.
      """
    end

    # -------------------------------------------------------------------------
    # Shared helpers for web-module patching
    # -------------------------------------------------------------------------

    # Runs `fun` against the web module's zipper. The web-module-not-found
    # case becomes a warning rather than an error, so other steps still run.
    defp patch_web_module(igniter, web_module, fun) do
      case Igniter.Project.Module.find_and_update_module(igniter, web_module, fun) do
        {:ok, igniter} ->
          igniter

        {:error, igniter} ->
          Igniter.add_warning(
            igniter,
            "phoenix_page_meta.install: Could not find web module #{inspect(web_module)}."
          )
      end
    end

    # Navigates from a module zipper into the body of `quote do ... end` inside
    # the given def/defp. Returns {:ok, quote_body_zipper} | {:error, reason}.
    defp move_to_def_quote_body(zipper, kind, fun) when kind in [:def, :defp] do
      move =
        case kind do
          :def -> &Function.move_to_def/3
          :defp -> &Function.move_to_defp/3
        end

      with {:ok, body} <- wrap_err(move.(zipper, fun, 0), "`#{kind} #{fun}` not found"),
           {:ok, q} <-
             wrap_err(
               Function.move_to_function_call(body, :quote, 1),
               "no `quote do` block inside `#{kind} #{fun}`"
             ),
           {:ok, qb} <-
             wrap_err(
               Common.move_to_do_block(q),
               "no `do` block inside the `quote` of `#{kind} #{fun}`"
             ) do
        {:ok, qb}
      end
    end

    defp wrap_err({:ok, z}, _), do: {:ok, z}
    defp wrap_err(:error, reason), do: {:error, reason}

    # Returns true if a top-level `alias <Module>` exists anywhere under the
    # given zipper (used for idempotency checks against both Step 3 and Step 4).
    defp contains_alias_to?(zipper, target_module) do
      result =
        Common.move_to(zipper, fn z ->
          case Zipper.node(z) do
            {:__aliases__, _, parts} -> Module.concat(parts) == target_module
            _ -> false
          end
        end)

      match?({:ok, _}, result)
    end

    defp indent(text, prefix) do
      text
      |> String.trim_trailing()
      |> String.split("\n")
      |> Enum.map_join("\n", &(prefix <> &1))
    end
  end
else
  defmodule Mix.Tasks.PhoenixPageMeta.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'phoenix_page_meta.install' requires igniter. Please install igniter and try again.
      """)

      exit({:shutdown, 1})
    end
  end
end
