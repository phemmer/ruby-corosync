
require File.expand_path('../common.rb', __FILE__)

module Corosync
  extend FFI::Library
  ffi_lib 'libvotequorum'

  class VotequorumCallbacksT < FFI::Struct; end
  class VotequorumInfo < FFI::Struct; end
  typedef :uint64, :votequorum_handle_t
  VOTEQUORUM_INFO_TWONODE = 1
  VOTEQUORUM_INFO_QUORATE = 2
  VOTEQUORUM_INFO_WAIT_FOR_ALL = 4
  VOTEQUORUM_INFO_LAST_MAN_STANDING = 8
  VOTEQUORUM_INFO_AUTO_TIE_BREAKER = 16
  VOTEQUORUM_INFO_ALLOW_DOWNSCALE = 32
  VOTEQUORUM_INFO_QDEVICE_REGISTERED = 64
  VOTEQUORUM_INFO_QDEVICE_ALIVE = 128
  VOTEQUORUM_INFO_QDEVICE_CAST_VOTE = 256
  VOTEQUORUM_INFO_QDEVICE_MASTER_WINS = 512
  VOTEQUORUM_QDEVICE_NODEID = 0
  VOTEQUORUM_QDEVICE_MAX_NAME_LEN = 255
  VOTEQUORUM_QDEVICE_DEFAULT_TIMEOUT = 10000
  VOTEQUORUM_NODESTATE_MEMBER = 1
  VOTEQUORUM_NODESTATE_DEAD = 2
  VOTEQUORUM_NODESTATE_LEAVING = 3
  class VotequorumInfo < FFI::Struct
    layout(
           :node_id, :uint,
           :node_state, :uint,
           :node_votes, :uint,
           :node_expected_votes, :uint,
           :highest_expected, :uint,
           :total_votes, :uint,
           :quorum, :uint,
           :flags, :uint,
           :qdevice_votes, :uint,
           :qdevice_name, [:char, 255]
    )
  end
  class VotequorumNodeT < FFI::Struct
    layout(
           :nodeid, :uint32,
           :state, :uint32
    )
  end
  Callback_votequorum_notification_fn_t = callback(:votequorum_notification_fn_t, [ :votequorum_handle_t, :uint64, :uint32, :uint32, :pointer ], :void)
  Callback_votequorum_expectedvotes_notification_fn_t = callback(:votequorum_expectedvotes_notification_fn_t, [ :votequorum_handle_t, :uint64, :uint32 ], :void)
  class VotequorumCallbacksT < FFI::Struct
    layout(
           :votequorum_notify_fn, Callback_votequorum_notification_fn_t,
           :votequorum_expectedvotes_notify_fn, Callback_votequorum_expectedvotes_notification_fn_t
    )
    def votequorum_notify_fn=(cb)
      @votequorum_notify_fn = cb
      self[:votequorum_notify_fn] = @votequorum_notify_fn
    end
    def votequorum_notify_fn
      @votequorum_notify_fn
    end
    def votequorum_expectedvotes_notify_fn=(cb)
      @votequorum_expectedvotes_notify_fn = cb
      self[:votequorum_expectedvotes_notify_fn] = @votequorum_expectedvotes_notify_fn
    end
    def votequorum_expectedvotes_notify_fn
      @votequorum_expectedvotes_notify_fn
    end

  end
  attach_function :votequorum_initialize, :votequorum_initialize, [ :pointer, VotequorumCallbacksT.ptr ], :cs_error_t
  attach_function :votequorum_finalize, :votequorum_finalize, [ :votequorum_handle_t ], :cs_error_t
  attach_function :votequorum_dispatch, :votequorum_dispatch, [ :votequorum_handle_t, :cs_dispatch_flags_t ], :cs_error_t
  attach_function :votequorum_fd_get, :votequorum_fd_get, [ :votequorum_handle_t, :pointer ], :cs_error_t
  attach_function :votequorum_getinfo, :votequorum_getinfo, [ :votequorum_handle_t, :uint, VotequorumInfo.ptr ], :cs_error_t
  attach_function :votequorum_setexpected, :votequorum_setexpected, [ :votequorum_handle_t, :uint ], :cs_error_t
  attach_function :votequorum_setvotes, :votequorum_setvotes, [ :votequorum_handle_t, :uint, :uint ], :cs_error_t
  attach_function :votequorum_trackstart, :votequorum_trackstart, [ :votequorum_handle_t, :uint64, :uint ], :cs_error_t
  attach_function :votequorum_trackstop, :votequorum_trackstop, [ :votequorum_handle_t ], :cs_error_t
  attach_function :votequorum_context_get, :votequorum_context_get, [ :votequorum_handle_t, :pointer ], :cs_error_t
  attach_function :votequorum_context_set, :votequorum_context_set, [ :votequorum_handle_t, :pointer ], :cs_error_t
  attach_function :votequorum_qdevice_register, :votequorum_qdevice_register, [ :votequorum_handle_t, :string ], :cs_error_t
  attach_function :votequorum_qdevice_unregister, :votequorum_qdevice_unregister, [ :votequorum_handle_t, :string ], :cs_error_t
  attach_function :votequorum_qdevice_update, :votequorum_qdevice_update, [ :votequorum_handle_t, :string, :string ], :cs_error_t
  attach_function :votequorum_qdevice_poll, :votequorum_qdevice_poll, [ :votequorum_handle_t, :string, :uint ], :cs_error_t
  attach_function :votequorum_qdevice_master_wins, :votequorum_qdevice_master_wins, [ :votequorum_handle_t, :string, :uint ], :cs_error_t

end
