#
#	tkMOO
#	~/.tkMOO-light/plugins/mcp21.tcl
#

# tkMOO-light is Copyright (c) Andrew Wilson 1994,1995,1996,1997,1998,1999.
#
#       All Rights Reserved
#
# Permission is hereby granted to use this software for private, academic
# and non-commercial use. No commercial or profitable use of this
# software may be made without the prior permission of the author.
#
# THIS SOFTWARE IS PROVIDED BY ANDREW WILSON ``AS IS'' AND ANY
# EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL ANDREW WILSON BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# *** This is alpha software.  It doesn't even PRETEND to be stable or
# *** accurate.  Do not expect miracles, don't even expect the sun to
# *** come up tomorrow.

# TODO
#
# o	when we see an 'mcp' message and we don't support the given
#	version then we should allow other modules/plugins to get
#	a chance to check the message.  right now we're just
#	swallowing it.  I suppose we could force handlers to return
#	module.module_ok/.module_deferred and do something with that...

# Further information on the MCP/2.1 protocol specification can be
# found here:
#
#	http://www.moo.mud.org/mcp2/

###
#
# The API
# =======
#
# Receiving messages
# ------------------
#
# To handle an incoming message you will need to register a package
# and detail the TCL procedures that will handle each message:
# mcp21.register $package $version $full-message $procedure
#
#    # register the 'foo' package, version 1.0, with 2 messages
#    # 'foo-bar' and 'foo-baz'
#    mcp21.register foo 1.0 foo-bar my_foo_bar
#    mcp21.register foo 1.0 foo-baz another_proc

# Precisely *when* you register matters too.  mcp21 is a plugin
# and like other parts of the client it uses the client.register call
# to initialise itself when the client issues the booting 'start'
# message.  mcp21 needs to be initialised *before* any calls are made
# by other plugins to its own .register procedure.  mcp21 registers
# with the default priority of 50, so a calling plugin should use a
# higher number (60 say) when registering its own .start procedure,
# which calls mcp21.register when the 'start' message arrives.  For
# example:
#
#	# wibble.tcl, an example plugin
#	# wait for mcp21 to initialise before registering
#	client.register wibble start 60
#	proc wibble.start {} {
#	    mcp21.register foo 1.0 foo-bar wibble.foo_bar
#	    mcp21.register foo 1.0 foo-baz wibble.foo_baz
#	}
#
#
# Retreiving arguments
# --------------------

# The client's 'request' API lets your handler procedures pick up
# their arguments.  You need to provide a $request_id of the following
# form.
# 
# 'current'			if the procedure is handling a single-line
#				message.
# value of '_data-tag' field	if the procedure is handling a multi-line
#				message.
# 
# If in doubt the following construction will always work:
# 
# # use the correct request_id
# set request_id current
# catch { set request_id [request.get current _data-tag] }
# # get the message arguments 'blah' and 'wibble'
# set blah [request.get $request_id blah] 
# set wibble [request.get $request_id wibble] 
# 
# request.get $request_id $keyword => value
#
#
# Testing connection capability
# -----------------------------
#
#    # what do server and client have in common.  .report_overlap
#    # returns a list of {package version} pairs.
#    set overlap [mcp21.report_overlap]
#    # pick out the version for the 'dns-com-awns-something' package
#    set version [util.assoc $overlap dns-com-awns-something]
#    # does this application want to support this version?
#    if { ($version == {}) || ([lindex $version 1] != 1.0) } {
#        puts "Sorry, only dns-com-awns-something/1.0 spoken here."
#        return
#    }   
#    # continue processing
#
#
# Sending messages
# ----------------
# mcp21.server_notify $message {keyval-list}
#
#
# Dealing with cords
# ------------------
#
# cord.open $type => $id | ""
# cord.cord $id $message {keyval-list}
# cord.close $id
#
#
# MCP/2.1 argument lists
# ----------------------
#
# A keyval-list contains {keyword value} pairs.  If the value is a
# list then a flag should be added as the 3rd element of the list.
# eg:  {mylist {1 2 3} 1}
#
###

# install into the client and initialise plugin
client.register mcp21 start
client.register mcp21 client_connected
client.register mcp21 incoming 40

