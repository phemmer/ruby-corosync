$:.unshift(File.expand_path('../../lib', __FILE__))
require 'corosync/cpg'
require 'json'

require 'zlib'
def makeid(nodeid,pid = nil)
  if nodeid.is_a?(Corosync::CPG::Member) then
    pid = nodeid.pid
    nodeid = nodeid.nodeid
  end
  Zlib::crc32("#{nodeid} #{pid}").to_s(36)
end

names = {}

cpg = Corosync::CPG.new
cpg.on_message do |message, nodeid, pid|
  id = makeid(nodeid, pid)
  message = JSON.parse(message)
  if message['type'] == 'name' then
    $stdout.puts "! #{names[id] || id} is now known as #{message['data']}" if names[id] != message['data']
    names[id] = message['data']
  elsif message['type'] == 'text' then
    name = names[id] || id
    $stdout.puts "#{name}: #{message['data']}"
  end
end

cpg.on_confchg do |member_list, left_list, join_list|
  if join_list.include?(cpg.member) then
    # we just joined the cluster
    other_list = member_list.to_a - [cpg.member]
    $stdout.puts "! we joined the cluster. Our name: #{makeid(cpg.member)}. Other members: #{other_list.map{|m| makeid(m)}.join(', ')}"
  elsif join_list.size > 0 then
    # someone else joined the cluster
    join_list.each do |m|
      id = makeid(m)
      $stdout.puts "! #{names[id] || id} joined the cluster"
      names.delete(m)
    end

    # send our name if we have one
    id = makeid(cpg.member)
    cpg.send({'type' => 'name', 'data' => names[id]}.to_json) if names[id]
  end
  left_list.each do |m|
    id = makeid(m)
    $stdout.puts "! #{names[id] || id} left the cluster"
    names.delete(m)
  end
end

cpg.join($0)

ios = [$stdin, cpg.fd]
inbuf = ''
while ios.size > 0 do
  ios_ready = IO.select(ios)
  if ios_ready[0].include?(cpg.fd) then
    cpg.dispatch
  end
  if ios_ready[0].include?($stdin) then
    inbuf << $stdin.read_nonblock(1024)
    while line = inbuf.slice!(/^(.*)#{$/}/) do
      if line.match(/^\/name (.+)/) then
        cpg.send({'type' => 'name', 'data' => $1}.to_json)
      elsif line.match(/^\/names/) then
        members = []
        cpg.members.each do |m|
          id = makeid(m)
          members << (names[id] || id)
        end
        $stdout.puts "! names: #{members.join(', ')}"
      else
        cpg.send({'type' => 'text', 'data' => line}.to_json)
      end
    end
  end
end
