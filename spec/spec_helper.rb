# we have to use the full path because rspec puts itself higher on the list, and we end up requiring `spec/corosync/cpg`
$:.unshift(File.expand_path('../../lib', __FILE__))
