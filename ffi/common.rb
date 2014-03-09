
require 'ffi'

module Corosync
  extend FFI::Library
  ffi_lib 'libcorosync_common'

  class Iovec < FFI::Struct
    layout(
           :iov_base, :pointer,
           :iov_len, :size_t
    )
  end
  typedef :int64, :cs_time_t
  CS_FALSE = 0
  CS_TRUE = !0
  CS_MAX_NAME_LENGTH = 256
  class CsNameT < FFI::Struct
    layout(
           :length, :uint16,
           :value, [:uint8, 256]
    )
  end
  class CsVersionT < FFI::Struct
    layout(
           :releaseCode, :char,
           :majorVersion, :uchar,
           :minorVersion, :uchar
    )
  end
  CS_DISPATCH_ONE = 1
  CS_DISPATCH_ALL = 2
  CS_DISPATCH_BLOCKING = 3
  CS_DISPATCH_ONE_NONBLOCKING = 4
  cs_dispatch_flags_t = enum :cs_dispatch_flags_t, [
    :one, 1,
    :all, 2,
    :blocking, 3,
    :one_nonblocking, 4,
  ]

  CS_TRACK_CURRENT = 0x01
  CS_TRACK_CHANGES = 0x02
  CS_TRACK_CHANGES_ONLY = 0x04
  CS_OK = 1
  CS_ERR_LIBRARY = 2
  CS_ERR_VERSION = 3
  CS_ERR_INIT = 4
  CS_ERR_TIMEOUT = 5
  CS_ERR_TRY_AGAIN = 6
  CS_ERR_INVALID_PARAM = 7
  CS_ERR_NO_MEMORY = 8
  CS_ERR_BAD_HANDLE = 9
  CS_ERR_BUSY = 10
  CS_ERR_ACCESS = 11
  CS_ERR_NOT_EXIST = 12
  CS_ERR_NAME_TOO_LONG = 13
  CS_ERR_EXIST = 14
  CS_ERR_NO_SPACE = 15
  CS_ERR_INTERRUPT = 16
  CS_ERR_NAME_NOT_FOUND = 17
  CS_ERR_NO_RESOURCES = 18
  CS_ERR_NOT_SUPPORTED = 19
  CS_ERR_BAD_OPERATION = 20
  CS_ERR_FAILED_OPERATION = 21
  CS_ERR_MESSAGE_ERROR = 22
  CS_ERR_QUEUE_FULL = 23
  CS_ERR_QUEUE_NOT_AVAILABLE = 24
  CS_ERR_BAD_FLAGS = 25
  CS_ERR_TOO_BIG = 26
  CS_ERR_NO_SECTIONS = 27
  CS_ERR_CONTEXT_NOT_FOUND = 28
  CS_ERR_TOO_MANY_GROUPS = 30
  CS_ERR_SECURITY = 100
  cs_error_t = enum :cs_error_t, [
    :ok, 1,
    :err_library, 2,
    :err_version, 3,
    :err_init, 4,
    :err_timeout, 5,
    :err_try_again, 6,
    :err_invalid_param, 7,
    :err_no_memory, 8,
    :err_bad_handle, 9,
    :err_busy, 10,
    :err_access, 11,
    :err_not_exist, 12,
    :err_name_too_long, 13,
    :err_exist, 14,
    :err_no_space, 15,
    :err_interrupt, 16,
    :err_name_not_found, 17,
    :err_no_resources, 18,
    :err_not_supported, 19,
    :err_bad_operation, 20,
    :err_failed_operation, 21,
    :err_message_error, 22,
    :err_queue_full, 23,
    :err_queue_not_available, 24,
    :err_bad_flags, 25,
    :err_too_big, 26,
    :err_no_sections, 27,
    :err_context_not_found, 28,
    :err_too_many_groups, 30,
    :err_security, 100,
  ]

  CS_IPC_TIMEOUT_MS = -1
  CS_TIME_MS_IN_SEC = 1000
  CS_TIME_US_IN_SEC = 1000000
  CS_TIME_NS_IN_SEC = 1000000000
  CS_TIME_US_IN_MSEC = 1000
  CS_TIME_NS_IN_MSEC = 1000000
  CS_TIME_NS_IN_USEC = 1000
  # inline function cs_timestamp_get
  attach_function :qb_to_cs_error, :qb_to_cs_error, [ :int ], :cs_error_t
  attach_function :cs_strerror, :cs_strerror, [ :cs_error_t ], :string
  attach_function :hdb_error_to_cs, :hdb_error_to_cs, [ :int ], :cs_error_t

end
