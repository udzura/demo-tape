class StreamApp
  def self.call(env)
    return [404, { "content-type" => "text/plain" }, ["Not found"]] unless env["PATH_INFO"] == "/stream"

    stream = Cloudflare::CustomReadableStream.new do |writer|
      30.times do |number|
        writer.write("data: chunk #{number + 1}\n\n")
      end
    end
    stream.on_error do |error|
      "event: error\ndata: #{error.class}: #{error.message}\n\n"
    end
    env["cloudflare.hijack"] = stream
    stream.finish
    [200, { "content-type" => "text/event-stream", "cache-control" => "no-store", "x-accel-buffering" => "no" }, []]
  end
end

Rackup::Handler::CloudflareWorker.run(StreamApp)