proc mcp21.start {} {
    global mcp21_authentication_key mcp21_registry_internal \
	mcp21_report_overlap
    set mcp21_authentication_key ""
    set mcp21_registry_internal {}
    set mcp21_report_overlap {}
    # register a bunch of message handlers
    mcp21.register mcp 2.1 mcp mcp21.do_mcp 
    mcp21.register mcp 2.1 : mcp21.do_:
    mcp21.register mcp 2.1 * mcp21.do_*
    mcp21.register mcp-negotiate 2.0 mcp-negotiate-can mcp21.do_mcp_negotiate_can
    mcp21.register mcp-negotiate 2.0 mcp-negotiate-end mcp21.do_mcp_negotiate_end

    mcp21.register mcp-cord 1.0 mcp-cord mcp21.do_mcp_cord
    mcp21.register mcp-cord 1.0 mcp-cord-open mcp21.do_mcp_cord_open
    mcp21.register mcp-cord 1.0 mcp-cord-closed mcp21.do_mcp_cord_closed
}

proc mcp21.register_internal { module event } {
    global mcp21_registry_internal
    lappend mcp21_registry_internal [list $module $event]
}   

proc mcp21.dispatch_internal event {
    global mcp21_registry_internal
    foreach me $mcp21_registry_internal {  
        if { $event == [lindex $me 1] } {
            [lindex $me 0].$event
        }
    }
}   

# minimal configuration using the preferences
preferences.register mcp21 {Out of Band} {
    { {directive UseModuleMCP21}
        {type boolean}
        {default On}
        {display "Use MCP/2.1"} }
    { {directive MCP21Logging}
        {type boolean}
        {default On}
        {display "Log MCP/2.1 messages"} }
}

# handle connections
proc mcp21.client_connected {} {
    global mcp21_use mcp21_active mcp21_server_registry mcp21_report_overlap \
	   mcp21_log

    set mcp21_report_overlap {}
    set mcp21_server_registry {}

    set mcp21_use 0
    set use [string tolower [worlds.get_generic On {} {} UseModuleMCP21]]
    if { $use == "on" } {
        set mcp21_use 1
    } elseif { $use == "off" } {
        set mcp21_use 0
    }

    set mcp21_log 0
    set log [string tolower [worlds.get_generic On {} {} MCP21Logging]]
    if { $log == "on" } {
        set mcp21_log 1
    } elseif { $log == "off" } {
        set mcp21_log 0
    }

    set mcp21_active 0

    return [modules.module_deferred]
}   

