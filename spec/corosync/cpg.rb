require 'spec_helper'

describe Corosync::CPG do
	context '#initialize offline' do
		before(:all) do
			@cpg = Corosync::CPG.new
		end

		it 'creates a CPG object' do
			expect(@cpg).to be_an_instance_of(Corosync::CPG)
			expect(@cpg.fd).to be_nil
		end

		it 'connects' do
			@cpg.connect

			expect(@cpg.fd).to be_an_instance_of(IO)
		end

		it 'joins a group' do
			group_name = "RSPEC-#{Random.rand(2 ** 32)}"
			@cpg.join(group_name)

			expect(@cpg.group).to eq(group_name)
		end

		it 'has ourself as a member' do
			membership = @cpg.membership
			expect(@cpg.members.find_all{|m| m === membership}).to have(1).items
		end
	end

	context '#initialize with join' do
		before(:all) do
			@group_name = "RSPEC-#{Random.rand(2 ** 32)}"
			@cpg = Corosync::CPG.new(@group_name)
		end
		it 'creates a CPG object and joins a group' do
			expect(@cpg).to be_an_instance_of(Corosync::CPG)
			expect(@cpg.fd).to be_an_instance_of(IO)
			expect(@cpg.group).to eq(@group_name)
		end

		it 'has ourself as a member' do
			membership = @cpg.membership
			expect(@cpg.members.find_all{|m| m === membership}).to have(1).items
		end
	end
end
