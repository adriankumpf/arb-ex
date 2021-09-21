defmodule Arb.MixProject do
  use Mix.Project

  def project do
    [
      app: :arb,
      version: "0.7.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: "https://github.com/adriankumpf/arb-ex"
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.22"},
      {:nimble_options, "~> 0.3"},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end

  defp description() do
    """
    An Elixir NIF for controlling the ABACOM CH341A relay board.
    """
  end

  defp package() do
    [
      files: [
        "lib",
        "priv",
        "native/arb/.cargo/config",
        "native/arb/Cargo*",
        "native/arb/src",
        "mix.exs",
        "README*",
        "LICENSE*"
      ],
      maintainers: ["Adrian Kumpf"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/adriankumpf/arb-ex"}
    ]
  end

  defp docs do
    [
      main: "Arb",
      extras: ["README.md"]
    ]
  end
end
