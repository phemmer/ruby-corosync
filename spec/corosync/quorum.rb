require 'spec_helper'

require 'corosync/quorum'
describe Corosync::Quorum do
  context '#initialize offline' do
    before(:all) do
      @quorum = Corosync::Quorum.new
    end

    it 'creates a Quorum object' do
      expect(@quorum).to be_an_instance_of(Corosync::Quorum)
      expect(@quorum.fd).to be_nil
    end

    it 'connects' do
      have_callback = false
      @quorum.on_notify do
        have_callback = true
      end

      @quorum.start(true)

      expect(@quorum.fd).to be_an_instance_of(IO)
      expect(have_callback).to be_true
    end
  end

  context '#initialize with connect' do
    before(:all) do
      @quorum = Corosync::Quorum.new(true)
    end

    it 'connects' do
      expect(@quorum).to be_an_instance_of(Corosync::Quorum)
      expect(@quorum.fd).to_not be_nil
    end

    it 'gets quorum state' do
      expect([TrueClass,FalseClass]).to include(@quorum.quorate?.class)
    end
  end
end
