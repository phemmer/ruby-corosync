require File.expand_path('../lib/version.rb', __FILE__)

Gem::Specification.new 'corosync', Corosync::GEM_VERSION do |s|
	s.description = 'An interface to the Corosync clustering services.'
	s.summary = 'Corosync library interface'
	s.homepage = 'http://github.com/phemmer/ruby-corosync/'
	s.author = 'Patrick Hemmer'
	s.email = 'patrick.hemmer@gmail.com'
	s.license = 'MIT'
	s.files = %x{git ls-files}.split("\n")

	s.add_runtime_dependency 'ffi', '~> 1.9'
end
