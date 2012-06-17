#
#       tkMOO
#       ~/.tkMOO-light/plugins/rehash.tcl
#

# tkMOO-light is Copyright (c) Andrew Wilson 1994,1995,1996,1997,1998,
#                                            1999,2000,2001
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

# maintain a list of likely commands and underline them if you type
# one of them as the first word in the input window.
# implements dns-com-awns-rehash/1.0

# macro behaviour controlled by 'Use Rehash Macros' checkbox in
# the Special Forces category of the Preferences Editor.
# when checked 'On' typed text is sent through macros.  if the
# first word on the line matched a known command (eg 'look') then
# hitting return sends the command to the server.  If the first word
# on the line doesn't match a known command then the whole line is
# sent prefixed by 'say'.

client.register rehash start 60
client.register rehash client_connected
client.register rehash client_disconnected

proc rehash.start {} {
    global rehash_commands_unexpanded
    set rehash_commands_unexpanded ""
    .input tag configure rehash_COMMAND -underline 1

    # other plugins, like spell.tcl trap this event, use '+' to
    # add our handler instead of just cancelling any previously
    # defined handlers
    bind .input <KeyRelease> +rehash.handle_keyrelease

    edittriggers.register_alias rehash.set_commands rehash.set_commands
    edittriggers.register_alias rehash.commands rehash.commands
    edittriggers.register_alias rehash.add_commands rehash.add_commands
    edittriggers.register_alias rehash.remove_commands rehash.remove_commands

    mcp21.register dns-com-awns-rehash 1.0 \
        dns-com-awns-rehash-commands rehash.do_dns_com_awns_rehash_commands
    mcp21.register dns-com-awns-rehash 1.0 \
        dns-com-awns-rehash-add rehash.do_dns_com_awns_rehash_add
    mcp21.register dns-com-awns-rehash 1.0 \
        dns-com-awns-rehash-remove rehash.do_dns_com_awns_rehash_remove
    mcp21.register_internal rehash mcp_negotiate_end

    edittriggers.macro \
         -priority 60 \
         -directive UseRehashMacros \
         -nocase \
         -regexp {^\\(.*)} \
         -command {
             # send everything after the '\' verbatim
             io.outgoing "$m1"
         }
  
    edittriggers.macro \
        -regexp {^(.)([^ ]*)(.*)$} \
        -nocase \
        -directive UseRehashMacros \
        -command {
            set commands [rehash.commands] 
            if { ($commands != {}) &&
                 ([lsearch -exact {\" \: \@ \` \; \' \! \| \- \.} $m1] == -1) &&
                 ([lsearch -exact $commands $m1$m2] == -1) } {
                io.outgoing "say $m1$m2$m3"
            } {
                io.outgoing "$m1$m2$m3"
            }
        }

    preferences.register rehash {Special Forces} {
        { {directive UseRehashMacros}
            {type boolean}
            {default Off}
            {display "Use Rehash Macros"} }
    } 
    rehash.zero_task
    rehash.set_cache_marks {} {} {}
}

proc rehash.zero_task {} {
    global rehash_task
    set rehash_task 0
}

proc rehash.mcp_negotiate_end {} {
    # wait till the mcp negotiation phase is over then request a refresh.
    # client does this because the package can't tell when a
    # reconnection takes place, whereas we want both reconnection
    # and connection to cause a refresh.  JHCore may be extended
    # to allow the FOs to detect player reconnection and so inform
    # the packages, but I'm not going to wait...
    set overlap [mcp21.report_overlap]
    set version [util.assoc $overlap dns-com-awns-rehash]
    if { ($version != {}) && ([lindex $version 1] == 1.0) } {
        mcp21.server_notify dns-com-awns-rehash-getcommands
    }
}

proc rehash.do_dns_com_awns_rehash_commands {} {
    rehash.set_commands [request.get current list]
    rehash.set_cache_marks {} {} {}
    rehash.do_marks
}
proc rehash.do_dns_com_awns_rehash_add {} {
    rehash.add_commands [request.get current list]
    rehash.set_cache_marks {} {} {}
    rehash.do_marks
}
proc rehash.do_dns_com_awns_rehash_remove {} {
    rehash.remove_commands [request.get current list]
    rehash.set_cache_marks {} {} {}
    rehash.do_marks
}

proc rehash.client_connected {} {
    rehash.set_commands {}
    rehash.set_cache_marks {} {} {}
    rehash.do_marks
    return [modules.module_deferred]
}

proc rehash.client_disconnected {} {
    rehash.set_commands {}
    rehash.set_cache_marks {} {} {}
    rehash.do_marks
    return [modules.module_deferred]
}

proc rehash.handle_keyrelease {} {
    global rehash_task
    if { $rehash_task != 0 } {
	after cancel $rehash_task
    }
    set rehash_task [after 250 {rehash.do_marks;rehash.zero_task}]
}

proc rehash.set_cache_marks {word from to} {
    global rehash_db
    set rehash_db(word) $word
    set rehash_db(from) $from
    set rehash_db(to) $to
}

proc rehash.get_cache_marks {} {
    global rehash_db
    return [list $rehash_db(word) $rehash_db(from) $rehash_db(to)]
}

proc rehash.do_marks {} {
    # trim leading whitespace, and drop the trailing \n
    set text [.input get 1.0 {end - 1 char}]

    # can't use 'set first [lindex $text 0]' because $text could
    # start with '"' which causes an 'unmatched quote in list' error
    # only whitespace (space, tab) terminates words.

    if { ! [regexp {^([ 	]*)([^ 	]*)} $text _ whitespace first] } {
	set first $text
	set whitespace {}
    }

    set original "$whitespace$first"

    # expand the list
    foreach {word from to} [rehash.get_cache_marks] { break }

    rehash.unmark_words .input

    if { $first != {} && $original == $word } {
        .input tag add rehash_COMMAND $from $to
	return
    }

    set commands [rehash.commands]
    if { ($first != {}) &&
	 ([lsearch -exact $commands $first] != -1) } {
	 set beginning [.input search -forwards $first 1.0 end]
	 if { $beginning != "" } {
	     set ending [.input index "$beginning + [expr [string length $first]] chars"]
	     .input tag add rehash_COMMAND $beginning $ending
	     rehash.set_cache_marks $original $beginning $ending
	 }
    }
}

proc rehash.unmark_words w {
    $w tag remove rehash_COMMAND 1.0 end
}

# set the list of known commands, expand stuff like 'l*ook' to 'l'
# 'lo' 'loo' 'look'
proc rehash.set_commands commands {
    global rehash_commands_unexpanded
    set rehash_commands_unexpanded $commands
}

proc rehash.expand_commands commands {
    set expanded [list]
    foreach c [lrange $commands 0 end] {
        if { [set first [string first "*" $c]] != -1 } {
            set pre [string range $c 0 [expr $first - 1]]
            set post [string range $c [expr $first + 1] end]
            lappend expanded $pre
            foreach p [split $post {}] {
                append pre $p
                lappend expanded $pre
            }
        } {
            lappend expanded $c
        }
    }
    return $expanded
}

proc rehash.add_commands commands {
    global rehash_commands_unexpanded
    set rehash_commands_unexpanded [concat $rehash_commands_unexpanded $commands]
}

proc rehash.remove_commands commands {
    global rehash_commands_unexpanded
    foreach c $commands {
        if { [set psn [lsearch -exact $rehash_commands_unexpanded $c]] != -1 } {
            set rehash_commands_unexpanded [lreplace $rehash_commands_unexpanded $psn $psn]
        }
    }
}

proc rehash.commands {} {
    global rehash_commands_unexpanded
    return [rehash.expand_commands $rehash_commands_unexpanded]
}

proc rehash.commands_unexpanded {} {
    global rehash_commands_unexpanded
    return $rehash_commands_unexpanded
}
