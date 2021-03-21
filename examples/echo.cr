require "../src/webchannels"

class EchoChannel < WebChannels::WebChannel

  def on_message(data)
    EchoChannel.fanout(data)
  end

  def on_join(_data)
    puts "socket:#{@socket.object_id} joined the echo party!!!"
  end

  def on_leave()
    puts "socket:#{@socket.object_id} left the echo party :("
  end
end

class SecretChannel < WebChannels::WebChannel

  def self.authenticate(socket, data, ctx)
  end

end

class MyManifold < WebChannels::Manifold
  channel "echo", EchoChannel
end


# Same can be done with Kemal and would be even simpler!

server = HTTP::Server.new([
  HTTP::WebSocketHandler.new &MyManifold.handler
])

server.bind_tcp "0.0.0.0", 8080
puts "Listening!"
spawn do
  100.times {
    EchoChannel.fanout "ECHOO ) ) )"
    sleep 10
    Fiber.yield
  }
end
server.listen
