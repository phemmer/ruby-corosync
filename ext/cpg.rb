
require File.expand_path('../common.rb', __FILE__)

module Corosync
  extend FFI::Library
  ffi_lib 'libcpg'

  typedef :uint64, :cpg_handle_t
  typedef :uint64, :cpg_iteration_handle_t
  cpg_guarantee_t = enum :cpg_guarantee_t, [
    :unordered,
    :fifo,
    :agreed,
    :safe,
  ]
  CPG_TYPE_UNORDERED = 0
  CPG_TYPE_FIFO = CPG_TYPE_UNORDERED + 1
  CPG_TYPE_AGREED = CPG_TYPE_FIFO + 1
  CPG_TYPE_SAFE = CPG_TYPE_AGREED + 1

  cpg_flow_control_state_t = enum :cpg_flow_control_state_t, [
    :disabled,
    :enabled,
  ]
  CPG_FLOW_CONTROL_DISABLED = 0
  CPG_FLOW_CONTROL_ENABLED = CPG_FLOW_CONTROL_DISABLED + 1

  cpg_reason_t = enum :cpg_reason_t, [
    :join, 1,
    :leave, 2,
    :nodedown, 3,
    :nodeup, 4,
    :procdown, 5,
  ]
  CPG_REASON_JOIN = 1
  CPG_REASON_LEAVE = 2
  CPG_REASON_NODEDOWN = 3
  CPG_REASON_NODEUP = 4
  CPG_REASON_PROCDOWN = 5

  cpg_iteration_type_t = enum :cpg_iteration_type_t, [
    :name_only, 1,
    :one_group, 2,
    :all, 3,
  ]
  CPG_ITERATION_NAME_ONLY = 1
  CPG_ITERATION_ONE_GROUP = 2
  CPG_ITERATION_ALL = 3

  cpg_model_t = enum :cpg_model_t, [
    :v1, 1,
  ]
  CPG_MODEL_V1 = 1

  class CpgAddress < FFI::Struct
    layout(
           :nodeid, :uint32,
           :pid, :uint32,
           :reason, :uint32
    )
  end
  CPG_MAX_NAME_LENGTH = 128
  class CpgName < FFI::Struct
    layout(
           :length, :uint32,
           :value, [:char, 128]
    )
  end
  CPG_MEMBERS_MAX = 128
  class CpgIterationDescriptionT < FFI::Struct
    layout(
           :group, CpgName,
           :nodeid, :uint32,
           :pid, :uint32
    )
  end
  class CpgRingId < FFI::Struct
    layout(
           :nodeid, :uint32,
           :seq, :uint64
    )
  end
  Callback_cpg_deliver_fn_t = callback(:cpg_deliver_fn_t, [ :cpg_handle_t, :pointer, :uint32, :uint32, :pointer, :uint ], :void)
  Callback_cpg_confchg_fn_t = callback(:cpg_confchg_fn_t, [ :cpg_handle_t, :pointer, :pointer, :uint, :pointer, :uint, :pointer, :uint ], :void)
  Callback_cpg_totem_confchg_fn_t = callback(:cpg_totem_confchg_fn_t, [ :cpg_handle_t, CpgRingId, :uint32, :pointer ], :void)
  class CpgCallbacksT < FFI::Struct
    layout(
           :cpg_deliver_fn, :cpg_deliver_fn_t,
           :cpg_confchg_fn, :cpg_confchg_fn_t
    )
  end
  class CpgModelDataT < FFI::Struct
    layout(
           :model, :cpg_model_t
    )
  end
  CPG_MODEL_V1_DELIVER_INITIAL_TOTEM_CONF = 0x01
  class CpgModelV1DataT < FFI::Struct
    layout(
           :model, :cpg_model_t,
           :cpg_deliver_fn, :cpg_deliver_fn_t,
           :cpg_confchg_fn, :cpg_confchg_fn_t,
           :cpg_totem_confchg_fn, :cpg_totem_confchg_fn_t,
           :flags, :uint
    )
  end
  attach_function :cpg_initialize, :cpg_initialize, [ :pointer, :pointer ], :cs_error_t
  attach_function :cpg_model_initialize, :cpg_model_initialize, [ :pointer, :cpg_model_t, :pointer, :pointer ], :cs_error_t
  attach_function :cpg_finalize, :cpg_finalize, [ :cpg_handle_t ], :cs_error_t
  attach_function :cpg_fd_get, :cpg_fd_get, [ :cpg_handle_t, :pointer ], :cs_error_t
  attach_function :cpg_context_get, :cpg_context_get, [ :cpg_handle_t, :pointer ], :cs_error_t
  attach_function :cpg_context_set, :cpg_context_set, [ :cpg_handle_t, :pointer ], :cs_error_t
  attach_function :cpg_dispatch, :cpg_dispatch, [ :cpg_handle_t, :cs_dispatch_flags_t ], :cs_error_t
  attach_function :cpg_join, :cpg_join, [ :cpg_handle_t, :pointer ], :cs_error_t
  attach_function :cpg_leave, :cpg_leave, [ :cpg_handle_t, :pointer ], :cs_error_t
  attach_function :cpg_mcast_joined, :cpg_mcast_joined, [ :cpg_handle_t, :cpg_guarantee_t, :pointer, :uint ], :cs_error_t
  attach_function :cpg_membership_get, :cpg_membership_get, [ :cpg_handle_t, :pointer, :pointer, :pointer ], :cs_error_t
  attach_function :cpg_local_get, :cpg_local_get, [ :cpg_handle_t, :pointer ], :cs_error_t
  attach_function :cpg_flow_control_state_get, :cpg_flow_control_state_get, [ :cpg_handle_t, :pointer ], :cs_error_t
  attach_function :cpg_zcb_alloc, :cpg_zcb_alloc, [ :cpg_handle_t, :uint, :pointer ], :cs_error_t
  attach_function :cpg_zcb_free, :cpg_zcb_free, [ :cpg_handle_t, :pointer ], :cs_error_t
  attach_function :cpg_zcb_mcast_joined, :cpg_zcb_mcast_joined, [ :cpg_handle_t, :cpg_guarantee_t, :pointer, :uint ], :cs_error_t
  attach_function :cpg_iteration_initialize, :cpg_iteration_initialize, [ :cpg_handle_t, :cpg_iteration_type_t, :pointer, :pointer ], :cs_error_t
  attach_function :cpg_iteration_next, :cpg_iteration_next, [ :cpg_iteration_handle_t, :pointer ], :cs_error_t
  attach_function :cpg_iteration_finalize, :cpg_iteration_finalize, [ :cpg_iteration_handle_t ], :cs_error_t

end
