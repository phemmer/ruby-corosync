########################################
desc "Create ffi/*.rb files"
multitask :ffi

file 'ffi/common.i' do # exempt 'ffi/common.i' from the service rule below
end
rule '.i' => [proc {'ffi/service.i.erb'}] do |t|
	File.open(t.name, 'w') do |f|
		puts "generating #{t.name}\n"
		require 'erb'
		service = t.name.split('/').last.split('.').first
		erb = ERB.new(File.read("ffi/service.i.erb"), nil, '-')
		f.write erb.result(binding)
	end
end
rule '.rb' => ['.i'] do |t|
	puts "generating #{t.name}\n"
	xml = %x{swig -I/usr/include -xml -o /dev/stdout #{t.source}}
	require 'ffi-swig-generator'
	File.open(t.name, 'w') do |f|
		f.write FFI::Generator::Parser.new.generate(Nokogiri::XML(xml))
	end
end

corosync_services = ['cpg','quorum','votequorum', 'cmap']
multitask :ffi => ['ffi/common.rb'] + corosync_services.map{|s| "ffi/#{s}.rb"}

########################################
desc 'Run tests'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:test) do |t|
	t.pattern = 'spec/**/*.rb'
	t.rspec_opts = '-c -f d --fail-fast'
end
