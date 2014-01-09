%module Corosync
%{
require File.expand_path('../common.rb', __FILE__)

module Corosync
  extend FFI::Library
  ffi_lib 'libvotequorum'

%}
%import "common.i"
%include <corosync/votequorum.h>
%{
end
%}
