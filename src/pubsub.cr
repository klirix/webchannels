# This is public interface to communicate with a pubsub process
# All of innerworkings related to actually working with containers are encapsulated and are only executed in one fiber making this fiber an eventbus, making it effectively threadsafe
module PubSub(Data)

  # :nodoc:
  record SubscriptionMessage(Data), topic : String, channel : Channel(Data)

  # :nodoc:
  record UnsubscriptionMessage(Data), topic : String, channel : Channel(Data)

  # :nodoc:
  record DataMessage(Data), topic : String?, data : Data


  # :nodoc:
  class InvalidCommandException < Exception
  end

  # Starts up an eventbus, none of the messages sent before that will be handled
  def run
    spawn do
      while msg = @channel.receive
        case msg
        when SubscriptionMessage
          subscribe_impl(msg.topic, msg.channel)
        when UnsubscriptionMessage
          unsubscribe_impl(msg.topic, msg.channel)
        when DataMessage
          if topic = msg.topic
            publish_impl(topic, msg.data)
          else
            broadcast_impl(msg.data)
          end
        else
          raise InvalidCommandException.new
        end
      end
    end
  end

  # Subscribes a channel to a topic
  def subscribe(topic : String, channel : Channel(Data))
    @channel.send(SubscriptionMessage.new(topic, channel))
  end

  # Unsubsribes a channel to a topic
  def unsubscribe(topic : String, channel : Channel(Data))
    @channel.send(UnsubscriptionMessage.new(topic, channel))
  end

  # Publishes data to a topic
  def publish(topic : String, data : Data)
    @channel.send(DataMessage.new(topic, data))
  end

  # Broadcasts data to all subscribers
  def broadcast(data : Data)
    @channel.send(DataMessage.new(nil, data))
  end

  @clients = {} of Channel(Data) => Set(String)
  @subscriptions = {} of String => Set(Channel(Data))
  @channel = Channel(SubscriptionMessage(Data) | UnsubscriptionMessage(Data) | DataMessage(Data)).new

  # :nodoc:
  def subscribe_impl(topic : String, channel : Channel(Data))
    unless @subscriptions[topic]?
      @subscriptions[topic] = Set(Channel(Data)).new
    end
    @subscriptions[topic] << channel
    unless @clients[channel]?
      @clients[channel] = Set(String).new
    end
    @clients[channel] << topic
  end

  # :nodoc:
  def unsubscribe_impl(topic : String, channel : Channel(Data))
    if set = @subscriptions[topic]?
      set.delete channel
      @clients[channel].delete topic
      if @clients[channel].size == 0
        @clients.delete channel
      end
    end
  end

  # :nodoc:
  def publish_impl(topic : String, data : Data)
    if set = @subscriptions[topic]?
      set.each &.send(data)
    end
  end

  # :nodoc:
  def broadcast_impl(data : Data)
    @clients.each_key &.send(data)
  end
end
