%module Corosync
%{
require 'ffi'

module Corosync
  extend FFI::Library
  ffi_lib 'libcorosync_common'

%}
struct iovec /* from bits/uio.h */
  {
    void *iov_base;	/* Pointer to data.  */
    size_t iov_len;	/* Length of data.  */
  };
%include <corosync/corotypes.h>
%{
end
%}
