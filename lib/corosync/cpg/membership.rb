module Corosync
	class CPG
	end
end
class Corosync::CPG::Membership
	# @return [Integer] Node ID of the member
	attr_reader :nodeid

	# @return [Integer] Process ID of the member
	attr_reader :pid

	# @return [Symbol, Integer, NilClass] Reason for the membership update.
	#   When the membership object is provided as the result of a join/leave callback, this indicates why this membership entry changed.
	#   * :join => The member joined the group normally.
	#   * :leave => The member left the group normally.
	#   * :nodedown => The member left the group because the node left the cluster.
	#   * :nodeup => The member joined the group because it was already a member of a group on a node that just joined the cluster.
	#   * :procdown => The member left the group uncleanly (without calling {#leave})
	attr_reader :reason

	# There is no reason this should be created by anything other than the Corosync::CPG class.
	# @!visibility private
	def initialize(cpgaddress)
		cpgaddress = Corosync::CpgAddress.new(cpgaddress) if cpgaddress.is_a?(FFI::Pointer)
		@nodeid = cpgaddress[:nodeid]
		@pid = cpgaddress[:pid]
		@reason = cpgaddress[:reason] == 0 ? nil : Corosync.find_type(:cpg_reason_t).from_native(cpgaddress[:reason], nil)
	end

	# Indicates whether the target membership is exactly the same as this one.
	# @return [Boolean]
	def ==(target)
		self.class == target.class and @nodeid == target.nodeid and @pid == target.pid and @reason == target.reason
	end

	# Indicates whether the target membership has the same nodeid and pid
	# @return [Boolean]
	def ===(target)
		self.class == target.class and @nodeid == target.nodeid and @pid == target.pid
	end
end
