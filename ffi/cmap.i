%module Corosync
%{
require File.expand_path('../common.rb', __FILE__)

module Corosync
  extend FFI::Library
  ffi_lib 'libcmap'

%}
%import "common.i"
%include <corosync/cmap.h>
%{
end
%}
