%module Corosync
%{
require File.expand_path('../common.rb', __FILE__)

module Corosync
  extend FFI::Library
  ffi_lib 'libcpg'

%}
%import "common.i"
%include <corosync/cpg.h>
%{
end
%}
