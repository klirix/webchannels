require "http"
require "json"
require "colorize"

module WebChannels
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
    @ctx : HTTP::Server::Context

    def self.leave(socket : HTTP::WebSocket)
      channel = chan_by_socket!(socket)
      channel.on_leave(socket)
      channel.topics.each do |topic|
        @@topic_sockets[topic].delete channel
      end
      @@sockets.delete channel
    end

    def self.pass_data(socket, data)
      channel = chan_by_socket!(socket)
      channel.on_message(socket, data)
    end

    def self.chan_by_socket(socket : HTTP::WebSocket)
      @@sockets.find {|x| x.socket == socket}
    end

    def self.chan_by_socket!(socket)
      self.chan_by_socket(socket).not_nil!
    end

    def self.fanout(data : String | Bytes)
      @@sockets.each &.send(data)
      puts "Fanout #{data} to everyone"
    end

    def self.broadcast(topic, data)
      @@topic_sockets[topic].each &.send(data)
    end

    def broadcast(topic, data)
      @@topic_sockets[topic].each &.send(data)
    end

    # Override me
    def on_message(data : String, socket : HTTP::WebSocket)
    end

    # Override me
    def on_leave(socket : HTTP::WebSocket)
    end

    # Override me
    def on_join(socket : HTTP::WebSocket, data : String)
    end

    def subscribe(topic : String)
      topics << topic
      @@topic_sockets[topic] << self
      puts "Socket #{@socket.object_id} subscribed to #{topic}"
    end

    def unsubscribe(topic : String)
      topics.delete topic
      @@topic_sockets[topic].delete self
      puts "Socket #{@socket.object_id} unsubscribed from #{topic}"
    end

    def initialize(@socket, data : String, @ctx)
      @@sockets << self
      on_join(@socket, data)
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

    private def self.channel_by_name?(name : String)
      if pair = @@channels.find {|x| x[0] == name}
        pair[1]
      end
    end

    def self.handler : HTTP::WebSocket, HTTP::Server::Context ->
      Proc(HTTP::WebSocket, HTTP::Server::Context, Void).new do |socket, ctx|
        socket.on_message do |data|
          msg = Message.from_json data
          if channel = channel_by_name? msg.channel
            case msg.event
            when "join"
              unless channel.chan_by_socket socket
                channel.new(socket, msg.data, ctx)
                socket.send({event: "joined", channel: msg.channel}.to_json)
              else
                socket.send({event: "error", channel: msg.channel, data: "Already joined"}.to_json)
              end
            when "leave"
              if channel.chan_by_socket socket
                channel.leave(socket)
                socket.send({event: "left", channel: msg.channel}.to_json)
              else
                socket.send({event: "error", channel: msg.channel, data: "Can't leave channel"}.to_json)
              end
            when "data"
              channel.pass_data(socket, msg.data)
            else
              puts "Weird command lmao"
            end
          else
            socket.send({event: "error", channel: msg.channel, data: "Channel doesn't exist"}.to_json)
          end
        rescue ex : JSON::ParseException
          socket.send({error: "Failed to parse JSON"}.to_json)
          puts "error parsing message"
        # rescue
        #   puts "unexpected error"
        end
      end
    end
  end
end
