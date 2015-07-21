require 'smb2'

RSpec.describe Smb2::Packet::QueryDirectoryResponse do
  subject(:packet) do
    described_class.new(data)
  end

  context 'with packet bytes' do
    let(:data) do
      [
        "fe534d4240000100000000000e0001000100000000000000df00000000000000" \
        "0000000005000000110000000004000000000000000000000000000000000000" \
        "09004800dc0000007000000000000000e829bdabc298d001e829bdabc298d001" \
        "e829bdabc298d001e829bdabc298d00100000000000000000000000000000000" \
        "1000000002000000000000000000000000000000000000000000000000000000" \
        "00000000000000002847000000000c002e005200650063000000000000000000" \
        "e829bdabc298d001e829bdabc298d001e829bdabc298d001e829bdabc298d001" \
        "0000000000000000000000000000000010000000040000000000000000000000" \
        "0000000000000000000000000000000000000000000000000000000000000000" \
        "2e002e00"
      ].pack('H*')
    end

    it_behaves_like "packet"

    context 'body' do
      specify 'struct_size' do
        expect(packet.struct_size).to eq(9)
      end
      specify 'output_buffer_offset' do
        expect(packet.output_buffer_offset).to eq(0x48)
      end
      specify 'output_buffer_length' do
        expect(packet.output_buffer_length).to eq(220)
      end
      specify 'output_buffer' do
        expect(packet.output_buffer).to eq(
          [
            "7000000000000000e829bdabc298d001e829bdabc298d001e829bdabc298d001" \
            "e829bdabc298d001000000000000000000000000000000001000000002000000" \
            "0000000000000000000000000000000000000000000000000000000000000000" \
            "2847000000000c002e005200650063000000000000000000e829bdabc298d001" \
            "e829bdabc298d001e829bdabc298d001e829bdabc298d0010000000000000000" \
            "0000000000000000100000000400000000000000000000000000000000000000" \
            "0000000000000000000000000000000000000000000000002e002e00"
          ].pack("H*")
        )
      end
    end

  end

end
