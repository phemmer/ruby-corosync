########################################
desc "Create ext/*.rb files"
multitask :ext

file 'ext/common.i' do # exempt 'ext/common.i' from the service rule below
end
rule '.i' => [proc {'ext/service.i.erb'}] do |t|
	File.open(t.name, 'w') do |f|
		puts "generating #{t.name}\n"
		require 'erb'
		service = t.name.split('/').last.split('.').first
		erb = ERB.new(File.read("ext/service.i.erb"), nil, '-')
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

corosync_services = ['cpg']
multitask :ext => ['ext/common.rb'] + corosync_services.map{|s| "ext/#{s}.rb"}

