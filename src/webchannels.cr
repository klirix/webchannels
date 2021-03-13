require "http"
require "json"

struct Message
  include JSON::Serializable

  property command : String?
  property channel : String?
  property body : String?
end

class WebChannel
  property sockets = [] of HTTP::WebSocket

  def initialize(@topic : String)
  end

  def fanout(obj)
    @sockets.each do |socket|
      socket.send(obj.to_json)
    end
  end

  def matches?(topic : String | Nil)
    # TODO(klirix): Allow for more complex matching strategies, which should allow for wildcard channelss
    @topic == topic
  end

  def subscribe(socket : HTTP::WebSocket)
    self << socket
    print("subscribed to topic #{@topic}: ", socket)
  end

  def <<(socket : HTTP::WebSocket)
    @sockets << socket
  end
end

room1 = WebChannel.new "room1"
room2 = WebChannel.new "room2"

channels = [room1, room2]

sockethandler = HTTP::WebSocketHandler.new do |socket, ctx|
  socket.on_message do |data|
    message = Message.from_json data
    case message.command
    when "subscribe"
      if ch = channels.find {|ch| ch.matches? message.channel}
        ch.subscribe(socket)
        socket.send("ok")
      end
    else
      puts "Weird command lmao"
    end
  rescue ex : JSON::ParseException
    socket.send({error: "Filed to parse JSON"}.to_json)
    puts "error parsing message"
  rescue
    puts "unexpected error"
  end
end

server = HTTP::Server.new([sockethandler])

server.bind_tcp "0.0.0.0", 8080
puts "Listening!"
server.listen
