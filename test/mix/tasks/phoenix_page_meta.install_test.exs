defmodule Mix.Tasks.PhoenixPageMeta.InstallTest do
  use ExUnit.Case, async: true
  import Igniter.Test

  @web_module_src """
  defmodule TestWeb do
    @moduledoc \"\"\"
    The entrypoint for defining your web interface.
    \"\"\"

    def router do
      quote do
        use Phoenix.Router, helpers: false

        import Plug.Conn
        import Phoenix.Controller
        import Phoenix.LiveView.Router
      end
    end

    def live_view do
      quote do
        use Phoenix.LiveView

        unquote(html_helpers())
      end
    end

    def live_component do
      quote do
        use Phoenix.LiveComponent

        unquote(html_helpers())
      end
    end

    defp html_helpers do
      quote do
        use Phoenix.Component
        import Phoenix.HTML
        import TestWeb.CoreComponents
        alias Phoenix.LiveView.JS
        alias TestWeb.Layouts
      end
    end

    defmacro __using__(which) when is_atom(which) do
      apply(__MODULE__, which, [])
    end
  end
  """

  @root_heex """
  <!DOCTYPE html>
  <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <meta name="csrf-token" content={get_csrf_token()} />
      <.live_title default="Test" suffix=" · Phoenix Framework">
        {assigns[:page_title]}
      </.live_title>
      <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
      <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
      </script>
    </head>
    <body>
      {@inner_content}
    </body>
  </html>
  """

  defp base_project do
    test_project(
      files: %{
        "lib/test_web.ex" => @web_module_src,
        "lib/test_web/components/layouts/root.html.heex" => @root_heex
      }
    )
  end

  describe "phoenix_page_meta.install — step 1: PageMeta module" do
    test "creates TestWeb.PageMeta at the correct path" do
      base_project()
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_creates("lib/test_web/page_meta.ex")
    end

    test "created module has use PhoenixPageMeta, @enforce_keys, and defstruct with expected fields" do
      base_project()
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_creates("lib/test_web/page_meta.ex", """
      defmodule TestWeb.PageMeta do
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
      end
      """)
    end
  end

  describe "phoenix_page_meta.install — step 2: root.html.heex" do
    test "injects MetaTags component before <.live_title in root.html.heex" do
      base_project()
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_has_patch(
        "lib/test_web/components/layouts/root.html.heex",
        """
        + |    <PhoenixPageMeta.Components.MetaTags.default page_meta={@page_meta} />
        """
      )
    end

    test "warns when <.live_title anchor is missing from root.html.heex" do
      heex_without_live_title = """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
        </head>
        <body>
          {@inner_content}
        </body>
      </html>
      """

      test_project(
        files: %{
          "lib/test_web.ex" => @web_module_src,
          "lib/test_web/components/layouts/root.html.heex" => heex_without_live_title
        }
      )
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_has_warning(&String.contains?(&1, "Could not inject MetaTags component"))
    end
  end

  describe "phoenix_page_meta.install — step 3: LiveView wiring" do
    test "injects @behaviour and import after use Phoenix.LiveView in def live_view" do
      base_project()
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_has_patch("lib/test_web.ex", """
      + |      @behaviour PhoenixPageMeta.LiveView
      + |      import PhoenixPageMeta.LiveView, only: [assign_page_meta: 1]
      """)
    end

    test "warns when use Phoenix.LiveView is missing from def live_view" do
      web_module_without_use = """
      defmodule TestWeb do
        def live_view do
          quote do
            unquote(html_helpers())
          end
        end

        defp html_helpers do
          quote do
            use Phoenix.Component
          end
        end

        defmacro __using__(which) when is_atom(which) do
          apply(__MODULE__, which, [])
        end
      end
      """

      test_project(
        files: %{
          "lib/test_web.ex" => web_module_without_use,
          "lib/test_web/components/layouts/root.html.heex" => @root_heex
        }
      )
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_has_warning(&String.contains?(&1, "Could not locate the `use Phoenix.LiveView`"))
    end

    test "warns when def live_view is missing from the web module" do
      web_module_without_live_view = """
      defmodule TestWeb do
        def router do
          quote do
            use Phoenix.Router, helpers: false
          end
        end

        defmacro __using__(which) when is_atom(which) do
          apply(__MODULE__, which, [])
        end
      end
      """

      test_project(
        files: %{
          "lib/test_web.ex" => web_module_without_live_view,
          "lib/test_web/components/layouts/root.html.heex" => @root_heex
        }
      )
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_has_warning(&String.contains?(&1, "`def live_view` not found"))
    end
  end

  describe "phoenix_page_meta.install — step 4: PageMeta alias in html_helpers" do
    test "adds `alias TestWeb.PageMeta` inside defp html_helpers" do
      base_project()
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_has_patch("lib/test_web.ex", """
      + |      alias TestWeb.PageMeta
      """)
    end

    test "warns when defp html_helpers is missing" do
      web_module_without_helpers = """
      defmodule TestWeb do
        def live_view do
          quote do
            use Phoenix.LiveView
          end
        end

        defmacro __using__(which) when is_atom(which) do
          apply(__MODULE__, which, [])
        end
      end
      """

      test_project(
        files: %{
          "lib/test_web.ex" => web_module_without_helpers,
          "lib/test_web/components/layouts/root.html.heex" => @root_heex
        }
      )
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_has_warning(&String.contains?(&1, "`defp html_helpers` not found"))
    end
  end

  describe "phoenix_page_meta.install — idempotency" do
    test "re-running on an already-installed project produces no changes" do
      # Simulate an already-installed project by providing the patched files
      # directly, then running the installer again. No files should change.
      already_patched_heex = """
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="csrf-token" content={get_csrf_token()} />
          <PhoenixPageMeta.Components.MetaTags.default page_meta={@page_meta} />
          <.live_title default="Test" suffix=" · Phoenix Framework">
            {assigns[:page_title]}
          </.live_title>
          <link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
          <script defer phx-track-static type="text/javascript" src={~p"/assets/js/app.js"}>
          </script>
        </head>
        <body>
          {@inner_content}
        </body>
      </html>
      """

      already_wired_web = """
      defmodule TestWeb do
        def live_view do
          quote do
            use Phoenix.LiveView
            @behaviour PhoenixPageMeta.LiveView
            import PhoenixPageMeta.LiveView, only: [assign_page_meta: 1]

            unquote(html_helpers())
          end
        end

        defp html_helpers do
          quote do
            use Phoenix.Component
            alias TestWeb.PageMeta
          end
        end

        defmacro __using__(which) when is_atom(which) do
          apply(__MODULE__, which, [])
        end
      end
      """

      test_project(
        files: %{
          "lib/test_web.ex" => already_wired_web,
          "lib/test_web/components/layouts/root.html.heex" => already_patched_heex,
          "lib/test_web/page_meta.ex" => """
          defmodule TestWeb.PageMeta do
            use PhoenixPageMeta
            @enforce_keys [:title, :path]
            defstruct [:title, :path, :parent]
          end
          """
        }
      )
      |> Igniter.compose_task("phoenix_page_meta.install", [])
      |> assert_unchanged("lib/test_web/components/layouts/root.html.heex")
      |> assert_unchanged("lib/test_web.ex")
      |> assert_unchanged("lib/test_web/page_meta.ex")
    end
  end
end
