require "http"
require "json"
require "colorize"

struct Message
  include JSON::Serializable

  property event : String
  property channel : String
  property data : String
end

abstract class WebChannel
  @@sockets : Set(self) = Set(self).new
  @@topic_sockets = {} of String => Set(self)
  property socket : HTTP::WebSocket
  property topics = [] of String

  def fanout(data : String | Bytes)
    @@sockets.each &.send(data)
    print "Fanout #{data} to everyone"
  end

  def self.broadcast(topic, data)
    @@topic_sockets[topic].each &.send(data)
  end

  def broadcast(topic, data)
    @@topic_sockets[topic].each &.send(data)
  end

  def on_message(data : String, socket : HTTP::WebSocket)
  end

  def on_subscribe(data)
  end

  def subscribe(topic : String)
    topics << topics
    @@topic_sockets[topic] << self
    puts "Socket #{@socket.object_id} subscribed to #{topic}"
  end

  def unsubscribe(topic : String)
    topics.delete topic
    @@topic_sockets[topic].delete self
    puts "Socket #{@socket.object_id} unsubscribed from #{topic}"
  end

  def initialize(@socket)
    puts "Socket #{@socket.object_id} connected to #{self.class.name}"
    @socket.on_message do |s|
      on_message s, @socket
    end
    @@sockets << self
  end

  def send(data : String | Bytes)
    @socket.send(data)
  end
end

class Manifold
  @@channels = [] of Tuple(String, WebChannel.class)

  macro channel(channel, channel_class)
    @@channels << { {{channel}} , {{channel_class}} }
  end

  def self.handler() : HTTP::WebSocket, HTTP::Server::Context ->
    Proc(HTTP::WebSocket, HTTP::Server::Context, Void).new do |socket, ctx|
      socket.on_message do |data|
        msg = Message.from_json data
        case msg.event
        when "subscribe"
          if pair = @@channels.find {|x| x[0] == msg.channel}
            klass = pair[1]
            klass.new(socket)
            socket.send("ok")
          end
        else
          puts "Weird command lmao"
        end
      rescue ex : JSON::ParseException
        socket.send({error: "Failed to parse JSON"}.to_json)
        puts "error parsing message"
      rescue
        puts "unexpected error"
      end
    end
  end
end

class EchoChannel < WebChannel
  def on_message(data, socket)
    fanout(data)
  end
end

class MyManifold < Manifold
  channel "echo", EchoChannel
end

sockethandler = HTTP::WebSocketHandler.new &MyManifold.handler

server = HTTP::Server.new([sockethandler])

server.bind_tcp "0.0.0.0", 8080
puts "Listening!"
server.listen
