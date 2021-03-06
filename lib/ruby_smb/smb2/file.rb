module RubySMB
  module SMB2
    # Represents a file on the Remote server that we can perform
    # various I/O operations on.
    class File
      # The maximum number of byte we want to read or write
      # in a single packet.
      MAX_PACKET_SIZE = 32_768

      # The {FileAttributes} for the file
      # @!attribute [rw] attributes
      #   @return [RubySMB::Fscc::FileAttributes]
      attr_accessor :attributes

      # The {Smb2FileId} for the file
      # @!attribute [rw] guid
      #   @return [RubySMB::Field::Smb2FileId]
      attr_accessor :guid

      # The last access date/time for the file
      # @!attribute [rw] last_access
      #   @return [DateTime]
      attr_accessor :last_access

      # The last change date/time for the file
      # @!attribute [rw] last_change
      #   @return [DateTime]
      attr_accessor :last_change

      # The last write date/time for the file
      # @!attribute [rw] last_write
      #   @return [DateTime]
      attr_accessor :last_write

      # The name of the file
      # @!attribute [rw] name
      #   @return [String]
      attr_accessor :name

      # The actual size, in bytes, of the file
      # @!attribute [rw] size
      #   @return [Integer]
      attr_accessor :size

      # The size in bytes that the file occupies on disk
      # @!attribute [rw] size_on_disk
      #   @return [Integer]
      attr_accessor :size_on_disk

      # The {RubySMB::SMB2::Tree} that this file belong to
      # @!attribute [rw] tree
      #   @return [RubySMB::SMB2::Tree]
      attr_accessor :tree

      def initialize(tree:, response:, name:)
        raise ArgumentError, 'No Tree Provided' if tree.nil?
        raise ArgumentError, 'No Response Provided' if response.nil?

        @tree = tree
        @name = name

        @attributes   = response.file_attributes
        @guid         = response.file_id
        @last_access  = response.last_access.to_datetime
        @last_change  = response.last_change.to_datetime
        @last_write   = response.last_write.to_datetime
        @size         = response.end_of_file
        @size_on_disk = response.allocation_size
      end

      # Appends the supplied data to the end of the file.
      #
      # @param data [String] the data to write to the file
      # @return [WindowsError::ErrorCode] the NTStatus code returned from the operation
      def append(data:'')
        write(data: data, offset: size)
      end

      # Closes the handle to the remote file.
      #
      # @return [WindowsError::ErrorCode] the NTStatus code returned by the operation
      def close
        close_request = set_header_fields(RubySMB::SMB2::Packet::CloseRequest.new)
        raw_response  = tree.client.send_recv(close_request)
        response = RubySMB::SMB2::Packet::CloseResponse.read(raw_response)
        response.smb2_header.nt_status.to_nt_status
      end

      # Read from the file, a specific number of bytes
      # from a specific offset. If no parameters are given
      # it will read the entire file.
      #
      # @param bytes [Integer] the number of bytes to read
      # @param offset [Integer] the byte offset in the file to start reading from
      # @return [String] the data read from the file
      def read(bytes: size, offset: 0)
        atomic_read_size = if bytes > MAX_PACKET_SIZE
                             MAX_PACKET_SIZE
                           else
                             bytes
                           end

        read_request = read_packet(read_length: atomic_read_size, offset: offset)
        raw_response = tree.client.send_recv(read_request)
        response     = RubySMB::SMB2::Packet::ReadResponse.read(raw_response)

        data = response.buffer.to_binary_s

        remaining_bytes = bytes - atomic_read_size

        while remaining_bytes > 0
          offset += atomic_read_size
          atomic_read_size = remaining_bytes if remaining_bytes < MAX_PACKET_SIZE

          read_request = read_packet(read_length: atomic_read_size, offset: offset)
          raw_response = tree.client.send_recv(read_request)
          response     = RubySMB::SMB2::Packet::ReadResponse.read(raw_response)

          data << response.buffer.to_binary_s
          remaining_bytes -= atomic_read_size
        end
        data
      end

      # Crafts the ReadRequest packet to be sent for read operations.
      #
      # @param bytes [Integer] the number of bytes to read
      # @param offset [Integer] the byte offset in the file to start reading from
      # @return [RubySMB::SMB2::Packet::ReadRequest] the data read from the file
      def read_packet(read_length: 0, offset: 0)
        read_request = set_header_fields(RubySMB::SMB2::Packet::ReadRequest.new)
        read_request.read_length  = read_length
        read_request.offset       = offset
        read_request
      end

      # Sets the header fields that we have to set on every packet
      # we send for File operations.
      # @param request [RubySMB::GenericPacket] the request packet to set fields on
      # @return  [RubySMB::GenericPacket] the rmodified request packet
      def set_header_fields(request)
        request         = tree.set_header_fields(request)
        request.file_id = guid
        request
      end

      # Write the supplied data to the file at the given offset.
      #
      # @param data [String] the data to write to the file
      # @param offset [Integer] the offset in the file to start writing from
      # @return [WindowsError::ErrorCode] the NTStatus code returned from the operation
      def write(data:'', offset: 0)
        buffer            = data.dup
        bytes             = data.length
        atomic_write_size = if bytes > MAX_PACKET_SIZE
                             MAX_PACKET_SIZE
                           else
                             bytes
                            end

        while buffer.length > 0 do
          write_request = write_packet(data: buffer.slice!(0,atomic_write_size), offset: offset)
          raw_response  = tree.client.send_recv(write_request)
          response      = RubySMB::SMB2::Packet::WriteResponse.read(raw_response)
          status        = response.smb2_header.nt_status.to_nt_status

          offset+= atomic_write_size
          return status unless status == WindowsError::NTStatus::STATUS_SUCCESS
        end

        status
      end

      # Creates the Request packet for the #write command
      #
      # @param data [String] the data to write to the file
      # @param offset [Integer] the offset in the file to start writing from
      # @return []RubySMB::SMB2::Packet::WriteRequest] the request packet
      def write_packet(data:'', offset: 0)
        write_request               = set_header_fields(RubySMB::SMB2::Packet::WriteRequest.new)
        write_request.write_offset  = offset
        write_request.buffer        = data
        write_request
      end

    end
  end
end
