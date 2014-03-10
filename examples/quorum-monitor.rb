$:.unshift(File.expand_path('../../lib', __FILE__))
require 'corosync/quorum'

quorum = Corosync::Quorum.new
quorum.on_notify do |quorate, member_list|
  puts "Cluster is#{quorate ? '' : ' not'} quorate"
  puts "  Members: #{member_list.join(' ')}"
end
quorum.connect(true)
loop do
  quorum.dispatch
end
