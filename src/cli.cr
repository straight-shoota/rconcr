require "./rconcr"

address = ARGV.shift
host = ARGV.shift
password = ARGV.shift

RCON::Client.open(address, host, password) do |client|
  ARGV.each do |command|
    print "> "
    puts command
    response = client.command command
    if response
      RCON.colorize(STDOUT, response)
      puts
    else
      abort "Server closed connection"
    end
  end
end
