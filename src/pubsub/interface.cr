# This is public interface to communicate with a pubsub process
# All of innerworkings related to actually working with containers are encapsulated and are only executed in one fiber making this fiber an eventbus, making it effectively threadsafe
module PubSub(Data)

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
end
