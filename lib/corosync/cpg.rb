require File.expand_path('../../corosync.rb', __FILE__)
require File.expand_path('../../../ffi/cpg.rb', __FILE__)

require 'corosync/cpg/member_list'
require 'corosync/cpg/member'

# CPG is used for sending messages between processes (usually on multiple servers).
# The benefits offered by CPG over normal IPC is that message order is guaranteed.
# If you have 3 nodes, and both node 1 and node 2 send a message at the exact same time, all 3 nodes will receive the messages in the same order. One of the key details in this is that a node will also receive it's own message.
# You can also be notified whenever nodes join or leave the group. The order of these messages is preserved as well.
#
# This is all done through callbacks. You define a block of code to execute, and whenever a message is received, it is passed to that block.  
# After registering the callbacks, you call {#dispatch} to check for any pending messages, upon which the appropriate callbacks will be executed.
#
# The simplest usage of this library is to call `Corosync::CPG.new('groupname')`. This will connect to CPG and join the specified group.
#
# == Threading notice
# With MRI Ruby 1.9.3 and older, you cannot call {#dispatch} from within a thread. Attempting to do so will result in a segfault.  
# This is because the Corosync library allocates a very large buffer on the stack, and these versions of Ruby do not allocate enough memory to the thread stack.  
# With MRI Ruby 2.0.0 the behavior is a bit different. There is a workaround, but without it, calling {#dispatch} will result in the thread hanging. The workaround is that you you can pass the environment variable RUBY_THREAD_MACHINE_STACK_SIZE to increase the size of the thread stack. The recommended size is 1572864.
#
# ----
#
# @example
#   require 'corosync/cpg'
#   cpg = Corosync::CPG.new('mygroup')
#   cpg.on_message do |sender, message|
#     puts "Received #{message}"
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

	# Name of the currently joined group
	# @return [String]
	attr_reader :group

	# Creates a new CPG connection to the CPG service.  
	# You can spawn as many connections as you like in a single process, but each connection can only belong to a single group.  
	# If you get an *ERR_LIBRARY* error, corosync is likely not running.  
	# If you get an *EACCESS* error, you're likely not running as root (or havent set a `uidgid` directive in the config).
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

		@group = nil
		@fd = nil
		@handle = nil

		join group if group
	end

	# Connect to the CPG service.
	# @return [void]
	def connect
		handle_ptr = FFI::MemoryPointer.new(Corosync.find_type(:cpg_handle_t))
		model_cast = Corosync::CpgModelDataT.new(@model.to_ptr)
		Corosync.cs_send(:cpg_model_initialize, handle_ptr, Corosync::CPG_MODEL_V1, model_cast, nil)
		@handle = handle_ptr.read_uint64

		fd_ptr = FFI::MemoryPointer.new(:int)
		Corosync.cs_send(:cpg_fd_get, @handle, fd_ptr)
		@fd = IO.new(fd_ptr.read_int)
	end

	# Shuts down the connection to the CPG service.
	# @return [void]
	def finalize
		return if @handle.nil?

		Corosync.cs_send(:cpg_finalize, @handle)

		@group = nil
		@fd = nil
		@model = nil
		@handle = nil

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
		Corosync.cs_send(:cpg_join, @handle, cpg_name)

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
		Corosync.cs_send(:cpg_leave, @handle, cpg_name)

		@group = nil
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

		begin
			Corosync.cs_send!(:cpg_dispatch, @handle, Corosync::CS_DISPATCH_ONE_NONBLOCKING)
		rescue Corosync::TryAgainError => e
			raise e if e.depth > 1 # this exception is from a nested corosync function, not our cpg_dispatch we just called
			return false
		end

		return true
	end

	# Proc to call when a message is received.
	# @param block [Proc] Proc to call when a message is received. Pass +Nil+ to disable the callback.
	# @yieldparam member [Corosync::CPG::Member] Sender from which the message came
	# @yieldparam message [String] Message content.
	# @return [void]
	def on_message(&block)
		@callback_deliver = block
	end
	def callback_deliver(handle, group_name_p, nodeid, pid, message_p, message_len)
		return if !@callback_deliver
		message = message_p.read_bytes(message_len)
		@callback_deliver.call(Corosync::CPG::Member.new(nodeid, pid), message)
	end
	private :callback_deliver

	# Proc to call when a node joins/leaves the group.
	# If this is set before calling {#join}, it will be called when joining the group.
	# @param block [Proc] Proc to call when a node joins/leaves the group. Pass +Nil+ to disable the callback.
	# @yieldparam member_list [Corosync::CPG::MemberList] Members in the group after the change completed.
	# @yieldparam left_list [Corosync::CPG::MemberList] Members who left the group.
	# @yieldparam joined_list [Corosync::CPG::MemberList] Members who joined the group.
	# @return [void]
	def on_confchg(&block)
		@callback_confchg = block
	end
	def callback_confchg(handle, group_name_p, member_list_p, member_list_size, left_list_p, left_list_size, joined_list_p, joined_list_size)
		member_list = Corosync::CPG::MemberList.new
		member_list_size.times do |i|
			member_list << (member_list_p + i * Corosync::CpgAddress.size)
		end

		return if !@callback_confchg # no point in continuing otherwise

		left_list = Corosync::CPG::MemberList.new
		left_list_size.times do |i|
			left_list << (left_list_p + i * Corosync::CpgAddress.size)
		end

		joined_list = Corosync::CPG::MemberList.new
		joined_list_size.times do |i|
			joined_list << (joined_list_p + i * Corosync::CpgAddress.size)
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
		Corosync.cs_send(:cpg_local_get, @handle, nodeid_p)
		nodeid_p.read_uint
	end

	# Gets a list of members currently in the group
	# @return [Corosync::CPG::MemberList]
	def members
		members = Corosync::CPG::MemberList.new

		cpg_name = Corosync::CpgName.new
		cpg_name[:value] = @group
		cpg_name[:length] = @group.size

		iteration_handle_ptr = FFI::MemoryPointer.new(Corosync.find_type(:cpg_iteration_handle_t))
		Corosync.cs_send(:cpg_iteration_initialize, @handle, Corosync::CPG_ITERATION_ONE_GROUP, cpg_name, iteration_handle_ptr)
		iteration_handle = iteration_handle_ptr.read_uint64

		begin
			iteration_description = Corosync::CpgIterationDescriptionT.new
			begin
				loop do
					Corosync.cs_send(:cpg_iteration_next, iteration_handle, iteration_description)
					members << Corosync::CPG::Member.new(iteration_description)
				end
			rescue Corosync::NoSectionsError
				# signals end of iteration
			end
		ensure
			Corosync.cs_send(:cpg_iteration_finalize, iteration_handle)
		end

		members
	end

	# Returns the {Corosync::CPG::Member member} object describing ourself.
	# @return [Corosync::CPG::Member]
	def member
		Corosync::CPG::Member.new(self.nodeid, $$)
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
			message = messages[i].to_s
			iovec[:iov_base] = FFI::MemoryPointer.from_string(message)
			iovec[:iov_len] = message.size
			iovec
		end
		iovec_len = messages.size

		Corosync.cs_send(:cpg_mcast_joined, @handle, Corosync::CPG_TYPE_AGREED, iovec_list_p, iovec_len)

		true
	end
end
