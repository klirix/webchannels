# webchannels

This is an experimental package, things can and _**will**_ change.

Basically soft-realtime channels powered by WebSockets for Crystal.

Heavily inspired by ActionCable and Phoenix Channels

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     webchannels:
       github: klirix/webchannels
   ```

2. Run `shards install`

## Usage

```crystal
require "webchannels"

class Echoes < WebChannels::WebChannel
  def on_data(context, data)
    Echoes.fanout(data)
  end
end

class MyManifold < WebChannels::Manifold
  channel "echo", Echoes
end
```

with `http`:
```crystal
require "http"

server = HTTP::Server.new([
  HTTP::WebsocketHandler.new &MyManifold.handler
])

server.listen 8080
```

with `kemal`:
```crystal
require "kemal"

ws "/echo", &MyManifold.handler

Kemal.run
```

## Development

A lot of things are to be completed.

TODO:

Passing data to WebChannels via structs not strings. Find a way for better communication.

Decouple connection and channel to simplify logic and naming.

Stabilize and standardize protocol and think of a better name for the library

add topic subscription data processing.

as in 

```ruby
subscribe "news" { |data| process(data) }
```

## Contributing

1. Fork it (<https://github.com/klirix/webchannels/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Askhat Saiapov](https://github.com/klirix) - creator and maintainer
