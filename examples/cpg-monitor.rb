$:.unshift(File.expand_path('../../lib', __FILE__))
require 'corosync/cpg'

cpg = Corosync::CPG.new
cpg.on_message do |message, sender|
	puts "MESSAGE: #{message.inspect}"
end
cpg.on_confchg do |member_list, left_list, joined_list|
	puts "CONFCHG:"
	puts "  MEMBER_LIST=#{member_list.inspect}"
	puts "  LEFT_LIST=#{left_list.inspect}"
	puts "  JOINED_LIST=#{joined_list.inspect}"
end
cpg.join('mygroup')
cpg.send('my message')
loop do
	puts "MEMBERS=#{cpg.members.inspect}"
	cpg.dispatch
	puts "LOOP"
end
