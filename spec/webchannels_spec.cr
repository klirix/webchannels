require "./spec_helper"

describe Webchannels do
  # TODO: Write tests

  describe Webchannels::Manifold do
    it "works" do
      Webchannels::Manifold.new do |fold|
        Webchannels::Exhaust.new fold, "topic"
      end
    end

    it "instantiates" do
      Webchannels::Manifold.new
    end
  end
end
