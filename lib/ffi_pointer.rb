require 'ffi'

# We create these 2 methods because of types like `size_t`. The type changes by platform, so we don't know which write/read method to use. So we create a generic read/write that we can pass a type to and it will figure out which method needs to be used.

class FFI::Pointer
	def read_type(type)
		type = FFI.find_type(type) if type.is_a?(Symbol)
		type = type.native_type if type.is_a?(FFI::Type::Mapped)
		raise ArgumentError, "Can only read built-in types (type=#{type})" unless type.is_a?(FFI::Type::Builtin)
		name = type.inspect.match(/<#{type.class}:(\S+)/)[1].downcase
		method = "read_#{name}".to_sym
		self.send(method)
	end
	def write_type(type, value)
		type = FFI.find_type(type) if type.is_a?(Symbol)
		type = type.native_type if type.is_a?(FFI::Type::Mapped)
		raise ArgumentError, "Can only write built-in types (type=#{type})" unless type.is_a?(FFI::Type::Builtin)
		name = type.inspect.match(/<#{type.class}:(\S+)/)[1].downcase
		method = "write_#{name}".to_sym
		self.send(method, value)
	end

	# these are methods where the type name doesn't match the method
	alias_method :write_float32, :write_float
	alias_method :read_float32, :read_float
	alias_method :write_float64, :write_double
	alias_method :read_float64, :read_double
end
