# This is public interface to communicate with a pubsub process
# All of innerworkings related to actually working with containers are encapsulated and are only executed in one fiber making this fiber an eventbus, making it effectively threadsafe
class PubSub(T)

  # :nodoc:
  record SubscriptionMessage(T), topic : String, channel : Channel(T)

  # :nodoc:
  record UnsubscriptionMessage(T), topic : String, channel : Channel(T)

  # :nodoc:
  record DataMessage(T), topic : String?, data : T


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

  # Subscribes a channel to a topic, adding it to the pool of channels
  def subscribe(topic : String?, channel : Channel(T))
    @channel.send(SubscriptionMessage.new(topic, channel))
  end

  # Subscribes a channel to the channel without assigning it a topic
  def subscribe(channel : Channel(T))
    @channel.send(SubscriptionMessage.new(nil, channel))
  end

  # Unsubscribes a channel to a topic
  def unsubscribe(topic : String?, channel : Channel(T))
    @channel.send(UnsubscriptionMessage.new(topic, channel))
  end

  # Removing a channel from the pool of channels
  def unsubscribe(channel : Channel(T))
    @channel.send(UnsubscriptionMessage.new(nil, channel))
  end

  # Publishes data to a topic
  def publish(topic : String, data : T)
    @channel.send(DataMessage.new(topic, data))
  end

  # Broadcasts data to all subscribers
  def broadcast(data : T)
    @channel.send(DataMessage.new(nil, data))
  end

  @clients = {} of Channel(T) => Set(String)
  @subscriptions = {} of String => Set(Channel(T))
  @channel = Channel(SubscriptionMessage(T) | UnsubscriptionMessage(T) | DataMessage(T)).new

  # :nodoc:
  private def subscribe_impl(topic : String?, channel : Channel(T))
    unless topic.nil?
      unless @subscriptions[topic]?
        @subscriptions[topic] = Set(Channel(T)).new
      end
      @subscriptions[topic] << channel
    end
    unless @clients[channel]?
      @clients[channel] = Set(String).new
    end
    @clients[channel] << topic unless topic.nil?
  end

  # :nodoc:
  private def unsubscribe_impl(topic : String?, channel : Channel(T))
    if set = @subscriptions[topic]?
      set.delete channel
      @clients[channel].delete topic
      if @clients[channel].size == 0
        @clients.delete channel
      end
    end
    @clients.delete channel if topic.nil?
  end

  # :nodoc:
  private def publish_impl(topic : String, data : T)
    if set = @subscriptions[topic]?
      set.each &.send(data)
    end
  end

  # :nodoc:
  private def broadcast_impl(data : T)
    @clients.each_key &.send(data)
  end
end
