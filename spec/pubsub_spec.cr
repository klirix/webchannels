require "spec"
require "../src/pubsub"

class Publisher
  include PubSub(String)
end

describe PubSub do
  it "accepts subscribers" do

    pubsub = Publisher.new
    pubsub.run
    ch1 = Channel(String).new
    ch2 = Channel(String).new
    pubsub.subscribe "topic", ch1
    pubsub.subscribe "topic", ch2
    message = "MSG"
    spawn do
      [ch1, ch2].each do |ch|
        ch.receive.should eq message
      end
    end

    pubsub.publish "topic", message

    spawn do
      [ch1, ch2].each do |ch|
        ch.receive.should eq message
      end
    end

    pubsub.broadcast message
  end
end
