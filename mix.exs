defmodule Arb.MixProject do
  use Mix.Project

  @source_url "https://github.com/adriankumpf/arb-ex"
  @version "0.20.0-rc.0"

  def project do
    [
      app: :arb,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.38.0", runtime: false},
      {:nimble_options, "~> 1.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    An Elixir NIF for controlling the ABACOM CH341A relay board.
    """
  end

  defp package do
    [
      files: [
        "lib",
        # No "priv": it would ship the build host's `arb_native.so` to every
        # platform, and it would be preferred over the artifact.
        "native/arb_native/.cargo/config.toml",
        "native/arb_native/Cargo*",
        "native/arb_native/src",
        "mix.exs",
        "README*",
        "CHANGELOG*",
        "LICENSE*"
      ],
      maintainers: ["Adrian Kumpf"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
