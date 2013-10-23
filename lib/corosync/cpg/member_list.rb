require File.expand_path('../member.rb', __FILE__)

module Corosync
	class CPG
	end
end
class Corosync::CPG::MemberList
	include Enumerable

	def initialize()
		@list = {}
	end

	# Add a member to the list
	# @param member [FFI::Pointer<Corosync::CpgAddress>,Corosync::CPG::Member] Member to add
	def << (member)
		if member.is_a?(FFI::Pointer) then
			cpgaddress = Corosync::CpgAddress.new(member)
			@list[Corosync::CPG::Member.new(cpgaddress)] = cpgaddress[:reason]
		else
			@list[member] = nil
		end
	end

	# Number of members in list
	# @return [Integer]
	def size
		@list.size
	end

	# Iterate over all the {Corosync::CPG::Member member} objects in the list.
	# @param block [Proc]
	# @yieldparam member [Corosync::CPG::Member]
	def each(&block)
		@list.each_key &block
	end

	# In the case of join/leave lists, this gets the reason a member is in the list.
	# @param member [Corosync::CPG::Member] Member look up
	# @return [Symbol, Integer, NilClass] Reason for the membership.
	#   * :join => The member joined the group normally.
	#   * :leave => The member left the group normally.
	#   * :nodedown => The member left the group because the node left the cluster.
	#   * :nodeup => The member joined the group because it was already a member of a group on a node that just joined the cluster.
	#   * :procdown => The member left the group uncleanly (without calling {#leave})
	def reason(member)
		member = Corosync::CPG::Member.new if !member.is_a?(Corosync::CPG::Member)
		@list[member]
	end

	# @return [Corosync::CPG::MemberList]
	def freeze
		@list.freeze
		self
	end
end
