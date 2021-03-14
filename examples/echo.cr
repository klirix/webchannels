require "../src/webchannels"

class EchoChannel < WebChannels::WebChannel
  def on_message(socket, data)
    fanout(data)
  end

  def on_join(socket, _data, _ctx)
    puts "socket:#{socket.object_id} joined the echo party!!!"
  end

  def on_leave(socket)
    puts "socket:#{socket.object_id} left the echo party :("
  end
end

class MyManifold < WebChannels::Manifold
  channel "echo", EchoChannel
end

# Same can be done with Kemal and would be even simpler!
sockethandler = HTTP::WebSocketHandler.new &MyManifold.handler

server = HTTP::Server.new([sockethandler])

server.bind_tcp "0.0.0.0", 8080
puts "Listening!"
server.listen
