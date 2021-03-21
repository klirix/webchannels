require "http"
require "json"

module WebChannels
  struct Message
    include JSON::Serializable

    property event : String
    property channel : String
    property data : String
  end

  abstract class WebChannel
    @@sockets = {} of HTTP::WebSocket => self
    @@topic_sockets = {} of String => Set(self)
    property socket : HTTP::WebSocket
    property topics = [] of String
    @ctx : HTTP::Server::Context

    def self.join(socket, data, ctx) : Bool
      self.authenticate(socket, data, ctx)
      unless self.chan_by_socket(socket)
        @@sockets[socket] = new(socket, data, ctx)
        true
      else
        false
      end
    rescue e : Exception
      socket.send({event: "error", data: e.message || "unauthorized" }.to_json)
      false
    end

    def self.leave(socket : HTTP::WebSocket)
      channel = chan_by_socket!(socket)
      channel.on_leave()
      channel.topics.each do |topic|
        @@topic_sockets[topic].delete channel
      end
      @@sockets.delete(socket)
    end

    def self.pass_data(socket, data)
      chan_by_socket!(socket)
        .on_message(data)
    end

    def self.chan_by_socket(socket : HTTP::WebSocket)
      @@sockets[socket]?
    end

    def self.chan_by_socket!(socket)
      self.chan_by_socket(socket).not_nil!
    end

    def self.fanout(data : String | Bytes)
      @@sockets.each_value &.send(data)
      puts "Fanout #{data} to everyone"
    end

    def self.broadcast(topic, data)
      @@topic_sockets[topic].each &.send(data)
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
      authorize(data)
      on_join(data)
    end

    def send(data : String | Bytes)
      @socket.send(data)
    end

    def broadcast(topic, data)
      self.broadcast(topic, data)
    end

    # Override me
    def self.authenticate(socket, data, ctx)
    end

    # Override me
    def on_message(data : String)
    end

    # Override me
    def authorize(data)
    end

    # Override me
    def on_leave()
    end

    # Override me
    def on_join(data : String)
    end
  end

  class Manifold
    @@channels = {} of String => WebChannel.class

    macro channel(channel, channel_class)
      @@channels[{{channel}}] = {{channel_class}}
    end

    private def self.channel_by_name?(name : String)
      @@channels[name]?
    end

    def self.handler : HTTP::WebSocket, HTTP::Server::Context ->
      Proc(HTTP::WebSocket, HTTP::Server::Context, Void).new do |socket, ctx|
        socket.on_close do
          @@channels.each_value do |ch|
            ch.leave(socket)
          end
        end
        socket.on_message do |data|
          msg = Message.from_json data
          if channel = channel_by_name? msg.channel
            case msg.event
            when "join"
              unless channel.chan_by_socket socket
                if channel.join(socket, msg.data, ctx)
                  socket.send({event: "joined", channel: msg.channel}.to_json)
                end
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
