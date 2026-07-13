defmodule Skia.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :skia,
    crate: "skia_native",
    base_url: "https://github.com/dannote/skia_ex/releases/download/v#{version}",
    force_build: System.get_env("SKIA_EX_BUILD") in ["1", "true"],
    targets: ~w(
      aarch64-apple-darwin
      x86_64-apple-darwin
      x86_64-unknown-linux-gnu
    ),
    version: version

  use Skia.Native.GeneratedStubs
end
