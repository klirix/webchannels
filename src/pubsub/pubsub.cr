module PubSub(Data)

  # abstract struct SubSubMessage
  #   @command : Command
  # end
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
