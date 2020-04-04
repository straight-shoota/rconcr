# rconcr

Client for the RCON (Remote CONsole) protocol implemented in Crystal.

This Protocol is used to access a remote console on game servers. The implementation
has been tested with Minecraft server, but should work with Source-compatible RCON
servers as well.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     rconcr:
       github: straight-shoota/rconcr
   ```

2. Run `shards install`

## Usage

```crystal
require "rconcr"

RCON::Client.open(address, host, password) do |client|
  response = client.command "say Hello World from RCON!"
  if response
    RCON.colorize(STDOUT, response)
    puts
  else
    abort "Server closed connection"
  end
end
```

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/your-github-user/rconcr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Johannes Müller](https://github.com/your-github-user) - creator and maintainer