# handle incoming events
proc mcp21.incoming event {
    global mcp21_use mcp21_active mcp21_authentication_key mcp21_log

    if { $mcp21_use == 0 } {
        return [modules.module_deferred]
    }

    # we need to test this thing on a few messages, but we have no
    # access to MCP/2.1 so let's fake something for now.
    set PREFIX {#$}
    set MATCH "$PREFIX*"

    set line [db.get $event line]
    if { [string match $MATCH $line] == 0 } {
	# nothing to do with us
        return [modules.module_deferred]
    }

    # by now we've identified that it's an MCP message, though not
    # for sure an MCP/2.1 message.  Check to see if we need to supress
    # this message in the logfile

    if { $mcp21_log == 0 } {
	# tell the incoming_2 phase of the logging module to ignore
	# this line
	db.set $event logging_ignore_incoming 1
    }

    regexp {^#\$(.)([^ ]+)(.*)} $line all type message rest

    # the Network Layer's quoting mechanism is active whether or
    # not the MCP session has begun.
    if { $type == "\"" } {
	db.set $event line [string range $line 3 end]
        return [modules.module_deferred]
    }

    if { ($mcp21_active == 0) &&
	 ($message != "mcp") } {
        # don't process any messages except for 'mcp' until
        # after we're active
        return [modules.module_deferred]
    }

    # type == '#'

    # clean up ready to process this message
    request.destroy current

    # parse out the header
    set rv 1
    if { $message == "*" } {
	regexp {^ ([^ ]*) ([^:]*): (.*)$} $rest all tag field value
	request.set current _data-tag $tag
	request.set current field $field
	request.set current value $value
    } elseif { $message == ":" } {
	regexp {^ ([^ ]*)} $rest all tag
	request.set current _data-tag $tag
    } {
	set rv [mcp21.parse $rest]
    }

    # check authentication
    if { ([lsearch -exact {* : mcp} $message] < 0) &&
	 ([request.get current _authentication-key] != $mcp21_authentication_key) } {
        return [modules.module_deferred]
    }

    if { $rv == "multiline" } {
	# this is a multiline message save some state, including
	# the original message name
        set tag [request.get current _data-tag]
	request.set current _message $message
        request.duplicate current $tag
    } {
	# use a registered handler if we're using a supported
	# version of MCP
        mcp21.dispatch $message

	# do we want to swallow an unsupported 'mcp' message?  If
	# so then test for mcp_active and return [modules.module_deferred]
    }

    return [modules.module_ok]
}

proc mcp21.parse header {
    set first [lindex $header 0]
    set rv 1

    # find the authentication key in this message.  if the message
    # is '*' then we're really recording the associated _data-tag value.

    if { [string last ":" $first] < 0 } {
        request.set current _authentication-key $first
        set header [lrange $header 1 end]
    }

    foreach { keyword value } $header {
	regsub ":" $keyword "" keyword
	if { [regexp {(.*)\*} $keyword _ field] } {
	    request.set current $field {}
	    set rv "multiline"
	} {
	    request.set current $keyword $value
	}
    }
    return $rv
}           

# look up a handler for this message
# find it, and execute the callback, dropping any return value on the floor
# we can tune this at connect time (after mcp-negotiate-end) by
# dropping all the messages for those package versions the session
# will not support.  

proc mcp21.dispatch message {
    global mcp21_registry

    set overlap [mcp21.report_overlap]
    set package [mcp21.package $message]
    set version [lindex [util.assoc $overlap $package] 1]

    foreach r $mcp21_registry {
	set v		[lindex $r 1]
	set msg		[lindex $r 2]

        if { ($msg == $message) &&
	      (($v == $version) ||
	       ($package == "mcp") || 
	       ($package == "mcp-negotiate")) } {
	    # callback
	    [lindex $r 3]
	    return
	}

    }
}

# register message handlers
# => 1|0
proc mcp21.register {package version message callback} {
    global mcp21_registry
    lappend mcp21_registry [list $package $version $message $callback]
}

# return the package name for this message
proc mcp21.package message {
    global mcp21_registry
    if { [set record [util.assoc $mcp21_registry $message 2]] != {} } {
	return [lindex $record 0]
    }
    return "";
}

# encode strings
proc mcp21.encode str {
    regsub -all {([\\\"])} $str {\\\1} str
    if { [regexp -- {[ :]} $str] } {
        set str "\"$str\""
    }
    if { $str == "" } {
        set str "\"\""    
    }
    return $str
} 

# send messages to the server
proc mcp21.server_notify {message {keyvals {}}} {
    global mcp21_authentication_key

    if { $mcp21_authentication_key == "" } {
	# we were called before the MCP/2.1 authentication key 
	# was set up!
	return
    }

    set multiline 0
    set kvstr ""
    foreach kv $keyvals {
        set k [lindex $kv 0]
        set v [lindex $kv 1]
        set t 0
        if { [llength $kv] == 3 } {
            set t [lindex $kv 2]
        }
        if { $t != 0 } {
            set multiline 1
            append kvstr " $k*: \"\""
            set multiple($k) $v
        } {
            append kvstr " $k: [mcp21.encode $v]"
        }
    }

    if { $multiline == 1 } {
        set tag [util.unique_id d]
        append kvstr " _data-tag: $tag"
    }

    io.outgoing "#$#$message $mcp21_authentication_key$kvstr"

    foreach k [array names multiple] {
        foreach v $multiple($k) {
            io.outgoing "#$#* $tag $k: $v"
        }
    }

    if { $multiline == 1 } {
        io.outgoing "#$#: $tag"
    }
}   


########
# HANDLERS
proc mcp21.do_mcp {} {
    global mcp21_active
    global mcp21_authentication_key

    # this plugin only speaks MCP/2.1, the client may contain other
    # plugins for MCP/1.0
    set version [request.get current version]
    set to [request.get current to]
    if { $version == "2.1" || $to == "2.1" } {
	set mcp21_active 1
    } {
	return
    }

    scan [winfo id .] "0x%x" mcp21_authentication_key
    io.outgoing "#$#mcp authentication-key: $mcp21_authentication_key version: 2.1 to: 2.1"

    # now examine our registry and send all the supported packages

    foreach r [mcp21.report_packages] {
        set package [lindex $r 0]
	# skip mcp, because we don't want to tell the server which
	# version of mcp we support *after* having already responded
	# to an mcp startup message
	if { $package == "mcp" } { continue; }
        set min     [lindex $r 1]
        set max     [lindex $r 2]
	mcp21.server_notify mcp-negotiate-can [list [list package $package] [list min-version $min] [list max-version $max]]
    }

    # finish negotiation
    mcp21.server_notify mcp-negotiate-end
}

# examine the registry and work out the min/max version for each
# supported package

proc mcp21.report_packages {} {
    global mcp21_registry
    foreach r $mcp21_registry {
        set package [lindex $r 0]
        set version [lindex $r 1]
	if { [info exists min($package)] == 1 } {
	    if { $version > $max($package) } {
		set max($package) $version
	    } elseif { $version < $min($package) } {
		set min($package) $version
	    }
	} {
	    set min($package) $version
	    set max($package) $version
	}
    }
    set report {}
    foreach p [array names min] {
	lappend report [list $p $min($p) $max($p)]
    }
    return $report
}

# ditto for the server's reported packages
proc mcp21.report_server_packages {} {
    global mcp21_server_registry
    return $mcp21_server_registry
}

proc mcp21.calculate_overlap {} {
    global mcp21_report_overlap
    set us   [mcp21.report_packages]
    set them [mcp21.report_server_packages]
    set report {}
    foreach p $us {
	set package [lindex $p 0]
	set s [util.assoc $them $package]
	if { $s != {} } {
	    set cmin [lindex $p 1]
	    set cmax [lindex $p 2]
	    set smin [lindex $s 1]
	    set smax [lindex $s 2]
	    if { ($cmax >= $smin) && ($smax >= $cmin) } {
		lappend report [list $package [mcp21.minimum $smax $cmax]]
	    }
	}
    }
    set mcp21_report_overlap $report
}

proc mcp21.report_overlap {} {
    global mcp21_report_overlap
    return $mcp21_report_overlap
}

proc mcp21.minimum { a b } {
    if { $a < $b } {
	return $a
    } {
	return $b
    }
}

# make a record of what the server can do
proc mcp21.do_mcp_negotiate_can {} {
    global mcp21_server_registry
    set package [request.get current package]
    set min_version [request.get current min-version]
    set max_version [request.get current max-version]
    lappend mcp21_server_registry [list $package $min_version $max_version]
}

proc mcp21.do_mcp_negotiate_end {} {
    mcp21.calculate_overlap
    mcp21.dispatch_internal mcp_negotiate_end
}

proc mcp21.do_* {} {
    # find the _data-tag value and the field
    set tag [request.get current _data-tag]
    set field [request.get current field]
    set value [request.get current value]
    set new [concat [request.get $tag $field] [list $value]]  
    request.set $tag $field $new
}
proc mcp21.do_: {} {
    set tag [request.get current _data-tag]
    set message [request.get $tag _message]
    mcp21.dispatch $message
    # clean up
    request.destroy $tag
}

# CORDS

proc mcp21.do_mcp_cord_open {} {
    global cord_db
    set id [request.get current _id]
    set type [request.get current _type]
    set cord_db($id:type) $type
}

proc mcp21.do_mcp_cord {} {
    global cord_db
    set id [request.get current _id]
    set message [request.get current _message]
    # dispatch on the message value
    set msg [request.get current _message]
    # deal with null messages...
    set full_message $cord_db($id:type)
    if { $msg != "" } {
	append full_message "-$msg"
    }
    mcp21.dispatch $full_message
}

proc mcp21.do_mcp_cord_closed {} {
    global cord_db
    set id [request.get current _id]
    unset cord_db($id:type)
}

# open a cord to the server, return "" if error or this connection
# doesn't support cords, otherwise return the cord id
proc cord.open type {
    global cord_db
    # WP is broken, sending 'R...' tag when it should send 'I...' tags!
    set id [util.unique_id R]
    # do we know about cords?
    set overlap [mcp21.report_overlap]
    set version [util.assoc $overlap mcp-cord]
    if { ($version == {}) || ([lindex $version 1] != 1.0) } {
	# nope!
	return ""
    }
    mcp21.server_notify mcp-cord-open [list [list _id $id] [list _type $type]]
    set cord_db($id:type) $type
    return $id
}

proc cord.send {id message keyvals} {
    lappend keyvals [list _id $id]
    lappend keyvals [list _message $message]
    mcp21.server_notify mcp-cord $keyvals
}

proc cord.close id {
    global cord_db
    mcp21.server_notify mcp-cord-close [list [list _id $id]]
    unset cord_db($id:type)
}
