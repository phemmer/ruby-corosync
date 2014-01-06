require File.expand_path('../../corosync.rb', __FILE__)
require File.expand_path('../../../ffi/quorum.rb', __FILE__)

# Quorum is used for tracking the health of the cluster.
# This simply reads the quorum state as defined by corosync. Whenever the node gains or loses quorum, a notification callback is called. You can also poll the quorum state instead of using a callback.
#
# ----
#
# @example
#   require 'corosync/quorum'
#   quorum = Corosync::Quorum.new
#   quorum.on_notify do |quorate,member_list|
#     puts "Cluster is#{quorate ? '' ' not'} quorate"
#     puts "  Members: #{member_list.join(' ')}"
#   end
#   loop do
#     quorum.dispatch
#   end

class Corosync::Quorum
	# The IO object containing the file descriptor notifications come across.
	# You can use this to check for activity, but do not read anything from it.
	# @return [IO]
	attr_reader :fd

	# Creates a new Quorum instance
	#
	# @param connect [Boolean] Whether to join the cluster immediately. If not provided, you must call {#connect} and/or {#connect} later.
	#
	# @return [void]
	def initialize(connect = false)
		@handle = nil
		@fd = nil

		@callbacks = Corosync::QuorumCallbacksT.new
		@callbacks[:quorum_notify_fn] = self.method(:callback_notify)

		self.connect if connect
	end

	# Connect to the Quorum service
	# @param start [Boolean] Whether to start listening for notifications (will not make initial call to callback).
	# @return [void]
	def connect(start = false)
		handle_ptr = FFI::MemoryPointer.new(Corosync.find_type(:quorum_handle_t))
		quorum_type_ptr = FFI::MemoryPointer.new(:uint32)

		cs_error = Corosync.quorum_initialize(handle_ptr, @callbacks.pointer, quorum_type_ptr)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to connect to corosync"
		end

		@handle = handle_ptr.read_uint64

		fd_ptr = FFI::MemoryPointer.new(:int)
		cs_error = Corosync.quorum_fd_get(@handle, fd_ptr)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to get handle descriptor"
		end
		@fd = IO.new(fd_ptr.read_int)

		self.start(initial_callback) if start
	end

	# Shuts down the connection to the Quorum service
	# @return [void]
	def finalize
		return if @handle.nil?

		cs_error = Corosync.quorum_finalize(@handle)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to perform finalize"
		end

		@handle = nil
		@fd = nil
	end

	# Start monitoring for changes to quorum status.
	# This basically just enables triggering the callback. If not called you can still call {#quorate?} to get quorum state.
	# @param initial_callback [Boolean] Whether to call the callback after start.
	# @return [Boolean]
	def start(initial_callback = false)
		connect if @handle.nil?

		cs_error = Corosync.quorum_trackstart(@handle, Corosync::CS_TRACK_CHANGES)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to start tracking quorum"
		end

		if initial_callback and @callback_notify then
			@callback_notify.call(quorate?)
		end
	end

	# Stop monitoring for changes to quorum status.
	# @return [void]
	def stop
		cs_error = Corosync.quorum_trackstop(@handle)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to stop tracking quorum"
		end
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

		cs_error = Corosync.quorum_dispatch(@handle, Corosync::CS_DISPATCH_ONE_NONBLOCKING)
		return false if cs_error == :err_try_again
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to perform dispatch"
		end
		return true
	end

	# Proc to call when quorum state changes.
	# @param block [Proc] Proc to call when quorm state changes. Pass +Nil+ to disable the callback.
	# @yieldparam message [Boolean] Whether cluster is quorate.
	# @yieldparam members [Array<Fixnum>] Node ID of cluster members.
	# @return [void]
	def on_notify(&block)
		@callback_notify = block
	end
	def callback_notify(handle, quorate, ring_id, view_list_entries, view_list_ptr)
		return if !@callback_notify

		view_list = []
		view_list_entries.times do |i|
			view_list << FFI::MemoryPointer.new(view_list_ptr + i * FFI.type_size(:uint32))
		end

		@callback_notify.call(quorate > 0, view_list)
	end
	private :callback_notify

	# Get node quorum status
	# @return [Boolean] Whether node is quorate.
	def getquorate
		quorate_ptr = FFI::MemoryPointer.new(:int)
		cs_error = Corosync.quorum_getquorate(@handle, quorate_ptr)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to get quorate"
		end

		quorate_ptr.read_int > 0
	end
	alias_method :quorate?, :getquorate
end
