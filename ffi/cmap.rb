
require File.expand_path('../common.rb', __FILE__)

module Corosync
  extend FFI::Library
  ffi_lib 'libcmap'

  typedef :uint64, :cmap_handle_t
  typedef :uint64, :cmap_iter_handle_t
  typedef :uint64, :cmap_track_handle_t
  CMAP_KEYNAME_MAXLEN = 255
  CMAP_KEYNAME_MINLEN = 3
  CMAP_TRACK_ADD = 4
  CMAP_TRACK_DELETE = 1
  CMAP_TRACK_MODIFY = 2
  CMAP_TRACK_PREFIX = 8
  CMAP_VALUETYPE_INT8 = 1
  CMAP_VALUETYPE_UINT8 = 2
  CMAP_VALUETYPE_INT16 = 3
  CMAP_VALUETYPE_UINT16 = 4
  CMAP_VALUETYPE_INT32 = 5
  CMAP_VALUETYPE_UINT32 = 6
  CMAP_VALUETYPE_INT64 = 7
  CMAP_VALUETYPE_UINT64 = 8
  CMAP_VALUETYPE_FLOAT = 9
  CMAP_VALUETYPE_DOUBLE = 10
  CMAP_VALUETYPE_STRING = 11
  CMAP_VALUETYPE_BINARY = 12
  cmap_value_types_t = enum :cmap_value_types_t, [
    :int8, 1,
    :uint8, 2,
    :int16, 3,
    :uint16, 4,
    :int32, 5,
    :uint32, 6,
    :int64, 7,
    :uint64, 8,
    :float, 9,
    :double, 10,
    :string, 11,
    :binary, 12,
  ]

  class CmapNotifyValue < FFI::Struct
    layout(
           :type, :cmap_value_types_t,
           :len, :size_t,
           :data, :pointer
    )
  end
  Callback_cmap_notify_fn_t = callback(:cmap_notify_fn_t, [ :cmap_handle_t, :cmap_track_handle_t, :int32, :string, CmapNotifyValue.by_value, CmapNotifyValue.by_value, :pointer ], :void)
  attach_function :cmap_initialize, :cmap_initialize, [ :pointer ], :cs_error_t
  attach_function :cmap_finalize, :cmap_finalize, [ :cmap_handle_t ], :cs_error_t
  attach_function :cmap_fd_get, :cmap_fd_get, [ :cmap_handle_t, :pointer ], :cs_error_t
  attach_function :cmap_dispatch, :cmap_dispatch, [ :cmap_handle_t, :cs_dispatch_flags_t ], :cs_error_t
  attach_function :cmap_context_get, :cmap_context_get, [ :cmap_handle_t, :pointer ], :cs_error_t
  attach_function :cmap_context_set, :cmap_context_set, [ :cmap_handle_t, :pointer ], :cs_error_t
  attach_function :cmap_set, :cmap_set, [ :cmap_handle_t, :string, :pointer, :size_t, :cmap_value_types_t ], :cs_error_t
  attach_function :cmap_set_int8, :cmap_set_int8, [ :cmap_handle_t, :string, :int8 ], :cs_error_t
  attach_function :cmap_set_uint8, :cmap_set_uint8, [ :cmap_handle_t, :string, :uint8 ], :cs_error_t
  attach_function :cmap_set_int16, :cmap_set_int16, [ :cmap_handle_t, :string, :int16 ], :cs_error_t
  attach_function :cmap_set_uint16, :cmap_set_uint16, [ :cmap_handle_t, :string, :uint16 ], :cs_error_t
  attach_function :cmap_set_int32, :cmap_set_int32, [ :cmap_handle_t, :string, :int32 ], :cs_error_t
  attach_function :cmap_set_uint32, :cmap_set_uint32, [ :cmap_handle_t, :string, :uint32 ], :cs_error_t
  attach_function :cmap_set_int64, :cmap_set_int64, [ :cmap_handle_t, :string, :int64 ], :cs_error_t
  attach_function :cmap_set_uint64, :cmap_set_uint64, [ :cmap_handle_t, :string, :uint64 ], :cs_error_t
  attach_function :cmap_set_float, :cmap_set_float, [ :cmap_handle_t, :string, :float ], :cs_error_t
  attach_function :cmap_set_double, :cmap_set_double, [ :cmap_handle_t, :string, :double ], :cs_error_t
  attach_function :cmap_set_string, :cmap_set_string, [ :cmap_handle_t, :string, :string ], :cs_error_t
  attach_function :cmap_delete, :cmap_delete, [ :cmap_handle_t, :string ], :cs_error_t
  attach_function :cmap_get, :cmap_get, [ :cmap_handle_t, :string, :pointer, :pointer, :pointer ], :cs_error_t
  attach_function :cmap_get_int8, :cmap_get_int8, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_uint8, :cmap_get_uint8, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_int16, :cmap_get_int16, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_uint16, :cmap_get_uint16, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_int32, :cmap_get_int32, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_uint32, :cmap_get_uint32, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_int64, :cmap_get_int64, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_uint64, :cmap_get_uint64, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_float, :cmap_get_float, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_double, :cmap_get_double, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_get_string, :cmap_get_string, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_inc, :cmap_inc, [ :cmap_handle_t, :string ], :cs_error_t
  attach_function :cmap_dec, :cmap_dec, [ :cmap_handle_t, :string ], :cs_error_t
  attach_function :cmap_iter_init, :cmap_iter_init, [ :cmap_handle_t, :string, :pointer ], :cs_error_t
  attach_function :cmap_iter_next, :cmap_iter_next, [ :cmap_handle_t, :cmap_iter_handle_t, :pointer, :pointer, :pointer ], :cs_error_t
  attach_function :cmap_iter_finalize, :cmap_iter_finalize, [ :cmap_handle_t, :cmap_iter_handle_t ], :cs_error_t
  attach_function :cmap_track_add, :cmap_track_add, [ :cmap_handle_t, :string, :int32, Callback_cmap_notify_fn_t, :pointer, :pointer ], :cs_error_t
  attach_function :cmap_track_delete, :cmap_track_delete, [ :cmap_handle_t, :cmap_track_handle_t ], :cs_error_t

end
