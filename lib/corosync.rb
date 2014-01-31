$:.unshift File.expand_path('../', __FILE__)
require File.expand_path('../../ffi/common.rb', __FILE__)
require 'version'

module Corosync
  require_relative 'corosync/exceptions'

  # Calls a Corosync method and raises an exception on errors.
  # This is a convenience method to handle error responses when calling various corosync library functions. When an error is returned, an exception is raised.
  # The exceptions are programatically generated based off the `:cs_error_t` enum defined in `ffi/common.rb`. For example, `:err_try_again` maps to `Corosync::TryAgainError`.
  #
  # @param method [Symbol] name of the method to call
  # @param args
  #
  # @return [TrueClass, Integer] Returns `true` on success, and an integer if the return value is not known (this should not happen unless you're running a newer version of corosync than the gem was released for).
  def self.cs_send!(method, *args)
    cs_error = send(method, *args)
    return true if cs_error == :ok # short circuit the rest of the method since this should be true the majority of the time

    exception = Error::Map[cs_error]
    raise exception, "Received #{cs_error.to_s.upcase} during #{method}" if exception

    cs_error
  end

  # Calls a Corosync method and raises an exception on error while handling retries.
  # This is the same as {cs_send!} except that on the event of TryAgainError, it tries up to 3 times.
  #
  # @param method [Symbol] name of the method to call
  # @param args
  #
  # @return [TrueClass, Integer] Returns `true` on success, and an integer if the return value is not known (this should not happen unless you're running a newer version of corosync than the gem was released for).
  # @see cs_send!
  def self.cs_send(method, *args)
    tries = 3
    begin
      cs_send!(method, *args)
    rescue TryAgainError => e
      retry if (tries -= 1) >= 0
      raise e
    end
  end
end

