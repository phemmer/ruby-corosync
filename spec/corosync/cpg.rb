require 'spec_helper'

require 'corosync/cpg'
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
			expect(@cpg.members).to include(@cpg.member)
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
			expect(@cpg.members).to include(@cpg.member)
		end
	end

	context '#with callbacks' do
		before(:all) do
			@cpg = Corosync::CPG.new
			@group_name = "RSPEC-#{Random.rand(2 ** 32)}"

			@confchgs = []
			@cpg.on_confchg do |member_list, left_list, join_list|
				@confchgs << {:member_list => member_list, :left_list => left_list, :join_list => join_list}
			end

			@messages = []
			@cpg.on_message do |sender, message|
				@messages << {:sender => sender, :message => message}
			end
		end

		it 'receives confchg on join' do
			@cpg.join(@group_name)

			@cpg.dispatch(1)

			expect(@confchgs.length).to eq(1)
			expect(@confchgs[0][:member_list]).to include(@cpg.member)
			expect(@confchgs[0][:join_list]).to include(@cpg.member)
			expect(@confchgs[0][:join_list].reason(@cpg.member)).to eq(:join)
		end

		it 'receives a message' do
			@cpg.send("a message")

			@cpg.dispatch(1)

			expect(@messages.length).to eq(1)
			expect(@messages[0][:sender]).to eq(@cpg.member)
			expect(@messages[0][:message]).to eq("a message")
		end
	end
end
