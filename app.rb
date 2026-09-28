class Application < Pavement::Base
  server_info name: "demo-tape", version: "0.1.0"

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

  tool "ask_ai" do
    description "Ask Cloudflare Workers AI a question"
    input do
      string :question, required: true, description: "Question to send to the AI model"
    end
    call do |question:|
      ask_ai(question)
    end
  end

  def ask_ai(question)
    model = "@cf/meta/llama-3.3-70b-instruct-fp8-fast"
    ai = env["cloudflare.env"].AI
    ai.generate(model, { "prompt" => question, "max_tokens" => 256 }).response
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
