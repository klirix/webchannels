require "http"
require "json"

require "./pubsub"

record WebChannelMessage(T),
  data : T,
  topic : String?,
  channel : String

abstract class WebChannel(T)

  abstract def on_message(data : T)

  abstract def id : String

  def self.make_channel
    Channel(WebChannelMessage(T)).new
  end

  @pubsub = PubSub(WebChannelMessage(T)).new

  def initialize
    @pubsub.run
  end

  def broadcast(data : T)
    @pubsub.broadcast(WebChannelMessage.new(
      data: data, topic: nil, channel: id
    ))
  end

end

class EchoChannel < WebChannel(String)

  getter id : String = "echo"

  def on_message(message)
    puts "broadcasting #{message} to echo"
    broadcast(message)
  end

  def join(conn : Connection)
    puts "connection joined #{conn.socket.object_id}"
    @pubsub.subscribe("echo", conn.channel_notifications)
  end

end

class Manifold
  class_property channels = {
    "echo" => EchoChannel.new
  }
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
        @socket.send(notification.data)
      end
    end
  end
end

server = HTTP::Server.new(HTTP::WebSocketHandler.new do |socket, ctx|
  Connection.new socket
end)

server.listen 8080
