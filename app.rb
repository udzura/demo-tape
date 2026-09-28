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

  tool "sum" do
    description "Add two integers and return a structured result"
    input do
      integer :left, required: true
      integer :right, required: true
    end
    output do
      integer :sum, required: true
    end
    call do |left:, right:|
      { sum: left + right }
    end
  end

  tool "slow_progress" do
    description "Show progress while making three delayed HTTP requests"
    enable :progress
    output { integer :completed, required: true }
    call { run_slow_progress }
  end

  def ask_ai(question)
    model = "@cf/meta/llama-3.3-70b-instruct-fp8-fast"
    ai = env["cloudflare.env"].AI
    ai.generate(model, { "prompt" => question, "max_tokens" => 256 }).response
  end

  def run_slow_progress
    total = 3
    progress(0, total: total, message: "Starting delayed requests")
    total.times do |index|
      response = Cloudflare.fetch("https://httpbin.org/delay/1")
      raise "httpbin returned HTTP #{response.status}" unless response.status == 200
      progress(index + 1, total: total, message: "Completed #{index + 1} of #{total} requests")
    end
    { completed: total }
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
