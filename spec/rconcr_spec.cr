require "./spec_helper"
require "socket"

TEST_PASSWORD = "sesame"

private def run_test_server(host = "localhost", port = 0, handler = nil)
  server = TCPServer.new(host, port)

  begin
    spawn do
      socket = server.accept

      packet_size = socket.read_bytes(Int32, IO::ByteFormat::LittleEndian)
      request_id = socket.read_bytes(Int32, IO::ByteFormat::LittleEndian)
      cmd_type = socket.read_bytes(Int32, IO::ByteFormat::LittleEndian)
      payload = socket.gets("\0\0").not_nil!
      payload = payload.byte_slice(0, payload.bytesize - 2)

      if payload != TEST_PASSWORD
        request_id = -1
      end

      socket.write_bytes(10, IO::ByteFormat::LittleEndian)
      socket.write_bytes(request_id, IO::ByteFormat::LittleEndian)

      # The RCON protocol returns 2 (= Command::EXEC_COMMAND) on successful authentication
      socket.write_bytes(RCON::Command::EXEC_COMMAND, IO::ByteFormat::LittleEndian)
      socket.write_byte 0_u8
      socket.write_byte 0_u8

      if h = handler
        h.call(socket)
      end
    ensure
      socket.close if socket
    end

    yield server
  ensure
    server.close
  end
end

describe RCON do
  describe "test auth" do
    it "address, port, password" do
      run_test_server do |server|
        RCON::Client.open("localhost", server.local_address.port, TEST_PASSWORD) do |client|
        end
      end
    end

    it "URI" do
      run_test_server do |server|
        RCON::Client.open(URI.new("rcon", "localhost", server.local_address.port, password: TEST_PASSWORD)) do |client|
        end
      end
    end
  end

  it "closes" do
    packet = nil
    channel = Channel(Nil).new

    handler = ->(socket : IO) do
      io = RCON::Client.new(socket)
      packet = io.read
      channel.send nil
    end

    run_test_server(handler: handler) do |server|
      RCON::Client.open("localhost", server.local_address.port, TEST_PASSWORD) do |client|
        client.close
      end
    end

    channel.receive
    packet.should be_a(RCON::Packet)
    packet.as(RCON::Packet).payload.should eq "close".to_slice
  end

  it "test multipacket" do
    handler = ->(socket : IO) do
      # start packet
      # start response
      socket.write_bytes(10 + 4000, IO::ByteFormat::LittleEndian)
      socket.write_bytes(123, IO::ByteFormat::LittleEndian)
      socket.write_bytes(RCON::Command::RESPONSE, IO::ByteFormat::LittleEndian)
      socket.write((" " * 4000).to_slice)
      socket.write_bytes(0_u8, IO::ByteFormat::LittleEndian)
      socket.write_bytes(0_u8, IO::ByteFormat::LittleEndian)
      # end response
      # start response
      socket.write_bytes(10 + 4000, IO::ByteFormat::LittleEndian)
      socket.write_bytes(123, IO::ByteFormat::LittleEndian)
      socket.write_bytes(RCON::Command::RESPONSE, IO::ByteFormat::LittleEndian)
      socket.write((" " * 2000).to_slice)
      # end packet
      socket.flush

      # start packet
      socket.write((" " * 2000).to_slice)
      socket.write_bytes(0_u8, IO::ByteFormat::LittleEndian)
      socket.write_bytes(0_u8, IO::ByteFormat::LittleEndian)
      # end response
      # start response
      socket.write_bytes(10 + 2000, IO::ByteFormat::LittleEndian)
      socket.write_bytes(123, IO::ByteFormat::LittleEndian)
      socket.write_bytes(RCON::Command::RESPONSE, IO::ByteFormat::LittleEndian)
      socket.write((" " * 2000).to_slice)
      socket.write_bytes(0_u8, IO::ByteFormat::LittleEndian)
      socket.write_bytes(0_u8, IO::ByteFormat::LittleEndian)
      # end response
      # end packet
    end

    run_test_server(handler: handler) do |server|
      RCON::Client.open("localhost", server.local_address.port, TEST_PASSWORD) do |client|
        package = client.read
        package.not_nil!.payload.bytesize.should eq 4000

        package = client.read
        package.not_nil!.payload.bytesize.should eq 4000

        package = client.read
        package.not_nil!.payload.bytesize.should eq 2000

        package = client.read.should be_nil
      end
    end
  end

  it "#closed?" do
    RCON::Client.new(IO::Memory.new).closed?.should be_a(Bool)
  end
end
