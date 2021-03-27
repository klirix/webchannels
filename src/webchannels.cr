require "http"
require "json"

require "./pubsub"

class WebChannel(Data) < PubSub({
    data: Data,
    topic: String?,
    id: String
  })

  def self.make_channel
    Channel({
      data: Data,
      topic: String?,
      id: String
    }).new
  end

  macro id(name)
    @id = {{name}}
  end

  # def publish(topic : String, data : M)

  #   previous_def({
  #     data: data,
  #     topic: topic,
  #     id: @id
  #   })
  # end

end

class EchoChannel < WebChannel(String)

  id "echo"

  def on_message(message)
    puts "broadcasting #{message} to echo"
    # broadcast(message)
  end

  def join(conn : Connection)
    puts "connection joined #{conn.socket.object_id}"
    subscribe("echo", conn.channel_notifications)
  end

end

class Manifold
  class_property channels = {
    "echo" => EchoChannel.new
  }

  @@channels.each_value &.run
end

class Connection
  property socket : HTTP::WebSocket
  property channel_notifications = WebChannel(String).make_channel
  @channels = [] of WebChannel(String)

  def initialize(@socket)
    # In message processing
    @socket.on_message do |message|
      if join = message.match(/join:(.*)/)
        puts "Joining #{join[1]}"
        if channel = Manifold.channels[join[1]]?
          channel.join(self)
          puts "Joined #{join[1]}"
        end
      end
      if join = message.match(/data:(.*)/)
        Manifold.channels["echo"].on_message(join[1])
      end
    end

    # Out message processing
    spawn do
      puts "Socket #{@socket.object_id} listening for data"
      while notification = @channel_notifications.receive?
        puts " #{@socket.object_id} Received something"
        @socket.send(notification[:data])
      end
    end
  end
end

server = HTTP::Server.new(HTTP::WebSocketHandler.new do |socket, ctx|
  Connection.new socket
end)

server.listen 8080
