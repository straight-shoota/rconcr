# This class represents a RCON connection.
#
# ```
# RCON::Client.open(address, port, password) do |client|
#  client.command "say Hello from RCON =)"
# end
# ```
#
# # Use as a Server
#
# While this is primarily a client implementation it can also be used as for a
# server because both ends work in the same manner.
#
# ```cr
# def handle_connection(socket)do
#   rcon = RCON::Client.new(socket)
#   packet = rcon.read_
#   puts "Received packet #{packet}"
#   # Probably need some authentication logic here
#   socket.close
# end
#
# TCPServer.open(27015) do |server|
#   while socket = server.accept?
#     spawn handle_connection(socket)
#   end
# end
# ```
class RCON::Client
  # :nodoc:
  HEADER_SIZE = 10

  # Opens a new connection to the server at *address*:*port* and authenticates
  # with *password*.
  # Yields the client instance to the block and ensures the connection is
  # closed after returning.
  def self.open(address, port, password, & : self ->)
    TCPSocket.open(address, port) do |socket|
      client = new(socket)
      client.authenticate(password)
      begin
        yield client
      ensure
        client.close
      end
    end
  end

  # Opens a new connection to the server at *uri* and authenticates.
  #
  # URI format: `rcon://:password@host:port`
  #
  # Yields the client instance to the block and ensures the connection is
  # closed after returning.
  def self.open(uri : URI, & : self ->)
    open(uri.host, uri.port, uri.password) do |client|
      yield client
    end
  end

  # Creates a new client instance wrapping *socket*.
  #
  #
  # The *socket* should usually be a `TCPSocket`, but it can really be any
  # `IO`.
  #
  # Calling `.open` is recommended for most use cases. When using this
  # constructor, authentication needs to be handled explicitly (see
  # `#authenticate`).
  def initialize(@socket : IO, @sync_close = true)
    @buffer = IO::Memory.new
    @mutex = Mutex.new
    @request_id = 0
  end

  # Sends `close` command and closes the connection.
  def close
    @closed = true
    return if @socket.closed?

    begin
      send "close"
    rescue
      # Ignore errors because we're about to close anyways
    end

    @socket.close if @sync_close
  end

  # Returns `true` when this client has been closed.
  def closed? : Bool
    @closed || @socket.closed?
  end

  # Sends *command* and returns the server's response.
  def command(command : String) : String?
    request_id = send command

    packet = read_response
    return nil unless packet

    unless packet.request_id == request_id
      raise InvalidResponseError.new("invalid request id #{packet.request_id} returned")
    end

    String.new(packet.payload)
  end

  # Sends *command* and returns the request id.
  def send(command : String | Bytes, cmd_type : Command | Int32 = Command::EXEC_COMMAND) : Int32
    send Packet.new(Command.new(cmd_type), command)
  end

  # Sends *packet* and returns the request id.
  def send(packet : Packet)
    request_id = packet.request_id? || next_request_id
    package_length = HEADER_SIZE + packet.payload.bytesize

    @mutex.synchronize do
      @buffer.clear
      @buffer.write_bytes(package_length, IO::ByteFormat::LittleEndian)
      @buffer.write_bytes(request_id, IO::ByteFormat::LittleEndian)
      @buffer.write_bytes(packet.command_type, IO::ByteFormat::LittleEndian)

      @buffer.write packet.payload
      @buffer.write_byte 0_u8
      @buffer.write_byte 0_u8

      @socket.write @buffer.to_slice
    end

    request_id
  end

  private def next_request_id
    @mutex.synchronize do
      @request_id += 1
    end
  end

  # Reads a response from the server.
  #
  # Returns `nil` if the connection is closed.
  def read : Packet?
    @mutex.synchronize do
      read_response
    end
  end

  private def read_response
    return nil if closed?

    packet_size = begin
      @socket.read_bytes(Int32, IO::ByteFormat::LittleEndian)
    rescue exc : IO::EOFError
      return nil
    end

    unless HEADER_SIZE <= packet_size <= 4096
      raise FormatError.new("packet size #{packet_size}")
    end

    request_id = @socket.read_bytes(Int32, IO::ByteFormat::LittleEndian)
    response_type = @socket.read_bytes(Int32, IO::ByteFormat::LittleEndian)

    payload = Bytes.new(packet_size - HEADER_SIZE)
    bytes_read = @socket.read_fully(payload)

    raise FormatError.new if @socket.read_byte != 0_u8
    raise FormatError.new if @socket.read_byte != 0_u8

    Packet.new(Command.new(response_type), payload, request_id)
  end

  # Sends an auth command to authenticate with *password*.
  #
  # Return `true` if authenticated successfully and `false` otherwise.
  # Raises `AuthenticationError` if there was an error in the authentication
  # process.
  def authenticate(password) : Bool
    request_id = send password, Command::AUTH
    packet = read_response

    raise AuthenticationError.new unless packet

    unless packet.command_type.auth_response?
      # try again, some minecraft servers might send two responses
      packet = read_response
      raise AuthenticationError.new unless packet
    end

    unless packet.command_type.auth_response?
      raise AuthenticationError.new(cause: InvalidResponseError.new)
    end

    case packet.request_id
    when request_id then true
    when -1 then false
    else
      raise AuthenticationError.new("Unrecognized request_id #{packet.request_id}")
    end
  end
end
