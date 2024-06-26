defmodule Arb.MixProject do
  use Mix.Project

  def project do
    [
      app: :arb,
      version: "0.12.0",
      elixir: "~> 1.13",
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
      {:rustler, "~> 0.33"},
      {:nimble_options, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
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
        "native/arb/.cargo/config.toml",
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
