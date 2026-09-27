# demo-tape

A small MCP server written in PicoRuby and served by Cloudflare Workers. The
Ruby framework lives in [`mgems/picoruby-pavement`](mgems/picoruby-pavement), and
[`app.rb`](app.rb) defines a `hello` tool and a `demo://about` resource.

## Run locally

Install Ruby 3.2 or later, Node.js supported by Wrangler, Emscripten, and a
nightly Rust toolchain with the `wasm32-unknown-emscripten` target. The Worker
uses `mruby-jsonrs` for JSON parsing and generation. Set
`PICORUBY_ROOT` to a PicoRuby checkout with initialized submodules. The first
build compiles PicoRuby to Wasm and can take several minutes.

```sh
rustup toolchain install nightly
rustup target add wasm32-unknown-emscripten --toolchain nightly
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
hostnames.

## Authentication with Cloudflare Access

Local `npm run dev` remains available on loopback without authentication. To
protect a deployed Worker, use Cloudflare Access in front of the entire Worker:

1. Deploy the Worker, then open **Workers & Pages → demo-tape → Access** in the
   Cloudflare dashboard. Choose **Protect this Worker behind Access** and
   **All traffic**, then add an Allow policy for the intended users. This
   protects its `workers.dev` URL, custom domains, routes, and previews.
2. In **Zero Trust → Access controls → Applications**, edit the resulting
   self-hosted Access application. Enable **Managed OAuth** under **Advanced
   settings**. Allow the MCP client's exact OAuth redirect URI; for local Codex
   clients, enable the localhost or loopback redirect option as needed.
3. Set the Worker's `MCP_ALLOWED_HOSTS` variable to its public hostname. Connect
   an OAuth-capable MCP client to `https://<hostname>/mcp` and complete the
   Access sign-in. No Access credentials need to be stored in this repository.

Managed OAuth gives non-browser MCP clients an OAuth challenge instead of a
browser login redirect. The client must support OAuth resource indicators
(RFC 8707). Before connecting a client, check that an unauthenticated request
to the public `/mcp` endpoint gets an Access `401` response with a
`WWW-Authenticate` header. Access runs before the Worker, so the Ruby handlers
only receive requests allowed by its policy. This configuration is performed
in Cloudflare; `npm run dev` does not emulate it.

See Cloudflare's [Worker Access setup](https://developers.cloudflare.com/workers/configuration/cloudflare-access/)
and [Managed OAuth setup](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/managed-oauth/)
for the dashboard settings.

## Build configuration

`build_config.rb` adds the local mgem to the Worker build. The template gem pins
its Worker and Rack mgems; see `build_config.rb` to override them with local
checkouts during development. Do not edit `generated/worker/` directly.

Commit `Gemfile.lock` and `package-lock.json`. Deployment is separate from local
development and uses `npm run deploy`.
