require "spec"
require "../src/rconcr"

def unused_local_port
  TCPServer.open("::", 0) do |server|
    server.local_address.port
  end
end
