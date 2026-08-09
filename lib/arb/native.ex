defmodule Arb.Native do
  @moduledoc false

  # The NIF stubs, kept off `Arb` so that the module users read the docs of is
  # plain Elixir and exposes nothing it does not mean to. `Inspect.Arb.Board`
  # reaches `describe/1` through here rather than through a public `Arb` function
  # that exists only for it.

  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :arb,
    crate: "arb_native",
    base_url: "https://github.com/adriankumpf/arb-ex/releases/download/v#{version}",
    version: version,
    force_build: System.get_env("ARB_BUILD") in ["1", "true"],
    # NIF 2.16 is OTP 24, the oldest this package supports, and a NIF is
    # forwards compatible within a major.
    nif_versions: ["2.16"],
    # Must match what `.github/workflows/release.yml` builds: a target listed
    # here but not built gets a download error instead of the source build it
    # needs. Windows is left out on purpose — rusb can only reach a device there
    # through a WinUSB/libusbK driver installed by hand, so an artifact would not
    # make a board work anyway.
    targets: ~w(
      aarch64-apple-darwin
      x86_64-apple-darwin
      aarch64-unknown-linux-gnu
      aarch64-unknown-linux-musl
      arm-unknown-linux-gnueabihf
      x86_64-unknown-linux-gnu
      x86_64-unknown-linux-musl
    )

  def open, do: :erlang.nif_error(:nif_not_loaded)
  def board(_usb, _port), do: :erlang.nif_error(:nif_not_loaded)
  def boards(_usb), do: :erlang.nif_error(:nif_not_loaded)
  def describe(_board), do: :erlang.nif_error(:nif_not_loaded)
  def set_relays(_board, _ids, _verify), do: :erlang.nif_error(:nif_not_loaded)
  def relays(_board), do: :erlang.nif_error(:nif_not_loaded)
  def self_test(_board), do: :erlang.nif_error(:nif_not_loaded)
  def reset_device(_board), do: :erlang.nif_error(:nif_not_loaded)
end
