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

########################################
@gemspec_file = Dir.glob('*.gemspec').first
def spec
	require 'rubygems' unless defined? Gem::Specification
	@spec ||= eval(File.read(@gemspec_file))
end

desc 'Bump version'
task 'version' do
	current_version = File.read('VERSION').chomp
	current_version_commit = %x{git rev-parse --verify #{current_version} 2>/dev/null}.chomp
	current_head_commit = %x{git rev-parse HEAD}.chomp
	if current_version_commit != '' and current_version_commit != current_head_commit then
		# there have been commits since the current version

		next_version = current_version.split('.')
		next_version[-1] = next_version.last.to_i + 1
		next_version = next_version.join('.')
		print "Next version? (#{next_version}): "
		response = STDIN.gets.chomp
		if response != '' then
			raise StandardError, "Not a valid version" unless response.match(/^[0-9\.]+$/)
			next_version = response
		end

		File.open('VERSION', 'w') do |file|
			file.puts next_version
		end
		message = %x{git log #{current_version_commit}..HEAD --pretty=format:'* %s%n  %an (%ai) - @%h%n'}.gsub(/'/, "'\\\\''")

		sh "git commit -m 'Version: #{next_version}\n\n#{message}' VERSION"
		sh "git tag #{next_version}"

		@spec = nil
	end
end

desc 'Build gem file'
task 'build' do
	sh "gem build #{@gemspec_file}"
end

desc 'Publish gem file'
task 'publish' do
	gem_file = "#{spec.name}-#{spec.version}.gem"
	sh "git tag #{spec.version}"
	sh "git push"
	sh "gem push #{gem_file}"
end

desc 'Release a new version'
task 'release' do
	raise StandardError, "Not on master branch" if %x{git rev-parse --abbrev-ref HEAD}.chomp != "master"
	raise StandardError, "Uncommitted files" if %x{git status --porcelain}.chomp.size != 0

	[:test, :version, :build, :publish].each do |task|
		puts "# #{task}\n"
		Rake::Task[task].execute
		puts "\n"
	end
end
