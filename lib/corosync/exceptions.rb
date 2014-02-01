module Corosync

  # Base class that all Corosync exceptions descend from.  
  # Corosync exception classes are programitcally generated from the `:cs_error_t` enum in `ffi/common.rb`. See that file for a comprehensive list of exception classes. The `:err_try_again` value will map to `Corosync::TryAgainError`. All exception classes follow the same pattern.
  class Error < StandardError
		Map = {}

    # @!attribute [rw] depth
    # The number of {Corosync.cs_send} methods the exception has passed through. This is important so that we don't rescue nested exceptions. For example, we call cs_send(:cpg_dispatch) which calls a callback which calls cs_send(:cpg_mcast_joined). If the cpg_mcast_joined were to raise an exception, and we had a rescue around the cpg_dispatch, we wouldn't know whether the exception came from cpg_mcast_joined or cpg_dispatch. However in this case the depth would be 2, and so we would know not to rescue it.
    # @return [Fixnum] Number of cs_send methods the exception has passed through
    def depth
      @depth ||= 0
    end
    def depth=(value)
      @depth = value
    end
  end

  Corosync.enum_type(:cs_error_t).to_h.each do |name, value|
    next if name == :ok

    name_s = name.to_s.sub(/^err_/, '').capitalize.gsub(/_(.)/){|m| m[1].upcase} + 'Error'

    c = Class.new(Error) do
      const_set :VALUE, value
      def value
        self.class.const_get :VALUE
      end
    end
		const_set name_s, c

		Error::Map[name] = c
  end
end
