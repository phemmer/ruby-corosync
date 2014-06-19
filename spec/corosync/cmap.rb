require 'spec_helper'
require 'timeout'

require 'corosync/cmap'
describe Corosync::CMAP do
	before(:all) do
		@cmap = Corosync::CMAP.new
		@cmap.connect
	end

	around :each do |example|
		Timeout::timeout(1) do
			example.run
		end
	end

	Corosync::CMAP::SIZEMAP.each do |type, info|
		it "can set a #{type}" do
			expect{@cmap.set("test.#{type}", type, info.max)}.to_not raise_error
		end
		it "can get a #{type}" do
			expect(@cmap.get("test.#{type}")).to eq([type, info.max])
		end
	end
	it 'can set a float' do
		expect{@cmap.set('test.float', :float, 1234.4321)}.to_not raise_error
	end
	it 'can get a float' do
		type, value = @cmap.get('test.float')
		expect(type).to eq(:float)
		expect(value).to be_within(0.00005).of(1234.4321)
	end
	it 'can set a double' do
		expect{@cmap.set('test.double', :double, 12345.54321)}.to_not raise_error
	end
	it 'can get a double' do
		type, value = @cmap.get('test.double')
		expect(type).to eq(:double)
		expect(value).to be_within(0.000005).of(12345.54321)
	end
	it 'cat set a string' do
		expect{@cmap.set("test.string", :string, 'xyzzy')}.to_not raise_error
	end
	it 'can get a string' do
		expect(@cmap.get("test.string")).to eq([:string, 'xyzzy'])
	end

	it 'can set an automatic type' do
		@cmap.set("test.auto", :int32, 1234)
		expect{@cmap.set_value("test.auto", 12345678)}.to_not raise_error
		expect(@cmap.get("test.auto")).to eq([:int32, 12345678])
	end

	it 'can get just the value' do
		@cmap.set("test.auto", :int32, 1234)
		expect(@cmap.get_value("test.auto")).to eq(1234)
	end

	it 'can increment a value' do
		@cmap.set('test.inc', :int32, 100)
		expect{@cmap.inc('test.inc')}.to_not raise_error
		expect(@cmap.get('test.inc')).to eq([:int32, 101])
	end

	it 'can decrement a value' do
		@cmap.set('test.dec', :int32, 100)
		expect{@cmap.dec('test.dec')}.to_not raise_error
		expect(@cmap.get('test.dec')).to eq([:int32, 99])
	end

	it 'can delete a value' do
		expect{@cmap.delete('test.string')}.to_not raise_error
		expect{@cmap.get('test.string')}.to raise_error
	end

	it 'can list keys' do
		keys = @cmap.keys

		expect(keys).to be_a(Array)
		keys.each do |key|
			expect(key).to be_a(String)
		end
	end

	it 'can track a value' do
		@cmap.delete('test.track') rescue Exception

		events = []
		track_id = @cmap.track_add('test.track', [:add, :delete, :modify]) do |*args|
			events << args
		end

		@cmap.set('test.track', :uint32, 1234)
		@cmap.dispatch
		@cmap.set('test.track', :int32, 1235)
		@cmap.dispatch
		@cmap.delete('test.track')
		@cmap.dispatch

		expect(events).to eq([
			[:add, 'test.track', :uint32, 1234, nil, nil],
			[:modify, 'test.track', :int32, 1235, :uint32, 1234],
			[:delete, 'test.track', nil, nil, :int32, 1235]
		])

		@cmap.track_delete(track_id)
		@cmap.set('test.track', :uint32, 1236)
		expect{@cmap.dispatch}.to raise_error # our timeout defined at the top should kick in
	end
end
