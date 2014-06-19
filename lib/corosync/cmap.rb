require File.expand_path('../../corosync.rb', __FILE__)
require File.expand_path('../../../ffi/cmap.rb', __FILE__)

# CMAP is used to access the corosync configuration database for the local node.
# You can list keys, get/set/delete values, and watch for changes.
#
# Many of the methods take or return a 'type'. The type is a symbol for one of CMAP's supported types. The symbols are:
# * :int8
# * :uint8
# * :int16
# * :uint16
# * :int32
# * :uint32
# * :int64
# * :uint64
# * :float
# * :double
# * :string
#
# ----
#
# @example
#   require 'corosync/cmap'
#   cmap = Corosync::CMAP.new(true)
#   cmap.set('mykey.foo', :int32, -1234)
#   puts "mykey.foo is #{cmap.get('mykey.foo')}"

class Corosync::CMAP
	# The IO object containing the file descriptor events and messages come across.
	# You can use this to check for activity prior to calling {#dispatch}, but do not read anything from it.
	# @return [IO]
	attr_reader :fd

	# Starts a new instance of CMAP.
	# You can have as many instances as you like, but no real reason for more than one.
	#
	# @param connect [Boolean] Whether to automatically call {#connect}
	def initialize(connect = true)
		@handle = nil

		@track_handle_callbacks = {}

		self.connect if connect
	end

	# Connect to the CMAP service.
	#
	# @return [void]
	def connect
		handle_ptr = FFI::MemoryPointer.new(Corosync.find_type(:cmap_handle_t))

		Corosync.cs_send(:cmap_initialize, handle_ptr)

		@handle = handle_ptr.read_uint64

		fd_ptr = FFI::MemoryPointer.new(:int)
		Corosync.cs_send(:cmap_fd_get, @handle, fd_ptr)
		@fd = IO.new(fd_ptr.read_int)
	end

	# Disconnect from the CMAP service.
	#
	# @return [void]
	def finalize
		return if @handle.nil?

		Corosync.cs_send(:cmap_finalize, @handle)

		@handle = nil
		@fd = nil
	end

	# Retrieve a key by the specified name.
	# Will raise {Corosync::NotExistError} if the key does not exist.
	#
	# @return [Array<type, value>] The type and value of the key
	def get(name)
		#TODO? make it just return nil if the key doesn't exist
		size_ptr = FFI::MemoryPointer.new(:size_t)
		type_ptr = FFI::MemoryPointer.new(Corosync.find_type(:cmap_value_types_t))

		size = 256

		begin
			size_ptr.write_type(:size_t, size)
			value_ptr = FFI::MemoryPointer.new(size)

			Corosync.cs_send(:cmap_get, @handle, name, value_ptr, size_ptr, type_ptr)
		rescue Corosync::InvalidParamError => e
			# err_invalid_param is supposed to indicate our buffer was too small
			value_ptr.free
			size << 1
			retry if size < 1024 ** 2 # 1 MB

			raise e
		end

		type = type_ptr.read_type(Corosync.find_type(:cmap_value_types_t))
		type = Corosync.enum_type(:cmap_value_types_t)[type]
		if type == :binary then
			raise RuntimeError, "Binary, not sure how to handle this. Corosync docs don't clearly indicate what it is"
		end

		[type, value_ptr.send("read_#{type}".downcase.to_sym)]
	end

	# Retrieve a key's value.
	# This is just a conveinence wrapper around {#get} to only get the value if you don't want the type.
	#
	# @param name [String] The name of the key to look up
	#
	# @return [Number, String] The value of the key
	def get_value(name)
		type, value = get(name)
		value
	end

	# Set a key to the specified type & value.
	# This will create the key if it doesn't exist, and will otherwise modify it, including changing the type if it doesn't match.
	#
	# @param name [String] The name of the key
	# @param type [Symbol] One of CMAP's supported types
	# @param value [Number,String] The value to set
	#
	# @return [Number,String] The value as stored in the CMAP service. This will normally be the value passed in, but if you store a non-string as a string, the return will be the result of to_s
	def set(name, type, value)
		# get byte size
		if type == :string then
			size = value.bytesize
		elsif SIZEMAP.keys.include?(type) then
			size = SIZEMAP[type].bytes
		elsif type == :float then
			size = 4
		elsif type == :double then
			size = 8
		elsif type == :binary then
			size = value.bytesize
		end

		value_ptr = FFI::MemoryPointer.new(size)
		value_ptr.write_type(type, value)
		Corosync.cs_send(:cmap_set, @handle, name, value_ptr, size, type)

		value
	end

	# @!visibility private
	NumType = Struct.new(:min, :max, :bytes)
	# @!visibility private
	SIZEMAP = {
		:int8 => NumType.new(-2 ** 7, 2 ** 7 - 1, 1),
		:uint8 => NumType.new(0, 2 ** 8 - 1, 1),
		:int16 => NumType.new(-2 ** 15, 2 ** 15 - 1, 2),
		:uint16 => NumType.new(0, 2 ** 16 - 1, 2),
		:int32 => NumType.new(-2 ** 31, 2 ** 31 - 1, 4),
		:uint32 => NumType.new(0, 2 ** 32 - 1, 4),
		:int64 => NumType.new(-2 ** 63, 2 ** 63 - 1, 8),
		:uint64 => NumType.new(0, 2 ** 64 - 1, 8),
	}
	# Set a key to the specified value.
	# A convenience wrapper around {#set} to automatically determine the type.
	# If the value is numeric, we will use the same type as the existing value (if it already exists). Otherwise we pick the smallest type that will hold the value.
	#
	# @param name [String] The name of the key
	# @param value [Number,String] The value to set
	#
	# @return [Number,String] The value as stored in the CMAP service. This will normally be the value passed in, but if you store a non-string as a string, the return will be the result of to_s
	def set_value(name, value)
		type = catch :type do
			# strings are strings
			throw :type, :string if value.is_a?(String)

			# try and get existing type
			begin
				type_ptr = FFI::MemoryPointer.new(Corosync.find_type(:cmap_value_types_t))
				size_ptr = FFI::MemoryPointer.new(:size_t)
				Corosync.cs_send(:cmap_get, @handle, name, nil, size_ptr, type_ptr)
				type = type_ptr.read_type(Corosync.find_type(:cmap_value_types_t))
				type = Corosync.enum_type(:cmap_value_types_t)[type]
				if SIZEMAP.keys.include?(type) then
					size = size_ptr.read_type(:size_t)
					if size <= SIZEMAP[type].bytes then
						# it fits within the existing type
						throw :type, type
					end
					# it doesnt fit, we need to re-type it
				else
					raise RuntimeError, "Received unexpected type: #{type}"
				end
			rescue Corosync::NotExistError
			end

			# find the type that will fit
			if value.is_a?(Float) then
				type = :double
			elsif value.is_a?(Numeric) then
				if value.abs <= 2 ** 7 and value < 0 then
					type = :int8
				elsif value <= 2 ** 8 and value >= 0 then
					type = :uint8
				elsif value.abs <= 2 ** 15 and value < 0 then
					type = :int16
				elsif value <= 2 ** 16 and value >= 0 then
					type = :uint16
				elsif value.abs <= 2 ** 31 and value < 0 then
					type = :int32
				elsif value <= 2 ** 32 and value >= 0 then
					type = :uint32
				elsif value.abs <= 2 ** 63 and value < 0 then
					type = :int64
				elsif value < 2 ** 64 and value >= 0 then
					type = :uint64
				else
					raise ArgumentError, "Corosync cannot handle numbers larger than 64-bit"
				end

				throw :type, type
			end

			# Unknown type, force it into a string
			throw :type, :string
		end

		value = value.to_s if type == :string and !value.is_a?(String)

		set(name, type, value)
	end

	# Delete the specified key.
	#
	# @param name [String] The name of the key
	#
	# @return [void]
	def delete(name)
		Corosync.cs_send(:cmap_delete, @handle, name)
	end

	# Decrement the specified key.
	#
	# @param name [String] The name of the key
	#
	# @return [void]
	def dec(name)
		Corosync.cs_send(:cmap_dec, @handle, name)
	end

	# Increment the specified key.
	#
	# @param name [String] The name of the key
	#
	# @return [void]
	def inc(name)
		Corosync.cs_send(:cmap_inc, @handle, name)
	end

	# Get a list of keys.
	#
	# @param prefix [String] Filter the list of keys to those starting with the specified prefix
	#
	# @return [Array<String>] List of matching key names
	def keys(prefix = nil)
		cmap_iteration_handle_ptr = FFI::MemoryPointer.new(Corosync.find_type(:cmap_iter_handle_t))
		Corosync.cs_send(:cmap_iter_init, @handle, prefix, cmap_iteration_handle_ptr)
		cmap_iteration_handle = cmap_iteration_handle_ptr.read_type(Corosync.find_type(:cmap_iter_handle_t))

		keys = []

		key_name_ptr = FFI::MemoryPointer.new(Corosync::CMAP_KEYNAME_MAXLEN)
		begin
			begin
				loop do
					Corosync.cs_send(:cmap_iter_next, @handle, cmap_iteration_handle, key_name_ptr, nil, nil)

					# we really don't need to get info on the value. it doesn't help us any
					#value_size = value_len_ptr.read_type(:size_t)
					#value_type = value_type_ptr.read_type(Corosync.find_type(:cmap_value_types_t))
					#value_type = Corosync.enum_type(:cmap_value_types_t)[value_type]
					#keys[key_name_ptr.read_string] = Corosync::CMAP::ValueInfo.new(value_size, value_type)

					keys << key_name_ptr.read_string
				end
			rescue Corosync::NoSectionsError
				# signals end of iteration
			end
		ensure
			Corosync.cs_send(:cmap_iter_finalize, @handle, cmap_iteration_handle)
		end

		keys
	end

	# Watch keys for changes.
	# Calls a callback when the watched key(s) are changed.
	#
	# @param name [String] The specified key (or prefix)
	# @param actions [Array<Symbol>] The operations to watch for
	#   * :add - The key is added
	#   * :delete - The key is deleted
	#   * :modify - The value/type is changed
	# @param prefix [Boolean] Whether to use the name as a prefix and watch all keys under it
	# @param block [Proc] The callback to call when an event is triggered.
	#
	# @yieldparam action [Symbol] The action that triggered the callback (:add, :delete, :modify)
	# @yieldparam key [String] The name of the key which changed
	# @yieldparam value_new_type [Symbol] The type of the new value. +nil+ if just deleted
	# @yieldparam value_new_data [Number,String] The new value. +nil+ if just deleted
	# @yieldparam value_old_type [Symbol] The type of the old value. +nil+ if just created
	# @yieldparam value_old_data [Number,String] The old value. +nil+ if just created
	#
	# @return [Object] The handle used to identify the track session. Pass to {#track_delete} to stop tracking.
	def track_add(name, actions, prefix = false, &block)
		cs_track_type = 0
		cs_track_type |= Corosync::CMAP_TRACK_ADD if actions.include?(:add)
		cs_track_type |= Corosync::CMAP_TRACK_DELETE if actions.include?(:delete)
		cs_track_type |= Corosync::CMAP_TRACK_MODIFY if actions.include?(:modify)

		cs_track_type |= Corosync::CMAP_TRACK_PREFIX if prefix

		track_handle_ptr = FFI::MemoryPointer.new(Corosync.find_type(:cmap_track_handle_t))

		@track_notify_method ||= self.method(:track_notify) # we have to keep it from being garbage collected
		Corosync.cs_send(:cmap_track_add, @handle, name, cs_track_type, @track_notify_method, nil, track_handle_ptr)

		track_handle = track_handle_ptr.read_type(Corosync.find_type(:cmap_track_handle_t))
		@track_handle_callbacks[track_handle] = block

		track_handle
	end

	# Stop watching for changes.
	# @param track_handle [Number] The handle returned by {#track_add}
	#
	# @return [void]
	def track_delete(track_handle)
		@track_handle_callbacks.delete(track_handle)
		Corosync.cs_send(:cmap_track_delete, @handle, track_handle)
	end

	# @!visibility private
	# The callback called by the CMAP library.
	def track_notify(handle, track_handle, event, key, value_new, value_old, user_data)
		block = @track_handle_callbacks[track_handle]
		raise RuntimeError, "Missing callback for track handle #{track_handle.inspect}" unless block # this should not have happened


		action = {Corosync::CMAP_TRACK_ADD => :add, Corosync::CMAP_TRACK_DELETE => :delete, Corosync::CMAP_TRACK_MODIFY => :modify}[event]
		if value_new[:type] != 0 then
		#if !value_new.null? then
			#value_new = Corosync::CmapNotifyValue.new(value_new)
			value_new_type = value_new[:type]
			value_new_data = value_new[:data].read_type(value_new_type)
		end
		if value_old[:type] != 0 then
		#if !value_old.null? then
			#value_old = Corosync::CmapNotifyValue.new(value_old)
			value_old_type = value_old[:type]
			value_old_data = value_old[:data].read_type(value_old_type)
		end
		block.call(action, key, value_new_type, value_new_data, value_old_type, value_old_data)
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
			Corosync.cs_send!(:cmap_dispatch, @handle, Corosync::CS_DISPATCH_ONE_NONBLOCKING)
		rescue Corosync::TryAgainError => e
			raise e if e.depth > 1 # this exception is from a nested corosync function, not our quorum_dispatch we just called
			return false
		end

		return true
	end
end
