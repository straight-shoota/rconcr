require "socket"
require "./client"

# RCON (Remote CONsole) protocol implemented in Crystal.
#
# This Protocol is used to access a remote console on game servers. The implementation
# has been tested with Minecraft server, but should work with Source-compatible RCON
# servers as well.
#
# See `Client` for usage instructions.
module RCON
  # Represents a command code.
  enum Command
    AUTH         = 3
    EXEC_COMMAND = 2
    RESPONSE     = 0

    def to_io(io : IO, format : IO::ByteFormat)
      value.to_io(io, format)
    end

    def auth_response?
      # The RCON protocol returns 2 (`Command::EXEC_COMMAND`) on successful authentication
      exec_command?
    end
  end

  # This exception is raised when there's an error in the message format.
  class FormatError < Exception
  end

  # This exception is raised when the response is invalid (for example mismatching
  # request id).
  class InvalidResponseError < Exception
  end

  # This exception is raised when authentication failed.
  class AuthenticationError < Exception
  end

  # `Packet` represents a message sent over the RCON protocol.
  struct Packet
    getter command_type : Command
    getter! request_id : Int32?
    getter payload : Bytes

    def self.new(command_type : Command, command : String)
      new(command_type, command.to_slice, nil)
    end

    def initialize(@command_type : Command, @payload : Bytes, @request_id : Int32? = nil)
    end
  end

  COLORS = [
    "\033[0;30m",   # 00 BLACK     0x30
    "\033[0;34m",   # 01 BLUE      0x31
    "\033[0;32m",   # 02 GREEN     0x32
    "\033[0;36m",   # 03 CYAN      0x33
    "\033[0;31m",   # 04 RED       0x34
    "\033[0;35m",   # 05 PURPLE    0x35
    "\033[0;33m",   # 06 GOLD      0x36
    "\033[0;37m",   # 07 GREY      0x37
    "\033[0;1;30m", # 08 DGREY     0x38
    "\033[0;1;34m", # 09 LBLUE     0x39
    "\033[0;1;32m", # 10 LGREEN    0x61
    "\033[0:1;36m", # 11 LCYAN     0x62
    "\033[0;1;31m", # 12 LRED      0x63
    "\033[0;1;35m", # 13 LPURPLE   0x64
    "\033[0;1;33m", # 14 YELLOW    0x65
    "\033[0;1;37m", # 15 WHITE     0x66
    "\033[4m",      # 16 UNDERLINE 0x6e
  ]

  # Translate Minecraft color codes to ANSI color codes.
  def self.colorize(io, string : String)
    i = 0
    while i < string.bytesize
      byte = string.to_slice[i]
      if byte == 0x0a
        io << color(0)
      elsif byte == 0xc2 && string.to_slice[i + 1] == 0xa7
        io << color(string.to_slice[i + 2])
        i += 2
      else
        io.write_byte byte
      end
      i += 1
    end
    io << color(0)
  end

  private def self.color(color)
    if (color == 0 || color == 0x72)
      "\033[0m" # CANCEL COLOR
    else
      if (color >= 0x61 && color <= 0x66)
        color -= 0x57
      elsif (color >= 0x30 && color <= 0x39)
        color -= 0x30
      elsif (color == 0x6e)
        color = 16
        # 0x6e: 'n'
      else
        return
      end

      COLORS[color]
    end
  end
end
