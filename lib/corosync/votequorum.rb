require File.expand_path('../../corosync.rb', __FILE__)
require File.expand_path('../../../ffi/votequorum.rb', __FILE__)

# Votequorum is used for tracking the health of the cluster.
# This monitors the quorum state as configured. Whenever the node gains or loses quorum, a notification callback is called. You can also poll the quorum state instead of using a callback.
#
# ----
#
# @example
#   require 'corosync/votequorum'
#   vq = Corosync::Votequorum.new
#   vq.on_notify do |quorate,node_list|
#     puts "Cluster is#{quorate ? '' ' not'} quorate"
#     puts "  Nodes:"
#     node_list.each do |name,state|
#       puts "    #{name}=#{state}"
#     end
#   end
#   vq.connect
#   loop do
#     vq.dispatch
#   end
class Corosync::Votequorum
	require 'ostruct'

	# The IO object containing the file descriptor notifications come across.
	# You can use this to check for activity, but do not read anything from it.
	# @return [IO]
	attr_reader :fd

	# Creates a new Votequorum instance
	#
	# @param connect [Boolean] Whether to join the cluster immediately. If not provided, you must call {#connect} and/or {#connect} later.
	#
	# @return [void]
	def initialize(connect = false)
		@handle = nil
		@fd = nil

		@callbacks = Corosync::VotequorumCallbacksT.new
		@callbacks[:votequorum_notify_fn] = self.method(:callback_notify)
		@callbacks[:votequorum_expectedvotes_notify_fn] = self.method(:callback_expectedvotes_notify)

		self.connect if connect
	end

	# Connect to the Votequorum service
	# @param start [Boolean] Whether to start listening for notifications (will not make initial call to callback).
	# @return [void]
	def connect(start = false)
		handle_ptr = FFI::MemoryPointer.new(Corosync.find_type(:votequorum_handle_t))

		Corosync.cs_send(:votequorum_initialize, handle_ptr, @callbacks)

		@handle = handle_ptr.read_uint64

		fd_ptr = FFI::MemoryPointer.new(:int)
		Corosync.cs_send(:votequorum_fd_get, @handle, fd_ptr)
		@fd = IO.new(fd_ptr.read_int)

		self.start if start
	end

	# Shuts down the connection to the Quorum service
	# @return [void]
	def finalize
		return if @handle.nil?

		Corosync.cs_send(:votequorum_finalize, @handle)

		@handle = nil
		@fd = nil
	end

	# Start monitoring for changes to quorum status/config.
	# This basically just enables triggering the callback. If not called you can still call {#quorate?} to get quorum state.
	# @param initial_callback [Boolean] Whether to call the callback after start.
	# @return [Boolean]
	def start(initial_callback = false)
		connect if @handle.nil?

		Corosync.cs_send(:votequorum_trackstart, @handle, 0, Corosync::CS_TRACK_CHANGES)

		if initial_callback and @callback_notify then
			@callback_notify.call(quorate?)
		end
	end

	# Stop monitoring for changes.
	# @return [void]
	def stop
		Corosync.cs_send(:votequorum_trackstop, @handle)
	end

	# Checks for a single pending event and triggers the appropriate callback if found.
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
			Corosync.cs_send(:votequorum_dispatch, @handle, Corosync::CS_DISPATCH_ONE_NONBLOCKING)
		rescue Corosync::TryAgainError
			return false
		end

		return true
	end

	# Proc to call when quorum state changes.
	# @param block [Proc] Proc to call when quorm state changes. Pass +Nil+ to disable the callback.
	# @yieldparam quorate [Boolean] Whether cluster is quorate.
	# @yieldparam nodes [Hash] Hash of node IDs and their state.
	#   The state is one of :member, :dead, or :leaving
	# @return [void]
	def on_notify(&block)
		@callback_notify = block
	end
	def callback_notify(handle, context, quorate, node_list_entries, node_list_ptr)
		return if !@callback_notify

		node_list = {}
		node_list_entries.times do |i|
			node = Corosync::VotequorumNodeT.new(node_list_ptr + i * Corosync::VotequorumNodeT.size)
			node_list[node[:nodeid]] = {
				Corosync::VOTEQUORUM_NODESTATE_MEMBER => :member,
				Corosync::VOTEQUORUM_NODESTATE_DEAD => :dead,
				Corosync::VOTEQUORUM_NODESTATE_LEAVING => :leaving,
			}[node[:state]]
			node_list[node[:nodeid]] = :UNKNOWN if node_list[node[:nodeid]].nil?
		end

		@callback_notify.call(quorate > 0, node_list)
	end
	private :callback_notify

	# Proc to call when the number of expected votes changes.
	# @param block [Proc] Proc to call when the expected votes changes. Pass +Nil+ to disable the callback.
	# @yieldparam expected_votes [Integer] New number of expected votes.
	# @return [void]
	def on_expectedvotes_notify(&block)
		@callback_expectedvotes_notify = block
	end
	def callback_expectedvotes_notify(handle, context, expected_votes)
		return if !@callback_expectedvotes_notify

		@callback_expectedvotes_notify.call(expected_votes)
	end
	private :callback_expectedvotes_notify

	# Get the votequorum info about a node.
	# The return openstruct will contain the following keys
	#   * node_id - Integer
	#   * node_state - Symbol: :member or :dead or :leaving
	#   * node_votes - Integer
	#   * node_expected_votes - Integer
	#   * highest_expected - Integer
	#   * total_votes - Integer
	#   * quorum - Integer
	#   * flags - Array<Symbol> where each symbol is one of: :twonode, :quorate, :wait_for_all, :last_man_standing, :auto_tie_breaker, :allow_downscale, :qdevice_registered, :qdevice_alive, :qdevice_cast_vote, or :qdevice_master_wins
	#   * qdevice_votes - Integer
	#   * qdevice_name - String
	# @param node_id [Integer] The node id to look up. 0 for the current node.
	# @return [OpenStruct]
	def info(node_id = 0)
		info = Corosync::VotequorumInfo.new

		Corosync.cs_send(:votequorum_getinfo, @handle, node_id, info)

		info = OpenStruct.new(Hash[info.members.zip(info.values)])

		info.qdevice_name = info.qdevice_name.to_s

		flags = info.flags
		info.flags = []
		[:twonode,:quorate,:wait_for_all,:last_man_standing,:auto_tie_breaker,:allow_downscale,:qdevice_registered,:qdevice_alive,:qdevice_cast_vote,:qdevice_master_wins].each do |flag_name|
			flag_value = Corosync.const_get("VOTEQUORUM_INFO_#{flag_name.to_s.upcase}")
			info.flags << flag_name if flags & flag_value >= 1
		end

		info
		#Corosync::Votequorum::Info.new info
	end

	# Set the number of expected votes for this node
	# @param count [Integer]
	# @return [void]
	def set_expected(count)
		Corosync.cs_send(:votequorum_setexpected, @handle, count)
	end
	alias_method :expected=, :set_expected

	# Set the number of votes contributed by the specified node.
	# @param count [Integer]
	# @param node_id [Integer] The node to modify
	# @return [void]
	def set_votes(count, node_id = 0)
		Corosync.cs_send(:votequorum_setvotes, @handle, node_id, count)
	end
	# Set the number of votes contributed by this node.
	# Shorthand for {#set_votes}(count)
	def votes=(count)
		set_votes(count)
	end

	# Get whether this node is quorate or not
	# Shorthand for {#info}.flags.include?(:quorate)
	# @return [Boolean]
	def quorate?
		self.info.flags.include?(:quorate)
	end
end
