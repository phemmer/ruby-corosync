module Corosync
	class CPG
	end
end

class Corosync::CPG::Member
	# @return [Integer] Node ID of the member
	attr_reader :nodeid

	# @return [Integer] Process ID of the member
	attr_reader :pid

	# @overload initialize(member)
	#   @param member [FFI::Pointer<Corosync::CpgAddress>, Corosync::CpgAddress]
	# @overload initialize(nodeid, pid)
	#   @param nodeid [Integer]
	#   @param pid [Integer]
	def initialize(*args)
		if args.size == 1 then
			member = args.first

			member = Corosync::CpgAddress.new(member) if member.is_a?(FFI::Pointer)
			if member.is_a?(Corosync::CpgAddress) then
				@nodeid = member[:nodeid]
				@pid = member[:pid]
			else
				raise ArgumentError, "Invalid argument type"
			end
		elsif args.size == 2 then
			@nodeid = args.shift.to_i
			@pid = args.shift.to_i
		else
			raise ArgumentError, "wrong number of arguments (#{args.size} for 1..2)"
		end
	end

	# @return [Boolean]
	def ==(target)
		self.class == target.class and @nodeid == target.nodeid and @pid == target.pid
	end
	alias_method :eql?, :==

	def hash
		[@nodid,@pid].hash
	end

	def to_s
		"#{@nodeid}:#{@pid}"
	end
end
