defmodule Arb.MixProject do
  use Mix.Project

  def project do
    [
      app: :arb,
      version: "0.2.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      compilers: [:rustler] ++ Mix.compilers(),
      rustler_crates: rustler_crates(),
      deps: deps()
    ]
  end

  defp rustler_crates do
    [
      io: [
        path: "native/arb",
        mode: if(Mix.env() == :prod, do: :release, else: :debug)
      ]
    ]
  end

  defp deps do
    [
      {:rustler, "~> 0.16.0"}
    ]
  end
end
