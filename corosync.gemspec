require File.expand_path('../lib/version.rb', __FILE__)

Gem::Specification.new 'corosync', Corosync::GEM_VERSION do |s|
	s.description = 'Provides an interface to the Corosync services.'
	s.summary = 'Corosync library interface'
	s.authors = [ 'Patrick Hemmer' ]
	s.homepage = 'http://github.com/phemmer/ruby-corosync/'
	s.files = %x{git ls-files}.split("\n")

	s.add_dependency 'ffi', '~> 1.9'
end
