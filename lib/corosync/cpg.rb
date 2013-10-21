require File.expand_path('../../../ffi/cpg.rb', __FILE__)

# @example
#   cpg = Corosync::CPG.new('mygroup')
#   cpg.on_message do |message, membership|
#     puts "Received #{message}
#   end
#   puts "Member node IDs: #{cpg.members.map {|m| m.nodeid}.join(" ")}"
#   cpg.send "hello"
#   loop do
#     cpg.dispatch
#   end

class Corosync::CPG
	# The IO object containing the file descriptor events and messages come across.
	# You can use this to check for activity, but do not read anything from it.
	# @return [IO]
	attr_reader :fd

	# {Corosync::CPG::Membership Members} currently in the group.
	# @return [Array<Membership>]
	attr_reader :members

	# Creates a new CPG connection to the CPG service.  
	# You can spawn as many connections as you like in a single process, but each connection can only belong to a single group.  
	# If you get an *ERR_LIBRARY* error, corosync is likely not running.  
	# If you get an *EACCESS* error, you're likely not running as root.
	#
	# @param group [String] The name of the group to join. If not provided, you must call {#join} later.
	#
	# @return [void]
	def initialize(group = nil)
		# The model has to be preserved so it doesn't get garbage collected.
		# Apparently CPG needs to reference it long after initialization :-(
		#  (cpg.c:423)
		@model = Corosync::CpgModelV1DataT.new
		@model[:cpg_deliver_fn] = self.method(:callback_deliver)
		@model[:cpg_confchg_fn] = self.method(:callback_confchg)
		@model[:cpg_totem_confchg_fn] = self.method(:callback_totem_confchg)

		ObjectSpace.define_finalizer(self, self.method(:finalize))


		@group = nil
		@fd = nil
		@handle = nil
		@members = []

		join group if group
	end

	# Connect to the CPG service.
	# @return [void]
	def connect
		handle_ptr = FFI::MemoryPointer.new(Corosync.find_type(:cpg_handle_t))
		cs_error = Corosync.cpg_model_initialize(handle_ptr, Corosync::CPG_MODEL_V1, @model.pointer, nil);
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to connect to corosync"
		end
		@handle = handle_ptr.read_uint64

		fd_ptr = FFI::MemoryPointer.new(:int)
		cs_error = Corosync.cpg_fd_get(@handle, fd_ptr)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to get handle descriptor"
		end
		@fd = IO.new(fd_ptr.read_int)
	end

	# Shuts down the connection to the CPG service.
	# @return [void]
	def finalize
		return if @handle.nil?

		cs_error = Corosync.cpg_finalize(@handle)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to perform finalize"
		end

		@group = nil
		@fd = nil
		@model = nil
		@handle = nil
		@members = []

		true
	end
	alias_method :close, :finalize

	# Join the specified closed process group.
	# @param name [String] Name of the group. Maximum length of 128 characters.
	# @return [void]
	def join(name)
		connect if @handle.nil?

		cpg_name = Corosync::CpgName.new
		cpg_name[:value] = name
		cpg_name[:length] = name.size
		cs_error = Corosync.cpg_join(@handle, cpg_name)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to join group"
		end

		dispatch

		@group = name

		self
	end

	# Leave the current closed process group.
	# @return [void]
	def leave()
		return if !@group
		cpg_name = Corosync::CpgName.new
		cpg_name[:value] = @group
		cpg_name[:length] = @group.size

		# we can't join multiple groups, so I dont know why corosync requires you to specify the group name
		cs_error = Corosync.cpg_leave(@handle, cpg_name)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to leave group"
		end

		@group = nil
		@members = []
	end

	# Checks for a single pending events and triggers the appropriate callback if found.
	# @param timeout [Integer] How long to wait for an event.
	#   * +-1+: Indefinite. Wait forever
	#   * +0+: Non-blocking. If there isn't a pending event, return immediately
	#   * +>0+: Wait the specified number of seconds.
	# @return [Boolean] Returns +True+ if an event was triggered. Otherwise +False+.
	def dispatch(timeout = -1)
		if !timeout != 0 then
			timeout = nil if timeout == -1
			select([@fd], [], [], timeout)
		end
		cs_error = Corosync.cpg_dispatch(@handle, Corosync::CS_DISPATCH_ONE_NONBLOCKING)
		return false if cs_error == :err_try_again
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting perform dispatch"
		end
		return true
	end

	# Proc to call when a message is received.
	# @param block [Proc] Proc to call when a message is received. Pass +Nil+ to disable the callback.
	# @yieldparam message [String] Message content.
	# @yieldparam membership [Corosync::CPG::Membership] Membership describing where the message came from.
	# @return [void]
	def on_message(&block)
		@callback_deliver = block
	end
	def callback_deliver(handle, group_name_p, nodeid, pid, message_p, message_len)
		return if !@callback_deliver
		message = message_p.read_bytes(message_len)
		@callback_deliver.call(message, Corosync::CPG::Membership.new(:nodeid => nodeid, :pid => pid))
	end
	private :callback_deliver

	# Proc to call when a node joins/leaves the group.
	# If this is set before calling {#join}, it will be called when joining the group.
	# @param block [Proc] Proc to call when a node joins/leaves the group. Pass +Nil+ to disable the callback.
	# @yieldparam member_list [Array<Membership>] {Corosync::CPG::Membership Members} in the group after the change completed.
	# @yieldparam left_list [Array<Membership>] {Corosync::CPG::Membership Members} who left the group.
	# @yieldparam joined_list [Array<Membership>] {Corosync::CPG::Membership Members} who joined the group.
	# @return [void]
	def on_confchg(&block)
		@callback_confchg = block
	end
	def callback_confchg(handle, group_name_p, member_list_p, member_list_size, left_list_p, left_list_size, joined_list_p, joined_list_size)
		member_list = member_list_size.times.collect do |i|
			member = Corosync::CPG::Membership.new(member_list_p + i * Corosync::CpgAddress.size)
		end
		@members = member_list.dup
		return if !@callback_confchg

		left_list = left_list_size.times.collect do |i|
			Corosync::CPG::Membership.new(left_list_p + i * Corosync::CpgAddress.size)
		end
		joined_list = joined_list_size.times.collect do |i|
			Corosync::CPG::Membership.new(joined_list_p + i * Corosync::CpgAddress.size)
		end

		@callback_confchg.call(member_list, left_list, joined_list)
	end
	private :callback_confchg

	# Proc to call when a node joins/leaves the cluster.
	# If this is set before calling {#connect} or {#join}, it will be called when connecting to the cluster.
	# @param block [Proc] Proc to call when a node joins/leaves the cluster.
	# @yieldparam ring_id [Integer] Ring ID change occurred on.
	# @yieldparam member_list [Array<Integer>] Node ID of members in the cluster after the change completed.
	# @return [void]
	def on_totem_confchg(&block)
		@callback_totem_confchg = block
	end
	def callback_totem_confchg(handle, ring_id, member_list_size, member_list_p)
		return if !@callback_totem_confchg
		member_list = member_list_size.times.collect do |i|
			(member_list_p + i * Corosync.find_type(:uint32).size).read_uint32
		end
		@callback_totem_confchg.call(ring_id, member_list)
	end
	private :callback_totem_confchg

	# The node ID of ourself.
	# @!attribute nodeid [r]
	# @return [Integer]
	def nodeid
		nodeid_p = FFI::MemoryPointer.new(:uint)
		cs_error = Corosync.cpg_local_get(@handle, nodeid_p)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to get nodeid"
		end
		nodeid_p.read_uint
	end

	# Returns the {Corosync::CPG::Membership membership} object describing ourself.
	# @return [Corosync::CPG::Membership]
	def membership
		Corosync::CPG::Membership.new(:nodeid => self.nodeid, :pid => $$, :reason => 0)
	end

	# Send one or more messages to the group.
	# Sending multiple messages through a single call to {#send} ensures that the messages will be delivered consecutively without another message in the middle.
	# @param messages [Array<String>,String] The message(s) to send.
	# @return [void]
	def send(messages)
		messages = [messages] if !messages.is_a?(Array)
		
		iovec_list_p = FFI::MemoryPointer.new(Corosync::Iovec, messages.size)
		iovec_list = messages.size.times.collect do |i|
			iovec = Corosync::Iovec.new(iovec_list_p + i * Corosync::Iovec.size)
			iovec[:iov_base] = FFI::MemoryPointer.from_string(messages[i])
			iovec[:iov_len] = messages[i].size
		end
		iovec_len = messages.size

		cs_error = Corosync.cpg_mcast_joined(@handle, Corosync::CPG_TYPE_AGREED, iovec_list_p, iovec_len)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to send a message"
		end
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
