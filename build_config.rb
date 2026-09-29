require "picoruby/cloudflare/build"

ENV["PICORUBY_USE_MRUBY_JSONRS"] = "1"

MRuby::CrossBuild.new("worker") do |conf|
  conf.cloudflare_worker! do |cf|
    # Optional overrides, applied before build setup:
    # cf.mruby_rack_mgem_dir = "vendor/mruby-rack"
    cf.picoruby_cloudflare_worker_wasm_revision = "0.11.0"
    # cf.mruby_rack_mgem_revision = "<commit SHA>"
  end

  # conf.gem gemdir: File.expand_path(ENV.fetch("PAVEMENT_ROOT", "../picoruby-pavement"), __dir__)
  conf.gem github: "udzura/picoruby-pavement", checksum_hash: "0.1.0"

  conf.worker_export(
    app: ENV.fetch("DEMO_TAPE_APP", "app.rb"),
    output_dir: "generated/worker",
    wrangler_config: "wrangler.jsonc",
    environment: ENV["CLOUDFLARE_ENV"],
    project_root: __dir__,
  )
end
