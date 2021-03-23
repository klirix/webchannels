module PubSub(Data)

  # :nodoc:
  record SubscriptionMessage(Data), topic : String, channel : Channel(Data)

  # :nodoc:
  record UnsubscriptionMessage(Data), topic : String, channel : Channel(Data)

  # :nodoc:
  record DataMessage(Data), topic : String?, data : Data

end
