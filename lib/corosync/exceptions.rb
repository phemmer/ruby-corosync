module Corosync

  # Base class that all Corosync exceptions descend from.  
  # Corosync exception classes are programitcally generated from the `:cs_error_t` enum in `ffi/common.rb`. See that file for a comprehensive list of exception classes. The `:err_try_again` value will map to `Corosync::TryAgainError`. All exception classes follow the same pattern.
  class Error < StandardError
		Map = {}
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
