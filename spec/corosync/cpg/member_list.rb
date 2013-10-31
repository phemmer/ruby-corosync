require 'spec_helper'

describe Corosync::CPG::MemberList do
	before(:all) do
		@list1 = Corosync::CPG::MemberList.new
		@list1 << Corosync::CPG::Member.new(1000,20000)
		@list1 << Corosync::CPG::Member.new(1001,20001)
		@list1 << Corosync::CPG::Member.new(1002,20002)
		@list1 << Corosync::CPG::Member.new(1003,20003)
		@list1 << Corosync::CPG::Member.new(1004,20004)
		@list2 = Corosync::CPG::MemberList.new
		@list2 << Corosync::CPG::Member.new(1000,20010)
		@list2 << Corosync::CPG::Member.new(1002,20002)
		@list2 << Corosync::CPG::Member.new(1005,20005)
	end

	it 'knows its size' do
		expect(@list1.size).to eq(5)
	end

	it 'ands the list' do
		list = @list1 & @list2

		expect(list.size).to eq(1)
		expect(list).to include(Corosync::CPG::Member.new(1002,20002))
	end

	it 'dups the list' do
		list = @list1.dup

		expect(list.first).to eq(@list1.first)
		expect(list.first.object_id).not_to eq(@list1.first.object_id)
	end

	it 'can check inclusion' do
		target = Corosync::CPG::Member.new(1001,20001)

		expect(@list1).to include(target)
		expect(@list2).not_to include(target)
	end

	it 'adds a member' do
		list = @list1.dup
		target = Corosync::CPG::Member.new(1006,20006)
		list << target

		expect(list.size).to eq(@list1.size + 1)
		expect(list).to include(target)
	end

	it 'deletes a member' do
		list = @list1.dup
		target = Corosync::CPG::Member.new(1001,20001)
		list.delete(target)

		expect(list.size).to eq(@list1.size - 1)
		expect(list).not_to include(target)
	end
end
