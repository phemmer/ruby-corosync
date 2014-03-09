$:.unshift(File.expand_path('../../lib', __FILE__))
require 'corosync/cmap'

def list
  cmap = Corosync::CMAP.new(true)

  cmap.keys.each do |key|
    type, value = cmap.get(key)
    puts "#{key} (#{type}) = #{value.inspect}"
  end
end
def get(key)
  cmap = Corosync::CMAP.new(true)

  type, value = cmap.get(key)
  puts "#{key} (#{type}) = #{value.inspect}"
end
def set(key, type, value)
  cmap = Corosync::CMAP.new(true)

  if type == 'float' or type == 'double' then
    value = value.to_f
  elsif type.match(/^u?int(8|16|32|64)$/) then
    value = value.to_i
  end

  cmap.set(key, type.to_sym, value)
end
def delete(key)
  cmap = Corosync::CMAP.new(true)

  cmap.delete(key)
end
def inc(key)
  cmap = Corosync::CMAP.new(true)

  cmap.inc(key)
end
def dec(key)
  cmap = Corosync::CMAP.new(true)

  cmap.dec(key)
end
def track(key)
  cmap = Corosync::CMAP.new(true)

  cmap.track_add(key, [:add, :delete, :modify]) do |action, key, value_type, value, value_old_type, value_old|
    puts "action=#{action.inspect} key=#{key.inspect} value_type=#{value_type.inspect} value=#{value.inspect} value_old_type=#{value_old_type.inspect} value_old=#{value_old.inspect}"
  end

  loop do
    cmap.dispatch
  end
end

args = ARGV.dup
action = args.shift
if action == 'list' then
  list(*args)
elsif action == 'get' then
  get(*args)
elsif action == 'set' then
  set(*args)
elsif action == 'delete' then
  delete(*args)
elsif action == 'inc' then
  inc(*args)
elsif action == 'dec' then
  dec(*args)
elsif action == 'track' then
  track(*args)
end
