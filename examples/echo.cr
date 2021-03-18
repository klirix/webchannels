require "../src/webchannels"

class EchoChannel < WebChannels::WebChannel

  @user : Int64?

  def authorize(socket, data, ctx)
    @user = socket.object_id
  end

  def on_message(socket, data)
    EchoChannel.fanout(data)
  end

  def on_join(socket, _data)
    puts "socket:#{@user} joined the echo party!!!"
  end

  def on_leave(socket)
    puts "socket:#{@user} left the echo party :("
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
spawn do
  100.times {
    EchoChannel.fanout "ECHOO ) ) )"
    sleep 10
    Fiber.yield
  }
end
server.listen
