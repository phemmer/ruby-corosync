require File.expand_path('../member.rb', __FILE__)

module Corosync
	class CPG
	end
end
class Corosync::CPG::MemberList
	include Enumerable

	def self.new(*list)
		# return the input list if we were passed a MemberList
		return list[0] if list.size == 1 and list[0].is_a?(self)
		super
	end
	def initialize(*list)
		@list = {}

		list = list[0] if list.size <= 1

		if list.is_a?(Array) then
			list.each do |recipient|
				self << recipient
			end
		elsif list.is_a?(Corosync::CPG::Member) then
			self << list
		elsif list.nil? then
			# nothing
		else
			raise ArgumentError, "Invalid recipient type: #{list.class}"
		end
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

	# Get a list of all members also present in another list
	# @param list [Corosync::CPG::MemberList]
	# @return [Corosync::CPG::MemberList]
	def &(list)
		@list.keys & list.to_a
	end

	# Delete member from list
	# @param member [Corosync::CPG::Member] Member to delete
	# @return [void]
	def delete(member)
		@list.delete(member)
	end

	# Duplicate
	# @return [Corosync::CPG::MemberList]
	def dup
		new = self.class.new
		self.each do |member|
			new << member.dup
		end
		new
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
		Corosync.enum_type(:cpg_reason_t)[@list[member]]
	end

	# @return [Corosync::CPG::MemberList]
	def freeze
		@list.freeze
		self
	end
end
