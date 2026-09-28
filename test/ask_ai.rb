require "json"
require "stringio"
require_relative "../../picoruby-pavement/mrblib/pavement"

module Cloudflare
  class AI; end
end

module Rackup
  module Handler
    class CloudflareWorker
      def self.run(_app); end
    end
  end
end

load File.expand_path("../app.rb", __dir__)

class FakeAI < Cloudflare::AI
  attr_reader :model, :input

  def generate(model, input)
    @model = model
    @input = input
    Struct.new(:response).new("A test answer")
  end
end

class FakeBindings
  def initialize(ai)
    @ai = ai
  end

  def AI
    @ai
  end
end

ai = FakeAI.new
env = {
  "PATH_INFO" => "/mcp",
  "REQUEST_METHOD" => "POST",
  "HTTP_HOST" => "localhost",
  "CONTENT_TYPE" => "application/json",
  "HTTP_MCP_PROTOCOL_VERSION" => "2025-11-25",
  "cloudflare.env" => FakeBindings.new(ai),
  "rack.input" => StringIO.new(JSON.generate({
    "jsonrpc" => "2.0", "id" => 1, "method" => "tools/call",
    "params" => { "name" => "ask_ai", "arguments" => { "question" => "A question" } }
  }))
}
status, _, body = Application.call(env)
raise "HTTP #{status}: #{body.join}" unless status == 200
result = JSON.parse(body.join)["result"]
raise "tool failed" unless result["content"][0]["text"] == "A test answer" && !result["isError"]
raise "wrong model" unless ai.model == "@cf/meta/llama-3.3-70b-instruct-fp8-fast"
raise "wrong input" unless ai.input == { "prompt" => "A question", "max_tokens" => 256 }

puts "AI binding test passed"
