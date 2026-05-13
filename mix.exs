defmodule PhoenixPageMeta.MixProject do
  use Mix.Project

  @version "0.1.2"
  @source_url "https://github.com/exfoundry/phoenix_page_meta"

  def project do
    [
      app: :phoenix_page_meta,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      name: "PhoenixPageMeta",
      source_url: @source_url,
      docs: [
        main: "PhoenixPageMeta",
        source_ref: "v#{@version}",
        extras: ["CHANGELOG.md"],
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
      ]
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [preferred_envs: [precommit: :test]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      precommit: [
        "compile --warning-as-errors",
        "format --check-formatted",
        "test"
      ]
    ]
  end

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      {:jason, "~> 1.4"},
      {:igniter, "~> 0.8", optional: true},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Per-page metadata for Phoenix LiveView: breadcrumbs, active-link state, SEO tags."
  end

  defp package do
    [
      maintainers: ["Elias Forge"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/phoenix_page_meta/changelog.html"
      },
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE usage-rules.md)
    ]
  end
end
