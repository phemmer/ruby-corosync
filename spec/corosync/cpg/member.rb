require 'spec_helper'

describe Corosync::CPG::Member do
	before(:all) do
		@member1 = Corosync::CPG::Member.new(1001,20001)
		@member2 = Corosync::CPG::Member.new(1001,20002)
	end

	it 'checks equality' do
		member = Corosync::CPG::Member.new(1001,20001)

		expect(member).to eq(@member1)
		expect(member).not_to eq(@member2)
	end

	it 'hashes consistently' do
		member = Corosync::CPG::Member.new(1001,20001)
		
		expect(member.hash).to eq(@member1.hash)
	end

	it 'converts to string' do
		expect(@member1.to_s).to eq("1001:20001")
	end

	it 'has nodeid accessor' do
		expect(@member1.nodeid).to eq(1001)
	end

	it 'has pid accessor' do
		expect(@member1.pid).to eq(20001)
	end

	it 'can create from CpgAddress pointer' do
		cpgaddress = Corosync::CpgAddress.new
		cpgaddress[:nodeid] = 1001
		cpgaddress[:pid] = 20001
		member = Corosync::CPG::Member.new(cpgaddress.pointer)

		expect(member).to eq(@member1)
	end
end
