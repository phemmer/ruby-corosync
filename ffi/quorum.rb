
require File.expand_path('../common.rb', __FILE__)

module Corosync
  extend FFI::Library
  ffi_lib 'libquorum'

  class QuorumCallbacksT < FFI::Struct; end
  typedef :uint64, :quorum_handle_t
  Callback_quorum_notification_fn_t = callback(:quorum_notification_fn_t, [ :quorum_handle_t, :uint32, :uint64, :uint32, :pointer ], :void)
  class QuorumCallbacksT < FFI::Struct
    layout(
           :quorum_notify_fn, Callback_quorum_notification_fn_t
    )
    def quorum_notify_fn=(cb)
      @quorum_notify_fn = cb
      self[:quorum_notify_fn] = @quorum_notify_fn
    end
    def quorum_notify_fn
      @quorum_notify_fn
    end

  end
  QUORUM_FREE = 0
  QUORUM_SET = 1
  attach_function :quorum_initialize, :quorum_initialize, [ :pointer, QuorumCallbacksT.ptr, :pointer ], :cs_error_t
  attach_function :quorum_finalize, :quorum_finalize, [ :quorum_handle_t ], :cs_error_t
  attach_function :quorum_fd_get, :quorum_fd_get, [ :quorum_handle_t, :pointer ], :cs_error_t
  attach_function :quorum_dispatch, :quorum_dispatch, [ :quorum_handle_t, :cs_dispatch_flags_t ], :cs_error_t
  attach_function :quorum_getquorate, :quorum_getquorate, [ :quorum_handle_t, :pointer ], :cs_error_t
  attach_function :quorum_trackstart, :quorum_trackstart, [ :quorum_handle_t, :uint ], :cs_error_t
  attach_function :quorum_trackstop, :quorum_trackstop, [ :quorum_handle_t ], :cs_error_t
  attach_function :quorum_context_set, :quorum_context_set, [ :quorum_handle_t, :pointer ], :cs_error_t
  attach_function :quorum_context_get, :quorum_context_get, [ :quorum_handle_t, :pointer ], :cs_error_t

end
