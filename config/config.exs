import Config

# This repo is the source: always build from the checkout. Until a version is
# tagged and built there is nothing published under it to download anyway, so
# without this a clean clone cannot compile at all. Not shipped in the package —
# consumers reach for `ARB_BUILD` instead.
config :rustler_precompiled, :force_build, arb: true
