Gem::Specification.new 'corosync', File.read('VERSION').chomp do |s|
	s.description = 'An interface to the Corosync clustering services.'
	s.summary = 'Corosync library interface'
	s.homepage = 'http://github.com/phemmer/ruby-corosync/'
	s.author = 'Patrick Hemmer'
	s.email = 'patrick.hemmer@gmail.com'
	s.license = 'MIT'
	s.files = %x{git ls-files}.split("\n")

	s.required_ruby_version = '>= 2.0.0'

	s.add_runtime_dependency 'ffi', '~> 1.9'
end
