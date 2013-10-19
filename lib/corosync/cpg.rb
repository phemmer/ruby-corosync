require File.expand_path('../../../ext/cpg.rb', __FILE__)

class Corosync::CPG
	attr_reader :fd
	attr_reader :members

	def initialize(group = nil)
		model = Corosync::CpgModelV1DataT.new
		model[:cpg_deliver_fn] = self.method(:callback_deliver)
		model[:cpg_confchg_fn] = self.method(:callback_confchg)
		model[:cpg_totem_confchg_fn] = self.method(:callback_totem_confchg)

		handle_ptr = FFI::MemoryPointer.new(Corosync.find_type(:cpg_handle_t))
		cs_error = Corosync.cpg_model_initialize(handle_ptr, Corosync::CPG_MODEL_V1, model.pointer, nil);
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to connect to corosync"
		end
		@handle = handle_ptr.read_uint64

		ObjectSpace.define_finalizer(self, self.method(:finalize))

		fd_ptr = FFI::MemoryPointer.new(:int)
		cs_error = Corosync.cpg_fd_get(@handle, fd_ptr)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to get handle descriptor"
		end
		@fd = IO.new(fd_ptr.read_int)

		@members = []

		join group if group
	end
	def finalize
		Corosync.cpg_finalize(@handle)
	end
	def dispatch(timeout = -1)
		if !timeout != 0 then
			timeout = nil if timeout == -1
			select([@fd], [], [], timeout)
		end
		cs_error = Corosync.cpg_dispatch(@handle, Corosync::CS_DISPATCH_ONE_NONBLOCKING)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting perform dispatch"
		end
	end

	def on_message(&block)
		@callback_deliver = block
	end
	def callback_deliver(handle, group_name_p, nodeid, pid, message_p, message_len)
		return if !@callback_deliver
		message = message_p.read_bytes(message_len)
		@callback_deliver.call(message, nodeid, pid)
	end

	def on_confchg(&block)
		@callback_confchg = block
	end
	def callback_confchg(handle, group_name_p, member_list_p, member_list_size, left_list_p, left_list_size, joined_list_p, joined_list_size)
		return if !@callback_confchg
		member_list = member_list_size.times.collect do |i|
			member = Corosync::CpgAddress.new(member_list_p + i * Corosync::CpgAddress.size)
		end
		left_list = left_list_size.times.collect do |i|
			left = Corosync::CpgAddress.new(left_list_p + i * Corosync::CpgAddress.size)
		end
		joined_list = joined_list_size.times.collect do |i|
			joined = Corosync::CpgAddress.new(joined_list_p + i * Corosync::CpgAddress.size)
		end

		@members = member_list.dup

		@callback_confchg.call(member_list, left_list, joined_list)
	end

	def on_totem_confchg(&block)
		@callback_totem_confchg = block
	end
	def callback_totem_confchg(handle, ring_id, member_list_size, member_list_p)
		return if !@callback_totem_confchg
		member_list = member_list_size.times.collect do |i|
			(member_list_p + i * Corosync.find_type(:uint32).size).read_uint32
		end
		@callback_totem_confchg.call(member_list)
	end

	def join(group_name)
		cpg_name = Corosync::CpgName.new
		cpg_name[:value] = group_name
		cpg_name[:length] = group_name.size
		cs_error = Corosync.cpg_join(@handle, cpg_name)
		if cs_error != :ok then
			raise StandardError, "Received #{cs_error.to_s.upcase} attempting to join group"
		end

		@group = group_name

		self
	end
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
	end

	def send(messages)
		messages = [messages] if !messages.is_a?(Array)
		
		iovec_list_p = FFI::MemoryPointer.new(Corosync::Iovec, messages.size)
		iovec_list = messages.size.times.collect do |i|
			iovec = Corosync::Iovec.new(iovec_list_p + i * Corosync::Iovec.size)
			iovec[:iov_base] = FFI::MemoryPointer.from_string(messages[i])
			iovec[:iov_len] = messages[i].size
		end
		iovec_len = messages.size

		Corosync.cpg_mcast_joined(@handle, Corosync::CPG_TYPE_AGREED, iovec_list_p, iovec_len)
	end
end
