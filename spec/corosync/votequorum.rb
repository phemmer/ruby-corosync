require 'spec_helper'

require 'corosync/votequorum'
describe Corosync::Votequorum do
  context '#initialize offline' do
    before(:all) do
      @vq = Corosync::Votequorum.new
    end

    it 'creates a Votequorum object' do
      expect(@vq).to be_an_instance_of(Corosync::Votequorum)
      expect(@vq.fd).to be_nil
    end

    it 'connects' do
      have_callback = false
      @vq.on_notify do
        have_callback = true
      end

      @vq.start(true)

      expect(@vq.fd).to be_an_instance_of(IO)
      expect(have_callback).to be_true
    end
  end

  context '#initialize with connect' do
    before(:all) do
      @vq = Corosync::Votequorum.new(true)
    end

    it 'connects' do
      expect(@vq).to be_an_instance_of(Corosync::Votequorum)
      expect(@vq.fd).to_not be_nil
    end

    it 'gets quorum state' do
      expect([TrueClass,FalseClass]).to include(@vq.quorate?.class)
    end

    it 'responds to inquorate change' do
      is_quorate = nil
      @vq.on_notify {|quorate| is_quorate = quorate}

      handle = @vq.instance_variable_get(:@handle)
      node_states = {
        1 => Corosync::VOTEQUORUM_NODESTATE_DEAD,
      }
      node_list = FFI::MemoryPointer.new(Corosync::VotequorumNodeT, node_states.size)
      node_states.to_a.each_with_index do |node_state, i|
        node = Corosync::VotequorumNodeT.new(node_list + i * Corosync::VotequorumNodeT.size)
        node[:nodeid] = node_state[0]
        node[:state] = node_state[1]
      end
      @vq.send(:callback_notify, handle, nil, 0, node_states.size, node_list)

      expect(is_quorate).to eq(false)
    end

    it 'responds to quorate change' do
      is_quorate = nil
      @vq.on_notify {|quorate| is_quorate = quorate}

      handle = @vq.instance_variable_get(:@handle)
      node_states = {
        1 => Corosync::VOTEQUORUM_NODESTATE_MEMBER,
        2 => Corosync::VOTEQUORUM_NODESTATE_MEMBER,
      }
      node_list = FFI::MemoryPointer.new(Corosync::VotequorumNodeT, node_states.size)
      node_states.to_a.each_with_index do |node_state, i|
        node = Corosync::VotequorumNodeT.new(node_list + i * Corosync::VotequorumNodeT.size)
        node[:nodeid] = node_state[0]
        node[:state] = node_state[1]
      end
      @vq.send(:callback_notify, handle, nil, 1, node_states.size, node_list)

      expect(is_quorate).to eq(true)
    end
  end
end
