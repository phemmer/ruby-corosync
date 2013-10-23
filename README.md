# ruby-corosync

## Description

Ruby-corosync is a gem for interfacing ruby with the corosync cluster services.

Corosync is a cluster communication engine for communication between nodes operating as a cluster. The services it offers are as follows:

* **CPG** - The CPG service which allows sending messages between nodes. Processes can join a 'group' and broadcast messages to that group. Order is preserved in that messages are guaranteed to arrive in the same order to all members.
* **SAM** - SAM is a service which is meant to ensure processes remain operational. You can instruct corosync to start a process, and should that process die, corosync can notify you, and start it back up.
* **Quorum** - The quorum service is a very basic service used for keeping track of whether the cluster has quorum or not.
* **Votequorum** - The votequorum service is a more powerful version of the quorum service. It allows you to control the number of votes provided by any one node such that you can control the logic that determines whether the cluster is quorate.
* **CMAP** - CMAP is a key/value store. It allows you to store keys & their values, and subscribe to changes made to those keys.


Corosync offers these services through a C API. This gem utilizes [ffi](http://github.com/ffi/ffi) to provide the interface to that API.

## State

Currently the only supported service is CPG. It is fully functional, though it may change as it is very young.

## Examples

### CPG

    cpg = Corosync::CPG.new('mygroup')
    cpg.on_message do |message, membership|
      puts "Received #{message}"
    end
    puts "Member node IDs: #{cpg.members.map {|m| m.nodeid}.join(" ")}"
    cpg.send "hello"
    loop do
      cpg.dispatch
    end
