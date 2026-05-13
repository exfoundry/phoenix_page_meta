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

    All three steps are idempotent — re-running the task is safe.

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
      case Igniter.Project.Module.find_and_update_module(igniter, web_module, fn zipper ->
             patch_live_view(zipper, web_module)
           end) do
        {:ok, igniter} ->
          igniter

        {:error, igniter} ->
          Igniter.add_warning(
            igniter,
            warning(web_module, "Could not find the web module.")
          )
      end
    end

    defp patch_live_view(zipper, web_module) do
      case Function.move_to_def(zipper, :live_view, 0) do
        :error ->
          {:warning, warning(web_module, "Could not find `def live_view`.")}

        {:ok, body} ->
          if already_wired?(body) do
            {:ok, zipper}
          else
            patch_quote_block(body, web_module)
          end
      end
    end

    defp patch_quote_block(body, web_module) do
      case move_to_quote_do(body) do
        :error ->
          {:warning, warning(web_module, "Found `def live_view` but no `quote do` block inside.")}

        {:ok, quote_body} ->
          case Igniter.Code.Module.move_to_use(quote_body, Phoenix.LiveView) do
            :error ->
              {:warning,
               warning(
                 web_module,
                 "Could not locate the `use Phoenix.LiveView` line inside `def live_view`."
               )}

            {:ok, use_call} ->
              {:ok, Common.add_code(use_call, @wiring_lines, placement: :after)}
          end
      end
    end

    # Idempotency check scoped to the `def live_view` body — looks for any
    # reference to `PhoenixPageMeta.LiveView` (the @behaviour or import).
    defp already_wired?(body_zipper) do
      case Common.move_to(body_zipper, fn z ->
             case Zipper.node(z) do
               {:__aliases__, _, parts} ->
                 Module.concat(parts) == PhoenixPageMeta.LiveView

               _ ->
                 false
             end
           end) do
        {:ok, _} -> true
        :error -> false
      end
    end

    # Find the `quote do ... end` block inside the function body and move
    # the zipper to the first expression inside its `do` block.
    defp move_to_quote_do(zipper) do
      with {:ok, quote_zipper} <- Function.move_to_function_call(zipper, :quote, 1) do
        Common.move_to_do_block(quote_zipper)
      end
    end

    defp warning(web_module, reason) do
      """
      phoenix_page_meta.install: #{reason} (web module: #{inspect(web_module)})
      Please add the following two lines manually after `use Phoenix.LiveView` inside
      `def live_view do ... quote do ...`:

      #{indent(@wiring_lines, "    ")}
      """
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
