# demo-tape

A small MCP server written in PicoRuby and served by Cloudflare Workers. The
Ruby framework lives in [`mgems/picoruby-pavement`](mgems/picoruby-pavement), and
[`app.rb`](app.rb) defines a `hello` tool and a `demo://about` resource.

## Run locally

Install Ruby 3.2 or later, Node.js supported by Wrangler, and Emscripten. Set
`PICORUBY_ROOT` to a PicoRuby checkout with initialized submodules. The first
build compiles PicoRuby to Wasm and can take several minutes.

```sh
export PICORUBY_ROOT=/path/to/picoruby
bundle install
npm install
npm run dev
```

Wrangler serves the MCP endpoint at `http://127.0.0.1:8787/mcp`. It runs the
PicoRuby build on startup and watches `app.rb`, `build_config.rb`, and `mgems`.
Run `npm run test:dev` in another terminal to exercise the live endpoint.

## Ruby DSL

```ruby
class Application < Pavement::Base
  tool "hello" do
    description "Greet someone"
    input do
      string :name, required: true
      boolean :shout, default: false
    end
    call do |name:, shout:|
      greeting(name, shout)
    end
  end

  resource "demo://about" do
    name "About demo-tape"
    read { about_text }
  end

  def greeting(name, shout)
    message = "Hello, #{name}!"
    shout ? message.upcase : message
  end

  def about_text
    "A PicoRuby MCP server on Cloudflare Workers."
  end
end

Rackup::Handler::CloudflareWorker.run(Application)
```

Each request runs `call` and `read` blocks on a fresh `Application` instance,
so they can call its instance methods. `env` returns that request's Rack env
hash. For example, `env["HTTP_HOST"]` reads the Host header, and
`env["cloudflare.env"]` accesses configured Worker bindings.

`input` currently supports `string`, `integer`, and `boolean` properties, plus
`required`, `default`, and `description`. The gem turns these declarations into
JSON Schema and validates tool arguments before calling Ruby. The framework
handles JSON-RPC and JSON responses for the MCP 2026-07-28 Streamable HTTP
revision: `server/discover`, `tools/list`, `tools/call`, `resources/list`, and
`resources/read`. It also accepts the 2025-03-26, 2025-06-18, and 2025-11-25
Streamable HTTP handshake for current clients. This first demo uses JSON
responses only; it does not implement prompts, SSE, or subscriptions.

The endpoint accepts only `localhost` and `127.0.0.1` Host headers by default.
For another hostname, set `MCP_ALLOWED_HOSTS` to a comma-separated list of
hostnames. The endpoint has no authentication and is intended for local
development. Add authentication before deploying a server that exposes private
data or actions.

## Build configuration

`build_config.rb` adds the local mgem to the Worker build. The template gem pins
its Worker and Rack mgems; see `build_config.rb` to override them with local
checkouts during development. Do not edit `generated/worker/` directly.

Commit `Gemfile.lock` and `package-lock.json`. Deployment is separate from local
development and uses `npm run deploy`.
