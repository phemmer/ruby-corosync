# ruby-corosync

## Description

Ruby-corosync is a gem for interfacing ruby with the corosync cluster services.

Corosync is a cluster communication engine for communication between nodes operating as a cluster. The services it offers are as follows:

* **CPG** - The CPG service which allows sending messages between nodes. Processes can join a 'group' and broadcast messages to that group. Order is preserved in that messages are guaranteed to arrive in the same order to all members.
* **SAM** - SAM is a service which is meant to ensure processes remain operational. You can instruct corosync to start a process, and should that process die, corosync can notify you, and start it back up.
* **Quorum** - The quorum service is a very basic service used for keeping track of whether the cluster has quorum or not.
* **Votequorum** - The votequorum service is a more powerful version of the quorum service. It allows you to control the number of votes provided by any one node such that you can control the logic that determines whether the cluster is quorate.
* **CMAP** - CMAP is a key/value store of the Corosync configuration database. You can get/set keys/values and watch them for changes.


Corosync offers these services through a C API. This gem utilizes [ffi](http://github.com/ffi/ffi) to provide the interface to that API.


## State

CPG, Quorum, Votequorum, and CMAP are feature complete. Possibly with bugs, but I personally use CPG very heavily, along the basic features of Quorum and CMAP.

## Examples

There are fully functional example scripts in the `examples` directory. But below are some brief snippets.

### CPG
    require 'corosync/cpg'
    cpg = Corosync::CPG.new('mygroup')
    cpg.on_message do |message, sender|
      puts "Received #{message} from #{sender.nodeid}:#{sender.pid}"
    end
    puts "Member node IDs: #{cpg.members.map {|m| m.nodeid}.join(" ")}"
    cpg.send "hello"
    loop do
      cpg.dispatch
    end

### CMAP
    require 'corosync/cmap'
    cmap = Corosync::CMAP.new
    cmap.set('mykey.foo', :int32, -1234)
    puts "mykey.foo is #{cmap.get('mykey.foo')}"


## Contributions
I welcome any contributions in the form of bugs or pull requests. One thing to be aware of in terms of new features is that the goal of this gem is to provide a low level interface to the Corosync library. Features which simplify or abstract things should be implemented as separate gems. For example, my own [corosync commander](http://github.com/phemmer/ruby-corosync-commander).


## Versioning

I use a slight variant of [semantic versioning](http://semver.org). The scheme is: DESIGN.MAJOR.MINOR.PATCH

The DESIGN is used to indicate when not only is it no longer backwards compatable, but the fundamental design has changed. Meaning that it may take more than a little tweaking to accomidate for the changes. This should rarely, if ever, happen.
