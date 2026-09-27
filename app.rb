class Application < Pavement::Base
  tool "hello" do
    description "Greet someone from PicoRuby on Cloudflare Workers"
    input do
      string :name, required: true, description: "Name to greet"
      boolean :shout, default: false, description: "Use uppercase letters"
    end
    call do |name:, shout:|
      greeting(name, shout)
    end
  end

  resource "demo://about" do
    name "About demo-tape"
    description "What this PicoRuby MCP demo exposes"
    mime_type "text/plain"
    read do
      about_text
    end
  end

  def greeting(name, shout)
    message = "Hello, #{name}!"
    shout ? message.upcase : message
  end

  def about_text
    "demo-tape is a PicoRuby MCP server running on Cloudflare Workers."
  end
end

Rackup::Handler::CloudflareWorker.run(Application)
