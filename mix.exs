# SPDX-License-Identifier: Apache-2.0

defmodule Mix.Tasks.Compile.Nif do
  @moduledoc false

  use Mix.Task.Compiler

  def run(_args) do
    make()
  end

  def clean do
    make("clean")
  end

  defp make(args \\ []) do
    {result, 0} = System.cmd("make", List.wrap(args), stderr_to_stdout: true)
    IO.binwrite(result)
  end
end

defmodule LibNFC.MixProject do
  use Mix.Project

  @source_url "https://github.com/maltoe/libnfc_ex"
  @version "0.1.0"

  def project do
    [
      name: "LibNFC",
      version: @version,
      source_url: @source_url,
      homepage_url: @source_url,
      app: :libnfc_ex,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      compilers: compilers(),
      deps: deps(),
      dialyzer: dialyzer(),
      docs: docs(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      lint: [
        "format --check-formatted",
        "credo --strict",
        "dialyzer --format dialyxir",
        "cmd make check"
      ]
    ]
  end

  defp compilers do
    [:nif] ++ Mix.compilers()
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "> 0.0.0", only: [:dev], runtime: false}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "_plts/dialyzer.plt"}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "LibNFC",
      extras: [
        "README.md": [title: "README"],
        "CHANGELOG.md": [title: "Changelog"],
        LICENSE: [title: "License"]
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      formatters: ["html"]
    ]
  end

  defp package do
    [
      description: "libnfc native wrapper",
      maintainers: ["@maltoe"],
      licenses: ["Apache-2.0"],
      links: %{
        Changelog: "https://hexdocs.pm/libnfc_ex/changelog.html",
        GitHub: @source_url
      }
    ]
  end
end
