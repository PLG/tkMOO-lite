# tkMOO-light is Copyright (c) Andrew Wilson 1994,1995,1996,1997,1998,
#                                            1999,2000,2001
# 
# 	All Rights Reserved
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

set tkmooVersion "0.4-PLGd"
set tkmooBuildTime "Sun Jun 17 16:00:54 CEST 2012"

#if { $tcl_platform(platform) == "macintosh" } {
#    catch { console hide }
#}

if {[info tclversion] < 8.5} {
    puts stderr "This application requires Tcl 8.5 or better.  This is only Tcl [info tclversion]"
    exit 1
}
if {[regexp {7\.5(a|b).} [info patchlevel]]} {
    puts stderr "This application will not work with a Tcl alpha or beta release"
    exit 1
}
if {![info exists tk_version]} {
    puts stderr "This application requires Tk"
    exit 1
}
if {$tk_version < 4.1} {
    puts stderr "This application requires Tk 4.1 or better.  This is only Tk $tk_version"
    exit 1
}
if {[regexp {4\.1(a|b).} $tk_patchLevel]} {
    puts stderr "This application will not work with a Tk alpha or beta release"
    exit 1
}

#
#

proc db.set { id field val args } {
    global db
    if { $args == {} } {
        set db($id:$field) $val
    } {
        eval db.set $db($id:$field) [concat [list $val] $args]
    }
}

proc db.unset { id field val args } {
    global db
    if { $args == {} } {
        unset -nocomplain db($id:$field) $val
    } {
        eval db.unset $db($id:$field) [concat [list $val] $args]
    }
}

proc db.get { id field args } {
    global db
    if { $args == {} } {
        return $db($id:$field)
    } {
        return [eval db.get $db($id:$field) $args]
    }
}

proc db.drop object {
    global db
    foreach name [array names db "$object:*"] {
        unset db($name)
    }
}

proc db.exists { id field args } {
    global db
    if { $args == {} } {
        return [info exists db($id:$field)]
    } {
        return [eval db.exists $db($id:$field) $args]
    }
}
#
#

proc client.new_session {} {
    set session [util.unique_id session]
    return $session
}
proc client.destroy_session session {
    db.drop $session
}

proc client.dev {} {
    global tkmooVersion
    return [string match {*-dev*} $tkmooVersion]
}

proc client.host_unreachable { host port } {
    window.displayCR "Server at $host $port is unreachable." window_highlight
}

set client_event_callbacks_x(start) {}
set client_event_callbacks_x(stop) {}
set client_event_callbacks_x(client_connected) {}
set client_event_callbacks_x(client_disconnected) {}
set client_event_callbacks_x(incoming) {}
set client_event_callbacks_x(incoming_2) {}
set client_event_callbacks_x(outgoing) {}
set client_event_callbacks_x(reconfigure_fonts) {}

proc client.register {plugin event {priority 50}} {
    global client_event_callbacks_x
    lappend client_event_callbacks_x($event) [list $plugin $priority [llength $client_event_callbacks_x($event)]]

    global client_plugin_location
    if { [info procs plugin.plugin_location] != {} } {
    set client_plugin_location($plugin) [plugin.plugin_location]
    } {
    set client_plugin_location($plugin) INTERNAL
    }
}

proc client.plugin_location plugin {
    global client_plugin_location
    if { [info exists client_plugin_location($plugin)] } {
        return $client_plugin_location($plugin)
    } {
        return INTERNAL
    }
}

proc client.plugins {} {
    global client_event_callbacks_x
    foreach event [array names client_event_callbacks_x] {
        foreach record $client_event_callbacks_x($event) {
            set plugin [lindex $record 0]
            set uniq($plugin) 1
        }
    }
    return [lsort [array names uniq]]
}


proc client.sort_registry {} {
    global client_event_callbacks client_event_callbacks_x
    
    foreach event [array names client_event_callbacks_x] {
	set tmp $client_event_callbacks_x($event)
	set client_event_callbacks($event) [util.slice [lsort -increasing -command client.compare_priority $tmp]]
    }
}

proc client.compare_priority { a b } {
    set rv [expr int( [lindex $a 1] - [lindex $b 1] )]
    if { $rv == 0 } { 
	set rv [expr int( [lindex $a 2] - [lindex $b 2] )]
    }
    return $rv
}



proc client.reconfigure_fonts {} {
    window.reconfigure_fonts
    modules.reconfigure_fonts
}

proc client.client_connected_session session {
    db.set current session $session

    window.client_connected
    modules.client_connected

    set ce [worlds.get_generic [colourdb.get red] colourlocalecho ColourLocalEcho ColourLocalEcho]
    if { $ce != "" } {
        .output tag configure client_echo -foreground $ce
    }
}

proc client.client_connected {} {
    window.client_connected
    modules.client_connected

    set ce [worlds.get_generic [colourdb.get red] colourlocalecho ColourLocalEcho ColourLocalEcho]
    if { $ce != "" } {
        .output tag configure client_echo -foreground $ce
    }
}

proc client.client_disconnected_session session {
    window.client_disconnected
    modules.client_disconnected

    db.set current session ""
    worlds.set_current ""
    client.destroy_session $session
}

proc client.client_disconnected {} {
    window.client_disconnected
    modules.client_disconnected

    set session UNKNOWN_SESSION
    worlds.set_current ""
    client.destroy_session $session
}


proc client.incoming-character event {
    global modules_module_deferred
    if { [modules.incoming $event] == $modules_module_deferred } {
	if { [io.noCR] == 1 } {
            window.display [db.get $event line]
	} {
            window.displayCR [db.get $event line]
	}
    }
}

proc client.incoming-line event {
    global modules_module_deferred
    window.clear_tagging_info
    if { [modules.incoming $event] == $modules_module_deferred } {
         set line [db.get $event line]
         window.displayCR $line
         window.assert_tagging_info $line
    }
}

proc client.incoming event {
    global client_mode
    client.incoming-$client_mode $event
    modules.incoming_2 $event
    db.drop $event
}

proc client.outgoing line {
    global modules_module_deferred client_echo
    if { [modules.outgoing $line] == $modules_module_deferred } {
        io.outgoing $line
    }
    if { $client_echo == 1 } {
        window.displayCR $line client_echo
    }
}

proc client.set_incoming_line line {
    global client_incoming_line
    set client_incoming_line $line
}
proc client.get_incoming_line {} {
    global client_incoming_line
    return $client_incoming_line
}

proc client.default_mode {} {
    return line
}

proc client.mode {} {
    global client_mode
    return $client_mode
}

proc client.set_mode mode {
    global client_mode
    set client_mode $mode
}

proc client.start {} {
    global client_echo

    client.sort_registry

    .output tag configure client_echo -foreground [colourdb.get red]
    set client_echo 1

    client.set_mode [client.default_mode]

    modules.start
    client.update
    io.start
    default.default
    client.default_settings
}

proc client.stop {} {
    modules.stop
    set session ""
    catch {
	set session [db.get current session]
    }
    io.stop_session $session
}

proc client.connect { host port } {
    client.set_mode [client.default_mode]

    set session [client.new_session]
    db.set $session host $host
    db.set $session port $port
    db.set .output session $session

    io.connect_session $session
}

proc client.do_login_from_dialog {} {
    set uid [.login.u.e get]
    set pwd [.login.p.e get]
    if { $uid != "" } {
        client.complete_connection [worlds.get_current] $uid $pwd
        client.default_settings
    }
    destroy .login
}

proc client.login_dialog { uid pwd } {
    set l .login
    catch { destroy $l }
    toplevel $l

    window.configure_for_macintosh $l

    window.bind_escape_to_destroy $l

    window.place_nice $l
    window.focus $l

    grab $l
    focus $l
    set name [worlds.get [worlds.get_current] Name]
    wm title $l "Login to $name"
    wm iconname $l "Login to $name"
    frame $l.u
	label $l.u.l -text "User:"
	entry $l.u.e -background [colourdb.get pink]
	$l.u.e insert 0 $uid
	pack $l.u.l -side left
	pack $l.u.e -side right
    frame $l.p
	label $l.p.l -text "Password:"
	entry $l.p.e -show "*" -background [colourdb.get pink]
	$l.p.e insert 0 $pwd
	pack $l.p.l -side left
	pack $l.p.e -side right
    frame $l.c
	button $l.c.l -text "Login" \
	    -command "client.do_login_from_dialog"
	button $l.c.c -text "Cancel" -command "destroy $l"
	pack $l.c.l $l.c.c -side left \
	    -padx 5 -pady 5

    bind $l <Return> { client.do_login_from_dialog };

    pack $l.u -side top -fill x
    pack $l.p -side top -fill x
    pack $l.c -side bottom
    window.focus $l.u.e
}

proc client.default_settings {} {
    global window_binding window_fonts client_echo

    set font(proportional) plain
    set font(fixedwidth)   fixedwidth
    set font(default)      $font(fixedwidth)

    set which [worlds.get_generic default {} {} DefaultFont]

    .output configure -font [fonts.$font($which)]
    if { $which == "default" } { 
        set window_fonts fixedwidth
    } {
        set window_fonts $which
    }

    client.set_bindings
 
    set echo [worlds.get_generic on {} {} LocalEcho]
    if { [string tolower $echo] == "on" } {
    	client.set_echo 1
    } {
    	client.set_echo 0
    }
}

proc client.set_echo echo {
    global client_echo
    set client_echo $echo
}

proc client.set_bindings {} {
    bindings.default 
        
    set which [worlds.get_generic default {} {} KeyBindings]
    
    bindings.set $which
    set window_binding $which
}

proc client.connect_world world {
    global window_binding window_fonts tcl_platform client_echo


    set session [client.new_session]
    db.set $session world $world
    db.set .output session $session

    set mode [worlds.get_generic [client.default_mode] {} {} ClientMode]

    client.set_mode $mode

    set kludge_world [worlds.get_current]




    worlds.set_current $world

    set host ""
    set port ""
    catch { set host [worlds.get $world Host] }
    catch { set port [worlds.get $world Port] }

    if { ($host == "") || ($port == "") } {
        window.displayCR "Host or Port not defined for this World" window_highlight
	return
    }

    db.set $session host $host
    db.set $session port $port

    if { [io.connect_session $session] == 1 } {
	worlds.set_current $kludge_world
	return
    }


    worlds.set_current $world

    set uid ""
    set pwd ""
    catch {set uid [worlds.get $world Login]}
    catch {set pwd [worlds.get $world Password]}

    set use [worlds.get_generic On {} {} UseLoginDialog]

    if { ($uid == "") && ($pwd == "") && ([string tolower $use] == "on") } {
        client.login_dialog $uid $pwd
	return
    }

    client.complete_connection $world $uid $pwd

    client.default_settings
}

proc client.complete_connection { world uid pwd } {
    set cscript [worlds.get_generic "connect %u %p" {} {} ConnectScript $world]

    regsub -all {\%u} $cscript [client.protect_regsub $uid] cscript
    regsub -all {\%p} $cscript [client.protect_regsub $pwd] cscript


    if { $cscript == "" } {
    } {


	regsub "\n\$" $cscript {} cscript


        io.outgoing $cscript
    }
}

proc client.protect_regsub str {
    regsub -all -- {&} $str {\\&} str
    return $str
}

proc client.disconnect_session session {
    set dscript ""
    catch { set dscript [worlds.get [worlds.get_current] DisconnectScript] }
    if { $dscript != "" } {
        io.outgoing $dscript
    }
    io.disconnect_session $session
}

proc client.disconnect {} {
    set dscript ""
    catch { set dscript [worlds.get [worlds.get_current] DisconnectScript] }
    if { $dscript != "" } {
        io.outgoing $dscript
    }
    io.disconnect
}


proc client.update {} {
    update idletasks
    after 500 client.update
}

proc client.exit {} {
    client.stop
    #
    #
    #
    #
    #
    global tcl_platform
    if { $tcl_platform(platform) == "macintosh" } {
        after 1500 destroy .
    } {
	destroy .
    }


    global tcl_platform
    if { $tcl_platform(platform) == "windows" } {
        exit
    }
}
#
#

set modules_module_deferred 0
set modules_module_ok 1

proc modules.module_deferred {} {
    global modules_module_deferred
    return $modules_module_deferred
}

proc modules.module_ok {} {
    global modules_module_ok
    return $modules_module_ok
}

proc modules.debug {} {
    set debug [worlds.get_generic Off {} {} ModulesDebug]
    if { [string tolower $debug] == "on" } {
        return 1
    }
    return 0
}

proc modules.reconfigure_fonts {} {
    global client_event_callbacks
    foreach module $client_event_callbacks(reconfigure_fonts) {
        if { [catch $module.reconfigure_fonts rv] && [modules.debug] } {
            window.displayCR "Internal Error in $module.reconfigure_fonts: $rv" window_highlight
        }
    }
}

proc modules.start {} {
    global client_event_callbacks
    foreach module $client_event_callbacks(start) {
        if { [catch $module.start rv] && [modules.debug] } {
            window.displayCR "Internal Error in $module.start: $rv" window_highlight
        }
    }
}

proc modules.stop {} {
    global client_event_callbacks
    foreach module $client_event_callbacks(stop) {
        if { [catch $module.stop rv] && [modules.debug] } {
            window.displayCR "Internal Error in $module.stop: $rv" window_highlight
        }
    }
}

proc modules.incoming_2 event {
    global modules_module_ok modules_module_deferred \
	   client_event_callbacks

    foreach module $client_event_callbacks(incoming_2) {
        if { [catch { $module.incoming_2 $event } rv] && [modules.debug] } {
            window.displayCR "Internal Error in $module.incoming_2: $rv" window_highlight
        } {
            if { $rv == $modules_module_ok } {
                return $rv
            }
        }
    }

    return $modules_module_deferred
}

proc modules.incoming event {
    global modules_module_ok modules_module_deferred \
	   client_event_callbacks

    foreach module $client_event_callbacks(incoming) {
        if { [catch { $module.incoming $event } rv] && [modules.debug] } {
            window.displayCR "Internal Error in $module.incoming: $rv" window_highlight
        } {
            if { $rv == $modules_module_ok } {
                return $rv
	    }
        }
    }

    return $modules_module_deferred
}

proc modules.outgoing line {
    global modules_module_ok modules_module_deferred \
	   client_event_callbacks

    foreach module $client_event_callbacks(outgoing) {
        if { [catch { $module.outgoing $line } rv] && [modules.debug] } {
            window.displayCR "Internal Error in $module.outgoing: $rv" window_highlight
        } {
            if { $rv == $modules_module_ok } {
                return $rv
            }
        }
    }

    return $modules_module_deferred
}

proc modules.client_connected {} {
    global modules_module_ok modules_module_deferred \
	   client_event_callbacks

    foreach module $client_event_callbacks(client_connected) {
        if { [catch $module.client_connected rv] && [modules.debug] } {
            window.displayCR "Internal Error in $module.client_connected: $rv" window_highlight
        } {
            if { $rv == $modules_module_ok } {
                return $rv
            }
        }
    }
    return $modules_module_deferred
}

proc modules.client_disconnected {} {
    global modules_module_ok modules_module_deferred \
	   client_event_callbacks

    foreach module $client_event_callbacks(client_disconnected) {
        if { [catch $module.client_disconnected rv] && [modules.debug] } {
            window.displayCR "Internal Error in $module.client_disconnected: $rv" window_highlight
        } {
            if { $rv == $modules_module_ok } {
                return $rv
            }
        }
    }
    return $modules_module_deferred
}
#

#PLG keysym is CASE SENSITIVE!!!! So Control-O and Control-o are not the same!
# http://www.tcl.tk/man/tcl/TkCmd/bind.htm
# Cmd is NOT a binding!!!
# 

# cool thing about testing here is that you get an immediate script error is it is wrong =)
# bind . <Command-o> { puts "Blah!" }

proc bindings.bindings {} {
    return [list emacs tf windows mac default]
}

proc bindings.default {} {
    global bindings_db window_binding
    foreach binding [array names bindings_db] {
		if { [regexp {^(.*):default:(.*)} $binding _ widget event] == 1 } {
		    catch { bind $widget $event $bindings_db($binding) }
		}
    }
    set window_binding default
}


proc bindings.set emulate {
    global bindings_db window_binding
    bindings.default
    if { $emulate == "default" } {
		return
    }

    foreach binding [array names bindings_db] {
	if { [regexp {^(.*):(.*):(.*)} $binding _ widget emul event] == 1 } {
		    if { ($emulate == $emul) } {
		        set bindings_db($widget:default:$event) [bind $widget $event]
		        catch { bind $widget $event $bindings_db($binding) }
		    }
		}
    }
    set window_binding $emulate
}

###
#

set bindings_db(Text:emacs:<Left>) 		{ ui.left_char %W }
set bindings_db(Text:emacs:<Right>) 		{ ui.right_char %W }
set bindings_db(Text:emacs:<Down>) 		{ ui.down_line %W }
set bindings_db(Text:emacs:<Up>) 		{ ui.up_line %W }
set bindings_db(Text:emacs:<Control-b>) 	{ ui.left_char %W } 
set bindings_db(Text:emacs:<Control-f>) 	{ ui.right_char %W }
set bindings_db(Text:emacs:<Control-n>) 	{ ui.down_line %W }
set bindings_db(Text:emacs:<Control-p>) 	{ ui.up_line %W }
set bindings_db(Text:emacs:<Control-a>) 	{ ui.start_line %W }
set bindings_db(Text:emacs:<Control-e>) 	{ ui.end_line %W }
set bindings_db(Text:emacs:<Control-v>) 	{ ui.page_down %W }

set bindings_db(Text:emacs:<Alt-w>) 		{ ui.copy_selection %W }
set bindings_db(Text:emacs:<Control-y>) 	{ ui.paste_selection %W }
set bindings_db(Text:emacs:<Control-w>) 	{ ui.delete_selection %W }
set bindings_db(Entry:emacs:<Alt-w>) 		{ ui.copy_selection %W }
set bindings_db(Entry:emacs:<Control-y>) 	{ ui.paste_selection %W }
set bindings_db(Entry:emacs:<Control-w>) 	{ ui.delete_selection %W }
set bindings_db(.output:emacs:<Control-y>) 	{ ui.paste_selection .input; focus .input }

set bindings_db(Text:emacs:<Escape>v) 		{ ui.page_up %W }

set bindings_db(Text:tf:<Control-b>) 	{ ui.left_word_start %W }
set bindings_db(Text:tf:<Control-f>) 	{ ui.right_word_start %W }
set bindings_db(Text:tf:<Control-u>) 	{ ui.delete_line %W }
set bindings_db(Text:tf:<Control-k>) 	{ ui.delete_to_end %W }
set bindings_db(Text:tf:<Control-d>) 	{ ui.delete_char_right %W }
set bindings_db(Text:tf:<Escape>k) 	{ ui.delete_to_beginning %W }
set bindings_db(Entry:tf:<Control-b>) 	{ ui.left_word_start_entry %W }
set bindings_db(Entry:tf:<Control-f>) 	{ ui.right_word_start_entry %W }
set bindings_db(Entry:tf:<Control-u>) 	{ ui.delete_line_entry %W }
set bindings_db(Entry:tf:<Control-k>) 	{ ui.delete_to_end_entry %W }
set bindings_db(Entry:tf:<Escape>k) 	{ ui.delete_to_beginning_entry %W }
set bindings_db(.input:tf:<Control-l>) 	{ ui.clear_screen .output }
set bindings_db(.input:tf:<Up>)		{ ui.up_line %W }
set bindings_db(.input:tf:<Down>)	{ ui.down_line %W }


set bindings_db(Text:windows:<Control-c>) 	{ ui.copy_selection %W }
set bindings_db(Text:windows:<Control-v>) 	{ ui.paste_selection %W }
set bindings_db(Text:windows:<Control-x>) 	{ ui.delete_selection %W }

set bindings_db(Entry:windows:<Control-c>) 	{ ui.copy_selection %W }
set bindings_db(Entry:windows:<Control-v>) 	{ ui.paste_selection %W }
set bindings_db(Entry:windows:<Control-x>) 	{ ui.delete_selection %W }
set bindings_db(.input:windows:<Alt-n>) 	{ wm iconify . }

set bindings_db(.input:windows:<Control-Home>) { ui.page_top .output }
set bindings_db(.input:windows:<Control-End>) { ui.page_end .output }

# set bindings_db(Text:mac:<Command-c>)	{ ui.copy_selection %W }
# set bindings_db(Text:mac:<Command-v>)	{ ui.paste_selection %W }
# set bindings_db(Text:mac:<Command-x>)	{ ui.delete_selection %W }

set bindings_db(Text:mac:<Command-a>) [bind Text <Control-slash>]
set bindings_db(Entry:mac:<Command-a>) [bind Entry <Control-slash>]

set bindings_db(.input:mac:<Command-Home>) { ui.page_top .output }
set bindings_db(.input:mac:<Command-End>) { ui.page_end .output }

set bindings_db(.input:default:<Tab>) { window.dabbrev; break }

set bindings_db(.input:default:<ISO_Left_Tab>) { window.dabbrev backward; break }

set bindings_db(.input:default:<Shift-Tab>) { window.dabbrev backward; break }
set bindings_db(.input:default:<Key>) {+
    if { ![string match "*Shift*" "%K"] &&
         ![string match "*Tab*" "%K"] &&
         ![string match "*Control*" "%K"] &&
         ![string match "*Command*" "%K"] &&
         ![string match "*Escape*" "%K"]
         } {
        window.set_dabbrev_target {}
    }
}

set bindings_db(.input:default:<Return>)    { window.ui_input_return }
set bindings_db(.input:default:<Control-p>) { window.ui_input_up }
set bindings_db(.input:default:<Control-n>) { window.ui_input_down }
set bindings_db(.input:default:<Up>)        { window.ui_input_up }
set bindings_db(.input:default:<Down>)      { window.ui_input_down }
set bindings_db(.input:default:<Next>) 	    { ui.page_down .output }
set bindings_db(.input:default:<Prior>)     { ui.page_up .output }

set bindings_db(.input:default:<MouseWheel>) {
    .output yview scroll [expr - (%D / 120) * 4] units
}

set bindings_db(.input:default:<Button-5>) { .output yview scroll 4 units }
set bindings_db(.output:default:<Button-5>) { .output yview scroll 4 units }
set bindings_db(.input:default:<Button-4>) { .output yview scroll -4 units }
set bindings_db(.output:default:<Button-4>) { .output yview scroll -4 units }

set bindings_db(.input:default:<Shift-Return>)     { tkTextInsert .input "\n"; break }
set bindings_db(.input:default:<Control-Up>)     "[bind Text <Up>]; break"
set bindings_db(.input:default:<Control-Down>)     "[bind Text <Down>]; break"


if {$tcl_platform(os) == "Darwin"} {
    set modifier Command
} elseif {$tcl_platform(platform) == "windows"} {
    set modifier Control
} else {
    set modifier Meta
}

# if { ($tcl_platform(os) == "Darwin") || ($tcl_platform(platform) == "windows") } {
if { ($tcl_platform(os) == "Darwin") } {

    # set modifier(macintosh) Command
    # set modifier(windows) Control

    # set bindings_db(.output:default:<$modifier($tcl_platform(platform))-v>) { ui.paste_selection .input;  focus .input }
    set bindings_db(.output:default:<Command-v>) { ui.paste_selection .input;  focus .input }

    set bindings_db(.output:default:<1>)	{ focus .output }
    set bindings_db(.output:default:<Button1-ButtonRelease>) {
        set sel ""
        catch { set sel [selection get -displayof .output] }
        if { "x$sel" == "x" } {
            focus .input
        }
    }
}

#
#

proc default.default {} {
    set menu .menu.prefs
    $menu.fonts invoke "fixedwidth"
    # $menu.bindings invoke "mac"
}

proc default.options {} {
    global tcl_platform
    option add *Text.background #f0f0f0 userDefault
    option add *Entry.background #d3b6b6 userDefault
    option add *desktopBackground #d9d9d9 userDefault
    option add *BorderWidth 1 userDefault

    #PLG:TODO    
    # if { $tcl_platform(platform) == "macintosh" } {
    #     option add *Text.insertWidth 2 userDefault
    #     option add *Entry.insertWidth 2 userDefault
    # }
    # if { $tcl_platform(platform) == "macintosh" } {
    #     option add *Frame.background #cccccc userDefault
    #     option add *Label.background #cccccc userDefault
    #     option add *Toplevel.background #cccccc userDefault
    #     option add *Checkbutton.background #cccccc userDefault
    #     option add *Radiobutton.background #cccccc userDefault
    #     option add *Menubutton.background #cccccc userDefault
    #     option add *Scale.background #cccccc userDefault
    #     option add *Text.highlightbackground #cccccc userDefault
    # }
}
#
#

proc history.drop id {
    global history_db
    foreach key [array names history_db "$id:"] {
	unset history_db($key)
    }
}

proc history.init { id {fixed 1} } {
    global history_db
    set history_db($id:history) {}
    set history_db($id:index) 0
    set history_db($id:fixed) $fixed
}

proc history.add { id line } {
    global history_db
    if { $line != "" } {
	lappend history_db($id:history) $line
    }
    if { [llength $history_db($id:history)] > 20 } {
	set history_db($id:history) [lrange $history_db($id:history) 1 end]
    }
    set history_db($id:index) [llength $history_db($id:history)]
}

proc history.next id {
    global history_db
    if { $history_db($id:history) == {} } {
	return ""
    }
    incr history_db($id:index)
    if { $history_db($id:index) > [llength $history_db($id:history)] } {
	if { $history_db($id:fixed) == 1 } {
	    set history_db($id:index) [llength $history_db($id:history)]
	} {
	    set history_db($id:index) 0
	}
    }
    return [lindex $history_db($id:history) $history_db($id:index)]
}

proc history.prev id {
    global history_db
    if { $history_db($id:history) == {} } {
	return ""
    }
    incr history_db($id:index) -1
    if { $history_db($id:index) < 0 } {
	if { $history_db($id:fixed) == 1 } {
	    set history_db($id:index) 0
	} {
	    set history_db($id:index) [llength $history_db($id:history)] 
	}
    }
    return [lindex $history_db($id:history) $history_db($id:index)]
}
#
#

set help_subject_list {
    Starting
    Preferences
    Worlds
    Resources
    CommandLine
    Plugins
    SEPARATOR
    About
    LICENCE
}

proc help.text subject {
    global help_subject
    if { [info exists help_subject($subject)] } {
        return $help_subject($subject)
    } elseif { [info procs help.text_$subject] != {} } {
        return [help.text_$subject]
    } {
        return $help_subject(NoHelpAvailable)
    }
}

proc help.show subject {
    global help_subject help_history help_index help_CR
    set h .help
    if { [winfo exists $h] == 0 } {
    toplevel $h
    window.configure_for_macintosh $h

    window.bind_escape_to_destroy $h   

    window.place_nice $h

    $h configure -bd 0

    text $h.t -font [fonts.plain] -wrap word \
	-width 70 \
        -bd 0 -highlightthickness 0 \
        -setgrid 1 \
        -relief flat \
	-bg #fff9e1 \
	-yscrollcommand "$h.s set" \
        -cursor {}

    bind $h <Prior> "ui.page_up $h.t"
    bind $h <Next> "ui.page_down $h.t"

    scrollbar $h.s -command "$h.t yview" \
	-highlightthickness 0
    window.set_scrollbar_look $h.s

    frame $h.controls -bd 0 -highlightthickness 0
    button $h.controls.close -text "Close" -command "destroy $h" -highlightthickness 0

    pack $h.controls -side bottom
    pack $h.controls.close -side left \
	-padx 5 -pady 5

    pack $h.s -fill y -side right
    pack $h.t -expand 1 -fill both 


    $h.t tag configure help_bold 	-font [fonts.bold]
    $h.t tag configure help_italic -font [fonts.italic]
    $h.t tag configure help_fixed -font [fonts.fixedwidth]
    $h.t tag configure help_header \
	-foreground [colourdb.get darkgreen] \
	-font [fonts.header]

    } {
        $h.t configure -state normal
	$h.t delete 1.0 end
    }

    if { [util.eight] == 1 } {
        $h.t tag configure help_paragraph \
	    -lmargin1 10p -lmargin2 10p -rmargin 10p
    }

    set help_CR 0

    help.displayCR

    foreach item [help.text $subject] {
	if { [llength $item] > 1 } {
	    if { [lindex $item 0] == "preformatted" } {
		set formatted $item
		regsub {^preformatted} $item "" formatted
		help.[lindex $item 0] $formatted
	    } {
                help.[lindex $item 0] [lrange $item 1 end]	
	    }
	} {
            help.display "$item "
	}
    }

    $h.t configure -state disabled
    window.focus $h
}

proc help.displayCR { {text ""} {tags ""} } {
    global help_CR
    set h .help
    if { $help_CR == 1 } {
	$h.t insert insert "\n" help_paragraph
    }
    set help_CR 1
    $h.t insert insert $text "help_paragraph $tags"
}

proc help.display { {text ""} {tags ""} } {
    global help_CR
    set h .help
    if { $help_CR == 1 } {
	$h.t insert insert "\n" help_paragraph
    }
    set help_CR 0
    $h.t insert insert $text "help_paragraph $tags"
}

proc help.get_title subject {
    global help_subject
    foreach item [help.text $subject] {
	if { [llength $item] > 1 } {
	    if { [lindex $item 0] == "title"} {
		return [lrange $item 1 end]
	    }
	}
    }
    return $subject
}

proc help.paragraph string {
    help.displayCR
    help.displayCR
}

proc help.bold string {
    help.display "$string" help_bold
    help.display " "
}

proc help.italic string {
    help.display "$string" help_italic
    help.display " "
}

proc help.header string {
    help.displayCR "$string" help_header
    help.displayCR
}

proc help.version null {
    help.display [util.version]
}

proc help.buildtime null {
    help.display [util.buildtime]
}

proc help.title string {
    wm title .help "Help: $string"
}

proc help.preformatted string {
    help.displayCR
    help.displayCR "$string" help_fixed
}

#

proc help.link string {
    if { ([info procs webbrowser.open] != {}) && [webbrowser.is_available] } {
        set tag [util.unique_id "hl"]
        set cmd "webbrowser.open $string"
        help.display "$string" [window.hyperlink.link .help.t $tag $cmd]
        help.display " "
    } {
        help.display "$string"
        help.display " "
    }
}

proc help.subjects {} {
    global help_subject_list
    return $help_subject_list
}

###############################################################################
set help_subject(NoHelpAvailable) {
    {title No Help Avilable}
    {header No Help Available}

    No help text is available for that subject.
}

proc help.text_Plugins {} {
    set text {
    {title Installed Plugins}
    {header Installed Plugins}

    This page displays information about the plugins that have
    been installed with this client.
 
    }

    set dir_info {
    {paragraph foo}
    {header Location of Plugins Directory}
    The client will look for directories to contain plugins in the
    following order.  Only plugins in the first matching directory
    will be loaded.
    }

    if { [info procs plugin.plugins_directories] != {} } {
    set foo {}
    foreach directory [plugin.plugins_directories] {
        lappend foo "    $directory"
    }
    set foo_list [join $foo "\n"]
    set dir_info [concat $dir_info "
        \{preformatted
$foo_list
        \}
    "]
    }
    set text [concat $text $dir_info]

    if { [info procs plugin.plugins_dir] != {} } {
    set dir [plugin.plugins_dir]
    if { $dir == "" } {
        set dir "None of the above directories have been found!!"
    }
    set text [concat $text "
    The client is using the following directory as a source for plugins:
    \{preformatted
    $dir
    \}
    "]
    }

    if { [info procs plugin.plugins_dir] != {} } {

    foreach p [client.plugins] {
        if { [set location [client.plugin_location $p]] != "INTERNAL" } {
            set locations($location) 1
        }
    }

    if { [info exists locations] } {
        set names {}
        foreach name [lsort [array names locations]] {
            lappend names "    $name"
        }
        set plugins_text [join $names "\n"]
    } {
        set plugins_text "    No plugins have been found!!"
    }

    set text [concat $text "
    {header Loaded Plugins}
    The following plugins have been loaded:
    \{preformatted
$plugins_text
    \}
    "]
    }

    return $text
}

set help_subject(Resources) {
    {title Resources File}
    {header Resources File}

    When the client is started it is able to read from an optional
    resources file which contains text entries defining some of
    the client's properties, like display colours and fonts.  For
    the time being only a few colours are definable, but the number
    of configurable options will be improved in future versions of
    the client.  The following entries define the client's default
    colour scheme:

    {preformatted 
    *Text.background: #f0f0f0
    *Entry.background: #f00000
    *desktopBackground: #d9d9d9
    }

    The client looks for your resources file in the following places
    depending on which platform you're using:

    {preformatted
    Platform	Location
    UNIX 	$HOME/.tkmoolightrc
    MAC 	$env(PREF_FOLDER):tkMOO-light.RC
    WINDOWS 	$HOME\tkmoo\tkmoo.res
    }
}

set help_subject(Worlds) {
    {title The worlds.tkm File}
    {header The worlds.tkm File}

    The Worlds Definition File describes the sites that the client
    knows about listing the name, machine host name and port number
    of each site. An {bold optional} username and password can be
    given for each definition which the client will use to connect
    you to your player object. The file contains lines of text laid
    out as follows:

    {preformatted
    World:    <human readable string for the Connections Menu>
    Host:     <host name>
    Port:     <port number>
    Login:    <username>
    Password: <some password>
    ConnectScript: <lines of text to send following connection>
    ConnectScript: ...
    DisconnectScript: <lines of text to send before disconnecting>
    DisconnectScript: ...
    KeyBindings: <keystroke emulation>
    DefaultFont: <font type for main screen, fixedwith or proportional>
    LocalEcho: <On | Off>

    World:    <a different string for a different world>
    Host:     <a different host name>
    Port:     <a different port number>
    ...
    }

    The client looks for the worlds.tkm file in each of the following
    locations depending on the platform you're using, and only data
    from the {bold first} matching file is used by the client:

    {preformatted
    On UNIX		./.worlds.tkm
    			$HOME/.tkMOO-lite/.worlds.tkm
    			$tkmooLibrary/.worlds.tkm

    On Macintosh	worlds.tkm
    			$env(PREF_FOLDER):worlds.tkm
    			$tkmooLibrary:worlds.tkm

    On Windows		.\worlds.tkm
    			$HOME\tkmoo\worlds.tkm
    			$tkmooLibrary\worlds.tkm
    }
}

set help_subject(About) {
    {title About tkMOO-light}
    {header About tkMOO-light}

    Version number {version foo} , built {buildtime foo} .
    {paragraph foo}

    tkMOO-light is Copyright (c) Andrew Wilson
    1994,1995,1996,1997,1998,1999,2000,2001.  All Rights Reserved.

    {paragraph foo}

    {bold tkMOO-light} is a new client which brings mudding kicking and
    screaming into the early eighties. The client supports a rich
    graphical user interface, and can be extended to implement
    a wide range of new tools for accessing MUDs.

    {paragraph foo}

    Online documentation, programming examples, plugins and developer
    mailing lists can be found on the client's homepage:

    {paragraph foo}
    {link http://www.awns.com/tkMOO-light/}

    {paragraph foo}
    {header Technical Support for tkMOO-light}

    If you need technical support for tkMOO-light or would like to
    see some new features designed for the client then please
    contact <info@awns.com>.
}

set help_subject(Starting) {
    {title Getting Started}
    {header Getting Started}

    {bold tkMOO-light} is a powerful and flexible piece of software
    which you can customise to suit your own needs.  Don't be put off
    by the complexity and all those menu-options because getting
    started is really easy.

    {paragraph foo}
    {header Choosing a world}

    The first thing you'll need to do is choose a mud you'd like
    to visit.  tkMOO-light lets you define {bold worlds} , each of
    which details the host name and port number of a mud server as
    well as a username, a password and an optional login script.
    You can also define how the client looks when you're in that
    world.

    {paragraph foo}

    The {bold Connect->Worlds...} menu option brings up a list of
    worlds for you to choose from.  Double-clicking on one of the
    entries in the list will connect you to that world.  Notice
    how some of the worlds also appear in the drop-down menu you
    see when you select the {bold Connect} menu option.  You can
    use the {bold Preferences Editor} to add a worlds to this short
    list.

    {paragraph foo}
    {header Adding a world to the list}

    Select the {bold Connect->Worlds...} menu option and click on
    the {bold New} button to create an empty world.  The {bold
    Preferences Editor} will open up ready for you to enter values
    for the world.  You'll need to enter values for the {bold Host}
    and {bold Port} and your {bold Username} and {bold Password}
    if you have one.  Also click on the {bold Add to short list} checkbox.
    When you've finished making changes in the Preferences Editor
    press the {bold Save} button.

    {paragraph foo}

    Now select the {bold Connect} menu option.  Notice how the
    world you've just added now appears in the short list menu?

    {paragraph foo}
    {header Making the connection}

    If your world has been short-listed then just select it from
    the {bold Connect} menu.  You can also select the {bold Connect->Worlds...} 
    menu option and double-click on the relevant entry in the list of worlds.

    {paragraph foo}
    {header Customising the connection}

    tkMOO-light has been developed to work well with MOO and Cold
    mud servers.  Both of these types of server expect you to log
    in by typing {bold connect <username> <password>} .  When the
    client connects to a server its normal behaviour is to send
    the command:

    {preformatted
    connect <username> <password>
    }

    The client will substitute the values you entered for your
    {bold username} and {bold password} into the command.

    {paragraph foo}

    You'll sometimes want the client to send additional commands
    to the server whenever you connect.  You can put these commands
    in the {bold Connection script} section of the Preferences
    Editor, but if you do this then you'll also need to add the
    'connect' command too.  Here's an example:

    {paragraph foo}

    If you wanted to connect to a MOO and then immediately read the news
    and check your mail then you could put something like this in
    your Connection script.

    {preformatted
    connect %u %p
    news
    @mail
    }

    Your username and password will be substituted automatically
    for the special tokens {bold %u} and {bold %p} .

    {paragraph foo}
    {header The Default World}

    To make things easier for you, the client has a {bold Default
    World} already set up with the most common settings that people
    use.  When the client connects to a world it will use these
    default settings unless you override some of them with new settings
    for that specific world.

    {paragraph foo}
    If you want to make a change that effects all of the worlds
    that the client knows about, then you should edit the settings
    for the default world.

}

set help_subject(Preferences) {
    {title The Preferences Editor}
    {header The Preferences Editor}

    The Preferences Editor has many directives grouped by categories.

    {paragraph foo}
    {header General Settings}

        {bold World}
        {paragraph foo}

	The name of the world you're connecting to.  you can enter
	any value here and the string will be used to help identify
	the mud.  if you use a unique world name then you can use
	it to connect to the world automatically with the {bold
	-world} command line option.  The value you enter here will
	also appear in the short list available from the {bold
	"Connect->Worlds..."} menu item.

        {paragraph foo}
        {bold Host}
        {paragraph foo}

	The host name, or IP address of the mud.

        {paragraph foo}
        {bold Port}
        {paragraph foo}

	The numeric port number of the mud.

        {paragraph foo}
        {bold User name}
        {paragraph foo}

	Your username on the mud.  If you don't enter a value then
	the client will prompt for a username and password when
	you connect to the mud.

        {paragraph foo}
        {bold Password}
        {paragraph foo}

	Your password on the mud.

        {paragraph foo}
        {bold Add to short list}
        {paragraph foo}

	Set this if you want the world to appear in the short list
	available from the {bold Connect->Worlds...} menu item.

        {paragraph foo}
        {bold Local echo}
        {paragraph foo}

	Set this if you want to see the words you type appearing
	hilighted in the output window of the client.  The colour
	of the echoed text is controlled by the {bold Local echo
	colour} directive in the {bold Colours and fonts} category.

        {paragraph foo}
        {bold Input window size}
        {paragraph foo}

	Controls the height of the input window at the bottom of
	the client.

        {paragraph foo}
        {bold Always resize window}
        {paragraph foo}

	When the client connects to a world it will check to see
	if you've saved a preferred window size and position.  If
	you have then the client will reset itself to take on those
	values.  This allows you to have different sized windows
	depending on the mud you're connecting to.

        {paragraph foo}

	You can save the client's current geometry settings by
	selecting the {bold Preferences->Save layout} menu option.

        {paragraph foo}
        {bold Client mode}
        {paragraph foo}

	Mud servers operate in one of two modes, {bold line mode}
	or {bold character mode} .  In line mode a server will send
	lines of text ending in a special end-of-line character.
	In character mode the server may send lines without an
	end-of-line character.  If the server uses command-line
	prompts a lot, or if it asks you a question and the cursor
	stays at the end of the line waiting for you to type your
	answer then the server is probably in character mode.

        {paragraph foo}

	MOO and Cold servers typically operate in line mode and
	many of the special out-of-band protocols that this client
	uses, like XMCP/1.1 and MCP/1.0 will rely upon line-mode
	communication.

        {paragraph foo}

	When in doubt, set this option to {bold line mode} .

        {paragraph foo}
        {bold Write to log file}
        {paragraph foo}

	You can control which of your worlds writes to a logfile
	by setting this toggle.  You'll still need to give a logfile
	name.  The client does not write to a logfile by default.

        {paragraph foo}
        {bold Log file name}
        {paragraph foo}

	The full path to a text file.  If the file doesn't exists
	then it will be created by the client.  If the file already
	exists then new messages will be appended to the file.

        {paragraph foo}
        {bold Connection script}
        {paragraph foo}

	A series of commands, one per line, that the client will
	send to the server immediately after connecting to the
	server.  The client's normal behaviour is to send the
	command {bold connect <username> <password>} but this is
	overriden by any commands you enter in the Connection script
	window.

	{paragraph foo}
	If you wish the client to send a 'connect' command then
	you'll need to add a line explicitly.  Here's an example
	script, the client will substitute the world's username
	and password values for the {bold %u} and {bold %p}
	parameters:

    {preformatted
    connect %u %p
    news
    @mail
    }

        {bold Disconnection script}
        {paragraph foo}

	A series of commands, one per line, that the client will
	send to the server immediately before connecting from the
	server.

	{paragraph foo}
        {bold Key bindings}
        {paragraph foo}

	The client understands several key-bindings that are common
	to other clients or operating-systems. 

    {preformatted
    emacs	standard emacs editor bindings
    tf		standard Tiny Fugue client bindings
    windows	standard Windows 95 bindings
    macintosh	standard Macintosh bindings
    default	standard Tk bindings
    }

    {header Out of Band}

    The client supports several forms of {bold Out of Band} protocol.
    Such protocols define how the client and server can pass complex
    messages to each other and they're usually associated with
    powerful user interfaces like {bold buddy lists} and {bold
    programming environments} .  The 2 main protocols used by the
    client are {bold XMCP/1.1} and the more modern {bold MCP/2.1} .

    {paragraph foo}

    XMCP applications include board-games, maps, whiteboards and
    drag-&-drop desktops.  Many XMCP applications are provided as
    additional {bold plugin} programs you can add to the client.

        {paragraph foo}
        {bold XMCP/1.1 enabled}
        {paragraph foo}

	This toggle controls whether or not the client reponds to
	XMCP messages which may be sent from the server.

	{paragraph foo}
        {bold XMCP/1.1 connection script}
        {paragraph foo}

	A series of commands, one per line, that the client will
	send to the server once an XMCP authentication code has
	been set.

        {paragraph foo}
        {bold Use MCP/2.1}
        {paragraph foo}

	This toggle controls whether or not the client reponds to
	MCP/2.1 messages which may be sent from the server.

        {paragraph foo}
        {bold Use MCP/1.0}
        {paragraph foo}

	This toggle controls whether or not the client reponds to
	MCP/1.0 messages which may be sent from the server.

    {paragraph foo}
    {header Colours and Fonts}

    The client is able to display text in a range of font styles
    and colours.  You can chose the overriding style of font
    displayed for each world by setting the {bold Default font
    type} option.

        {paragraph foo}
        {bold Normal text colour}
        {paragraph foo}

	Click on the long coloured bar to open a colour-chooser
	dialog box.  This option sets the foreground text colour
	for the main output window.

        {paragraph foo}
        {bold Background colour}
        {paragraph foo}

	This option sets the background colour for the main output window.

        {paragraph foo}
        {bold Local echo colour}
        {paragraph foo}

	This option sets the foreground colour for locally echoed
	text.  Local echo behaviour is controlled by the {bold
	Local echo} option under General Settings.

        {paragraph foo}
        {bold Default font type}
        {paragraph foo}

	This option controls the general look of the main display
	font, either fixedwidth or proportional.

        {paragraph foo}
        {bold Fixedwidth font}
        {paragraph foo}

	This option controls the font used for all fixedwidth text
	displayed on the output window.

        {paragraph foo}
        {bold Proportional font}
        {paragraph foo}

	This option controls the font used for all proportional text
	displayed on the output window.

        {paragraph foo}
        {bold Bold font}
        {paragraph foo}

	This option controls the font used for all bold text
	displayed on the output window.

        {paragraph foo}
        {bold Italic font}
        {paragraph foo}

	This option controls the font used for all italic text
	displayed on the output window.

        {paragraph foo}
        {bold Header font}
        {paragraph foo}

	This option controls the font used for all headings displayed
	on the output window.  At the moment any headings are also
	displayed in green.

    {paragraph foo}
    {header Paragraph Layout}

    Lines of text can be displayed as plain text (no margins or
    indentation), or with left and right margins, and extra
    indentation for text that wraps round the end of a line.

    {preformatted
|<- full width of output window  ------------------------------->|
|<- left ->|                                         |<- right  >|
           This is a long sentence which the client
                        will automatically wrap over 
                        several lines.  If the text
                        wraps over two or more lines
                        then the additional lines are
                        indented.  This helps to make
                        the text easier to read.
           |<- indent ->|
    }

    You can also control the spacing above or below a line of text.
    If a line wraps round to produce several formatted lines of
    text on the screen then the space between the screen lines can
    also be controlled.

        {paragraph foo}
	{bold Display paragraphs}
        {paragraph foo}

	Setting this toggle causes paragraphs of text to be displayed
	according to the following settings.

        {paragraph foo}
	{bold Distance units}
        {paragraph foo}

	All the paragraph settings can be in units of pixels,
	millimeters or characters.

        {paragraph foo}
	{bold Left margin}
        {paragraph foo}

	The distance from the left edge of the screen to the first
	character in the paragraph.

        {paragraph foo}
	{bold 2nd line indent}
        {paragraph foo}

	If the paragraph is longer than the width of the screen
	then the line will be wrapped.  The second line and subsequent
	lines in the paragraph will be indented but this amount.

        {paragraph foo}
	{bold Right margin}
        {paragraph foo}

	The distance from the right edge of the screen to the
	characters in the paragraph.

        {paragraph foo}
	{bold Space above}
        {paragraph foo}

	The amount of space displayed above the first line in a
	paragraph.

        {paragraph foo}
	{bold Space between}
        {paragraph foo}

	The amount of space displayed between each line in the body
	of a paragraph.

        {paragraph foo}
	{bold Space below}
        {paragraph foo}

	The amount of space displayed below the last line in a
	paragraph.

}

set help_subject(LICENCE) {
    {title LICENCE}
    {header LICENCE}
tkMOO-light is Copyright (c) Andrew Wilson 1994,1995,1996,1997,1998,
                                           1999,2000,2001.

	All Rights Reserved.

    {paragraph foo}

Permission is hereby granted to use this software for private, academic
and non-commercial use. No commercial or profitable use of this
software may be made without the prior permission of the author.
    {paragraph foo}

THIS SOFTWARE IS PROVIDED BY ANDREW WILSON ``AS IS'' AND ANY
EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL ANDREW WILSON BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
}

set help_subject(CommandLine) {
    {title Command Line Options}
    {header Command Line Options}

The client currently supports the following command line options,
{bold %} is your system prompt, optional arguments appear inside
braces.

{paragraph foo}     
{bold % tkmoo {-dir <directory>} {<host> {<port> default 23}} }
{paragraph foo}     

	Use it either from the command line or perhaps set up your
	web browser to use the client as the 'telnet' application
	when processing telnet URLs.  Telnet URLs can be bound to
	a command like 'tkmoo %h %p'.  When using a web browser
	like Netscape, %h and %p are translated to the telnet URL's
	host and port number respectively.

{paragraph foo}

	'<directory>' is the name of a directory containing the
	client's resource files, worlds.tkm and triggers.tkm files
	and /plugins/ directory.

{paragraph foo}     

	When no command line options are present, the client will
	start up and wait for you to select menu options.

{paragraph foo}     
{bold % tkmoo {-dir <directory>} -world <some unique substring>}
{paragraph foo}     

	The client will search for a world with a Name containing
	the substring.  If a unique world is present in your
	worlds.tkm file then the client will try to connect to it.
	If there are several worlds matching the substring then
	the client will display a list of the matching worlds, but
	will not attempt to connect to any of them.

{paragraph foo}     
{bold % tkmoo {-dir <directory>} -f <some file name>}
{paragraph foo}     

	The client assumes that the file is in the same format as
	the worlds.tkm file and contains a single world's definitions.
	The client will read the file and attempt to connect to
	the world defined there.

{paragraph foo}

        You can use this funtionality to create URLs to a .tkm
        file.  Make your webserver send a special mime-type when
	you download the file and teach your web browser to launch
	the client when it receives such a file.

{paragraph foo}

	A mime type like 'application/x-tkm' could be bound it to
	the command 'tkmoo -f %s'.  When using a web browser like
	Netscape, %s is translated to the downloaded file's name.

}
#
#



set fonts_plain      "-*-times-medium-r-*-*-14-*-*-*-*-*-*-*"
set fonts_fixedwidth "7x14"
set fonts_bold       "-*-times-bold-r-*-*-14-*-*-*-*-*-*-*"
set fonts_italic     "-*-times-medium-i-*-*-14-*-*-*-*-*-*-*"
set fonts_header     "-*-helvetica-medium-o-normal-*-18-*-*-*-*-*-*-*"

switch $tcl_platform(platform) {
    windows {
        if { $tk_version >= 8.0 } {
            set fonts_plain      {helvetica 8}
            set fonts_fixedwidth {courier 8}
            set fonts_bold       {helvetica 8 bold}
            set fonts_italic     {helvetica 8 italic}
            set fonts_header     {helvetica 10 bold italic}
        }
    }
    macintosh {
        if { $tk_version >= 8.0 } {
            set fonts_plain      {helvetica 12}
            set fonts_fixedwidth {courier 12}
            set fonts_bold       {helvetica 12 bold}
            set fonts_italic     {helvetica 12 italic}
            set fonts_header     {helvetica 14 bold italic}
        }
    }
    unix - default {
        if { $tk_version >= 8.0 } {
            set fonts_plain      {helvetica 12}
            set fonts_fixedwidth {courier 12}
            set fonts_bold       {helvetica 12 bold}
            set fonts_italic     {helvetica 12 italic}
            set fonts_header     {helvetica 14 bold italic}
        }
    }
}

proc fonts.get font {
    return [fonts.$font]
}

proc fonts.fixedwidth {} {
    global fonts_fixedwidth
    return [worlds.get_generic $fonts_fixedwidth fontFixedwidth FontFixedwidth FontFixedwidth]
}

proc fonts.plain {} {
    global fonts_plain
    return [worlds.get_generic $fonts_plain fontPlain FontPlain FontPlain]
}

proc fonts.bold {} {
    global fonts_bold
    return [worlds.get_generic $fonts_bold fontBold FontBold FontBold]
}

proc fonts.header {} {
    global fonts_header
    return [worlds.get_generic $fonts_header fontHeader FontHeader FontHeader]
}

proc fonts.italic {} {
    global fonts_italic
    return [worlds.get_generic $fonts_italic fontItalic FontItalic FontItalic]
}

#
#

set colourdb_colours(red) 	"#fb1441"
set colourdb_colours(orange) 	"#ffa600"
set colourdb_colours(yellow) 	"#ffff00"
set colourdb_colours(green) 	"#3cfb34"
set colourdb_colours(darkgreen) "#006500"
set colourdb_colours(lightblue)	"#c3e3e3"
set colourdb_colours(blue) 	"#5151fb"
set colourdb_colours(darkblue) 	"#00008a"
set colourdb_colours(black) 	"#000000"
set colourdb_colours(grey) 	"#dbdbdb"
set colourdb_colours(white) 	"#ffffff"
set colourdb_colours(pink) 	"#d3b6b6"

set colourdb_colours(magenta)	"#ff00ff"
set colourdb_colours(cyan)	"#00ffff"

proc colourdb.get colour {
    global colourdb_colours
    set col ""
    catch { set col $colourdb_colours($colour) };
    if { $col == "" } {
	puts "colourdb.get, colour '$colour' unknown"
	set col black
    }
    return $col
}
#
#

proc window.clear_tagging_info {} {
    global window_tagging_info
    set window_tagging_info {}
}
proc window.append_tagging_info record {
    global window_tagging_info
    lappend window_tagging_info $record
}
proc window.assert_tagging_info line {
    global window_tagging_info
    set last_char [.output index {end - 1 char}]
    foreach {num _} [split $last_char "."] { break }
    foreach record $window_tagging_info {
        foreach {the_line tag_list} $record { break }
        if { $line == $the_line } {
            foreach tag_record $tag_list {
                foreach {from to tags} $tag_record { break }
                foreach tag $tags {
                    .output tag add $tag $num.$from $num.$to
                }
            }
        }
    }
}

proc window.place_absolute {win x y} {
    wm geometry $win "+$x+$y"
}
proc window.place_nice {this {that ""}} {
    if { $that != "" } {
    	set x [winfo rootx $that]
    	set y [winfo rooty $that]

    	incr x 50
    	incr y 50

    	window.place_absolute $this $x $y
    } {
    	window.place_absolute $this 50 50
    }
}

proc window.set_geometry {win geometry} {
    pack propagate . 1
    wm geometry $win $geometry
    update
    pack propagate . 0
}

proc window.bind_escape_to_destroy win {
    global tcl_platform
    if { $tcl_platform(os) == "Darwin" } {
        bind $win <Command-w> "destroy $win"
    } {
        bind $win <Escape> "destroy $win"
    }
}

proc window.configure_for_macintosh win {
    global tcl_platform
    if { $tcl_platform(os) != "Darwin" } {
    	return;
    }
    #PLG:TODO
    # set mac _macintosh
    # if { $win != "." } {
    # set mac "._macintosh"
    # }

    # set topline "_topline"
    # set cell "_cell"
    # if { [winfo exists $win$mac$topline] } {
    # return;
    # }

    # frame $win$mac$topline \
    # -height 1 \
    # -borderwidth 0 \
    # -highlightthickness 0 \
    # -background #000000
    # frame $win$mac$cell \
    # -height 14 \
    # -borderwidth 0 \
    # -highlightthickness 0 \
    # -background #cccccc
    # window.pack_for_macintosh $win
}

proc window.pack_for_macintosh win {
    global tcl_platform
    if { $tcl_platform(os) != "Darwin" } {
        return;
    }
    #PLG:TODO
    # set mac _macintosh
    # if { $win != "." } {
    # set mac "._macintosh"
    # }
    # set topline "_topline"
    # set cell "_cell"
    # pack $win$mac$cell \
    # -side bottom \
    # -fill x \
    # -in $win
    # pack $win$mac$topline \
    # -side bottom \
    # -fill x \
    # -in $win
}

proc window.toolbar_look frame {
    global tcl_platform

    if { $tcl_platform(platform) == "windows" } {
        set sep $frame.__separator
        frame $sep -highlightthickness 0 -bd 2 -relief sunken -height 2
        pack $sep -side top -fill x
        $frame configure -relief flat -bd 0 -highlightthickness 0
        return;
    } 
    # if { 0 && $tcl_platform(platform) == "macintosh" } {
    #     set sep $frame.__separator
    #     frame $sep -highlightthickness 0 -bd 2 -relief sunken -height 2
    #     pack $sep -side bottom -fill x
    #     $frame configure -relief flat -bd 0 -highlightthickness 0
    #     return
    # }
    if { $tcl_platform(platform) == "unix" } {
        # also if $tcl_platform(os) == "Darwin"
        #
        $frame configure -relief raised -bd 1 -highlightthickness 0
        return;
    }
}

proc window.set_scrollbar_look scrollbar {
    global tcl_platform
    if { $tcl_platform(platform) == "unix" } {
        $scrollbar configure -width 10
    } elseif { $tcl_platform(platform) == "macintosh" } {
        $scrollbar configure -bd 0
    }
}

proc window.iconify {} {
    if { [winfo viewable .] } {
        wm iconify .
    }
}

proc window.deiconify {} {
    if { ! [winfo viewable .] } {
        wm deiconify .
    }
}

proc window.initialise_text_widget w {
    global window_db
    set window_db("$w,window_CR") 0
}

set window_CR 0

set window_input_size 1
set window_input_size_display 1

set window_close_state disabled

proc window.hidemargin menu {
    global tcl_platform
    if { ($tcl_platform(os) == "Darwin") || ($tcl_platform(platform) == "windows") } {
    	return
    }

    if { ([util.eight] == 1) && ([$menu type end] != "separator") } {
        $menu entryconfigure end -hidemargin 1
    }
}

proc window.save_layout {} {
    set world [worlds.get_current]
    if { $world == "" } { return }

    set worlds_geometry [worlds.get_generic "=50x24" {} {} WindowGeometry]
    set actual_geometry [wm geometry .]
    if { $worlds_geometry != $actual_geometry } {
    	worlds.set $world WindowGeometry $actual_geometry
    }
}

client.register window start
proc window.start {} {
    global window_clip_output_buffer
    set window_clip_output_buffer 0
    preferences.register window {Special Forces} {
        { {directive UnderlineHyperlinks}  
              {type choice-menu}
              {default hover}
              {display "Underline hyperlinks"}
              {choices {never hover always}} }
        { {directive HyperlinkForeground}  
              {type colour}
              {default "#0000ee"}
              {default_if_empty}
              {display "Link colour"}}
        { {directive WindowClipBuffer}  
              {type boolean}
              {default Off}
              {display "Limit output window"} }
        { {directive WindowClipBufferSize}  
              {type updown-integer}
              {default 500}
              {display "Output window size"}
              {low 500}
              {delta 500}
	      {high 100000}}
    }

    preferences.register window {Paragraph Layout} {
        { {directive UseParagraph}  
              {type boolean}
              {default On}
              {display "Display paragraphs"} }
        { {directive ParagraphUnits}
              {type choice-menu}
              {default pixels}
              {display "Distance units"}
              {choices {pixels millimeters characters}} }
        { {directive ParagraphLMargin}
              {type updown-integer}
              {default 0}
              {display "Left margin"}
              {low 0}
	      {high 50}}
        { {directive ParagraphLIndent}
              {type updown-integer}
              {default 3}
              {display "2nd line indent"}
              {low 0}
	      {high 100}}
        { {directive ParagraphRMargin}
              {type updown-integer}
              {default 0}
              {display "Right margin"}
              {low 0}
	      {high 50}}
        { {directive ParagraphSpacing1}
              {type updown-integer}
              {default 0}
              {display "Space above"}
              {low 0}
	      {high 10}}
        { {directive ParagraphSpacing2}
              {type updown-integer}
              {default 0}
              {display "Space between"}
              {low 0}
	      {high 10}}
        { {directive ParagraphSpacing3}
              {type updown-integer}
              {default 0}
              {display "Space below"}
              {low 0}
	      {high 10}}
    }
    preferences.register window {Statusbar Settings} {
        { {directive ShowStatusbars}
              {type boolean}
              {default On}
              {display "Show statusbars"} }
        { {directive UseActivityFlash}
              {type boolean}
              {default On}
              {display "Activity flash light"} }
    }
    preferences.register window {Statusbar Settings} {
        { {directive KioskTimeout}
              {type updown-integer}
              {default 0}
              {low 0}
              {high 30}
              {display "Kiosk after seconds"} }
    }
}


set window_activity_flash 0
set window_activity_toggle 0

proc window.activity_flash {} {
    global window_activity_flash window_activity_toggle \
       window_activity_flash_colour window_flash
    if { [winfo exists $window_flash] == 0 } { return }
    if { $window_activity_flash == 0 } {
        $window_flash.light configure -background $window_activity_flash_colour
        return
    }
    if { [window._last_char_is_visible] == 1 } {
        $window_flash.light configure -background $window_activity_flash_colour
        set window_activity_flash 0
        set window_activity_toggle 0
        return
    }
    if { $window_activity_toggle == 1 } {
        $window_flash.light configure -background red
        set window_activity_toggle 0
    } {
        $window_flash.light configure -background $window_activity_flash_colour
        set window_activity_toggle 1
    }
    after 500 window.activity_flash
}

proc window.activity_begin_flashing {} {
    global window_activity_flash
    
    if { $window_activity_flash == 0 } {
	set window_activity_flash 1
	window.activity_flash
    }
}
proc window.activity_stop_flashing {} {
    global window_activity_flash window_activity_toggle
    set window_activity_flash 0
}

set window_toolbars {}
proc window.add_toolbar toolbar {
    global window_toolbars
    if { [lsearch -exact $window_toolbars $toolbar] == -1 } {
        lappend window_toolbars $toolbar
    }
}
proc window.remove_toolbar toolbar {
    global window_toolbars
    set index [lsearch -exact $window_toolbars $toolbar]
    if { $index != -1 } {
        set window_toolbars [lreplace $window_toolbars $index $index]
    }
}

set window_statusbars {}
proc window.add_statusbar statusbar {
    global window_statusbars
    if { [lsearch -exact $window_statusbars $statusbar] == -1 } {
    	if { $statusbar == ".statusbar" } {
    	    set window_statusbars [linsert $window_statusbars 0 $statusbar]
    	} {
                lappend window_statusbars $statusbar
    	}
    }
}
proc window.remove_statusbar statusbar {
    global window_statusbars
    set index [lsearch -exact $window_statusbars $statusbar]
    if { $index != -1 } {
        set window_statusbars [lreplace $window_statusbars $index $index]
    }
}

proc window.statusbar_create {} {
    if { [winfo exists .statusbar] == 1 } { return }
    global window_statusbar_message
    set window_statusbar_message ""
    frame .statusbar -bd 1 -relief sunken -highlightthickness 0
    window.add_statusbar .statusbar
    label .statusbar.messages \
        -text "" \
        -highlightthickness 0 \
        -bd 1 \
        -relief raised \
        -justify left \
        -anchor w \
        -bg lightblue 
    pack .statusbar.messages -side left -expand 1 -fill x
    bind .statusbar.messages <Configure> "window.statusbar_messages_repaint"
    window.repack
}

proc window.statusbar_destroy {} {
    catch { destroy .statusbar }
    window.remove_statusbar .statusbar
}


proc window.truncate_for_label {label text} {
    global tk_version
    if { $tk_version < 8.0 } {
    	return $text
    }
    set width [winfo width $label]
    set padx [$label cget -padx]
    set font [$label cget -font]
    set measure [font measure $font -displayof $label $text]
    if { $measure < [expr $width - 4*$padx] } {
        return $text
    }
    for {set i [string length $text]} {$i > 0} { incr i -1 } {
        set trial "[string trimright [string range $text 0 $i]]..."
        set measure_trial [font measure $font -displayof $label $trial]
        if { $measure_trial < [expr $width - 4*$padx] } {
            set text $trial 
            break
        }   
    }
    if { $i == 0 } {
    	return ""
    }
    return $text
}

proc window.statusbar_messages_repaint {} {
    global window_statusbar_message
    .statusbar.messages configure -text [window.truncate_for_label .statusbar.messages $window_statusbar_message]
}

proc window.set_status {text {type decay}} {
    global window_statusbar_current_task_id window_statusbar_message
    window.statusbar_create
    set window_statusbar_message $text
    window.statusbar_messages_repaint
    catch { 
        after cancel $window_statusbar_current_task_id 
    }
    if { $type == "decay" } {
    	set window_statusbar_current_task_id [after 20000 window.statusbar_decay]
    }
}

proc window.statusbar_decay {} {
    window.set_status "" stick
}

proc window.create_statusbar_item {} {
    window.statusbar_create
    set item .statusbar.[util.unique_id "item"]
    return $item
}
proc window.delete_statusbar_item item {
    destroy $item
}
proc window.clear_status_if_present {} {
    if { [winfo exists .statusbar] == 1 } {
        .statusbar.messages configure -text ""
    }
}

proc window.client_connected {} {
    global window_close_state window_fonts tkmooVersion
    set window_close_state normal

    .menu.connections entryconfigure "Close Connection" -state normal
    
    set size [worlds.get_generic 1 {} {} InputSize]

    if { $size < 1 } { set size 1 };
    if { $size > 5 } { set size 5 };
    after idle window.input_resize $size

    set fg [worlds.get_generic "#000000" foreground Foreground ColourForeground]

    if { $fg != "" } {
        .output configure -foreground $fg 
    }

    set bg [worlds.get_generic "#f0f0f0" background Background ColourBackground]

    if { $bg != "" } {
        .output configure -background $bg
    }

    set fg [worlds.get_generic "#000000" foregroundinput ForegroundInput ColourForegroundInput]

    if { $fg != "" } {
        .input configure -foreground $fg 
    }

    set bg [worlds.get_generic [colourdb.get pink] backgroundinput BackgroundInput ColourBackgroundInput]

    if { $bg != "" } {
        .input configure -background $bg
    }

    set font [worlds.get_generic fixedwidth background DefaultFont DefaultFont]

    if { $font != "" } {
        set window_fonts $font
    }
    window.reconfigure_fonts

    catch { wm title . "[worlds.get [worlds.get_current] Name] - tkMOO-light" }
    catch { wm iconname . [worlds.get [worlds.get_current] Name] }

    set lm      [worlds.get_generic 0 {} {} ParagraphLMargin]
    set in      [worlds.get_generic 3 {} {} ParagraphLIndent]
    set rm      [worlds.get_generic 0 {} {} ParagraphRMargin]
    set s_one   [worlds.get_generic 0 {} {} ParagraphSpacing1]
    set s_two   [worlds.get_generic 0 {} {} ParagraphSpacing2]
    set s_three [worlds.get_generic 0 {} {} ParagraphSpacing3]
    set units   [worlds.get_generic pixels {} {} ParagraphUnits]

    set xxx(pixels)      p
    set xxx(millimeters) m
    set xxx(characters)  c
    set units $xxx($units)

    set use [worlds.get_generic on {} {} UseParagraph]

    if { [string tolower $use] == "on" } {
        set paragraphs 1
    } {
        set paragraphs 0
    }

    if { $paragraphs == 1 } {

        eval .output tag configure window_margin -lmargin1 [join "$lm $units" {}] -lmargin2 [join "$in $units" {}] -rmargin [join "$rm $units" {}] -spacing1 [join "$s_one $units" {}] -spacing2 [join "$s_two $units" {}] -spacing3 [join "$s_three $units" {}]

    } {

        .output tag configure window_margin -lmargin1 0 -lmargin2 0 -rmargin 0 -spacing1 0 -spacing2 0 -spacing3 0

    }

    set show_statusbars [worlds.get_generic "On" {} {} ShowStatusbars]
    if { [string tolower $show_statusbars] == "on" } {
	window.set_statusbar_flag 1
    } {
	window.set_statusbar_flag 0
    }

    window.statusbar_destroy

    set use_flash [worlds.get_generic On {} {} UseActivityFlash]
    if { [string tolower $use_flash] == "on" } {
        window.make_flash
    } {
        window.destroy_flash
    }


    set resize [worlds.get_generic 0 {} {} WindowResize]
    if { $resize } {

        set geometry [worlds.get_generic "=80x24+100+100" {} {} WindowGeometry]

        if { $geometry != "" } {
	    if { [regexp {^=*[0-9]*x[0-9]*[+-][0-9]*[+-][0-9]*$} $geometry unused gx gy] == 1 } {
                after idle window.set_geometry . $geometry
	    }
        } {
	    window.place_nice .
	}
    }
    window.menu_preferences_state "Edit Preferences..." normal
    window.repack

    global window_clip_output_buffer window_clip_output_buffer_size
    set use_clip [worlds.get_generic Off {} {} WindowClipBuffer]
    if { [string tolower $use_clip] == "on" } {
	set window_clip_output_buffer 1
    } {
	set window_clip_output_buffer 0
    }
    set window_clip_output_buffer_size [worlds.get_generic Off {} {} WindowClipBufferSize]
}

set window_flash 0
proc window.make_flash {} {
    global window_flash window_activity_flash_colour
    if { [winfo exists $window_flash] == 1 } { return };
    set window_flash [window.create_statusbar_item]
    frame $window_flash -bd 0 -highlightthickness 0 -relief raised
    pack $window_flash -side right -fill both
    frame $window_flash.light -bd 1 -height 10 -width 6 -relief raised
    $window_flash.light configure -background pink
    set window_activity_flash_colour [$window_flash.light cget -background]
    pack $window_flash.light -expand 1 -fill y
}
proc window.destroy_flash {} {
    global window_flash
    window.delete_statusbar_item $window_flash
}

proc window.client_disconnected {} {
    global window_close_state
    set window_close_state disabled
    window.displayCR "Connection closed" window_highlight
    wm title    . "tkMOO-light"
    wm iconname . "tkMOO-light"
    window.clear_status_if_present
    window.menu_preferences_state "Edit Preferences..." disabled

    .menu.connections entryconfigure "Close Connection" -state disabled
}

proc window.do_open {} {
    set host [string trim [.open.entries.host get]]
    set port [string trim [.open.entries.port get]]
    if { $host != "" && $port != "" } {
        destroy .open
        client.connect $host $port 
    }
}

proc window.open {} {
    catch { destroy .open };
    toplevel .open
    window.configure_for_macintosh .open

    window.place_nice .open

    .open configure -bd 0

    wm title .open "Open Connection"
    frame .open.entries
    label .open.entries.h -text "Host:"
    entry .open.entries.host -font [fonts.fixedwidth]
    label .open.entries.p -text "Port:"
    entry .open.entries.port -width 4 -font [fonts.fixedwidth]
    pack .open.entries.h -side left
    pack .open.entries.host -side left
    pack .open.entries.p -side left
    pack .open.entries.port -side left

    frame .open.buttons

    button .open.buttons.connect -text "Connect" -command { window.do_open }

    bind .open <Return> { window.do_open };
    window.bind_escape_to_destroy .open

    button .open.buttons.cancel -text "Cancel" -command "destroy .open"

    pack .open.entries
    pack .open.buttons

    pack .open.buttons.connect .open.buttons.cancel -side left -padx 5 -pady 5
    window.focus .open.entries.host
}

proc window.menuise_worlds {} {
    catch {
    	.menu.connections.menu delete 5 end
    }
    .menu.connections.menu add separator
    set hints [split 0123456789abdfghijklmnprstuvwxyz {}]
    foreach world [worlds.worlds] { 
	set hint [lindex $hints 0]
	set hints [lrange $hints 1 end]
        .menu.connections.menu add command \
        -label   "$hint. [worlds.get $world Name]"\
    	-underline 0 \
        -command "client.connect_world \"$world\""
    }
}

proc window.do_disconnect {} {
    set session ""
    catch {
        set session [db.get .output session]
    }
    if { $session != "" } {
    	client.disconnect_session $session
    }
}

proc window.post_connect {} {
    global tcl_platform
	set menu .menu.connections

    global window_close_state

    $menu delete 0 end

    $menu add command -label "Worlds..." -underline 0 -command "window.open_list"
    window.hidemargin $menu

    $menu add command -label "Open Connection..." -underline 0 -command "window.open"
    window.hidemargin $menu

    $menu add command -label "Close Connection" -underline 0 \
        -command "window.do_disconnect" \
        -accelerator "[window.accel Ctrl]+K"
    bind . <Command-k> "window.do_disconnect"
    window.hidemargin $menu

    $menu entryconfigure "Close Connection" -state $window_close_state

    $menu add separator

    if { $tcl_platform(os) == "Darwin" } {
        set hints [split 0123456789 {}]
    } {
        set hints [split 0123456789abdefghijklmnprstuvxyz {}]
    }

    foreach world [worlds.worlds] {
    	if { $world != 0 } {
    	    set shortlist ""
    	    catch { set shortlist [worlds.get_generic "Off" {} {} ShortList $world] }

    	    if { [string tolower $shortlist] == "on" } {
    	        set hint [lindex $hints 0]
    	        set hints [lrange $hints 1 end]

        		if { $tcl_platform(os) == "Darwin" } {
                    set label [worlds.get $world Name]
        		} {
        		    set label "$hint. [worlds.get $world Name]"
        		}

                $menu add command -label $label -underline 0 \
                    -command "client.connect_world $world" \
                    -accelerator "Cmd+$hint"
                bind . <Command-$hint> "client.connect_world $world"
                window.hidemargin $menu
    	    }
    	}
    }

    # $menu add separator
    # $menu add command -label "Quit" -underline 0 -command "client.exit"

    window.hidemargin $menu
}

proc window.load_connections_menu {} {
    if { [worlds.load] == 1 } {
        set worlds [worlds.worlds]
        window.menuise_worlds
    }
}

proc window.configure_help_menu {} {
	set menu .menu.help
    $menu delete 0 end
    foreach subject [help.subjects] {
        if { $subject == "SEPARATOR" } {
	    $menu add separator
        } {
            $menu add command -label "[help.get_title $subject]" -command "help.show $subject"
            window.hidemargin $menu
        }
    }
}


proc window.menu_help_add { text {command ""} } {
	set menu .menu.help

    if { $text == "SEPARATOR" } {
	$menu add separator
    } {
        $menu add command -label "$text" -command $command
        window.hidemargin $menu
    }
}

proc window.menu_help_state { text state } {
    .menu.help entryconfigure $text -state $state
}

# proc window.menu_tools_macintosh_accelerator { text accelerator } {
#     set menu .menu.tools
#     window.menu_macintosh_accelerator $menu $text $accelerator
# }

proc window.menu_tools_add { text {command ""} accelerator } {
	set menu .menu.tools
    if { $text == "SEPARATOR" } {
    	$menu add separator
    } {
        $menu add command -label "$text" -command $command -accelerator $accelerator
        window.hidemargin $menu
    }
}

proc window.menu_tools_state { text state } {
    .menu.tools entryconfigure $text -state $state
}

# proc window.menu_preferences_macintosh_accelerator { text accelerator } {
#     set menu .menu.prefs
#     window.menu_macintosh_accelerator $menu $text $accelerator
# }

proc window.menu_preferences_state { text state } {
    .menu.prefs entryconfigure $text -state $state
}

proc window.menu_preferences_add { text {command ""} } {
	set menu .menu.prefs
    if { $text == "SEPARATOR" } {
    	$menu add separator
    } {
        $menu add command -label   "$text" -command $command
        window.hidemargin $menu
    }
}

proc window.reconfigure_fonts {} {
    global window_fonts
    switch $window_fonts {
    	fixedwidth {
    	    .output configure -font [fonts.fixedwidth]
    	    .input configure -font [fonts.fixedwidth]
    	}
    	proportional {
               .output configure -font [fonts.plain]
               .input configure -font [fonts.plain]
    	}
    }
}

proc window.resize_event {} {
    global window_resize_event_task
    catch { after cancel $window_resize_event_task }
    set window_resize_event_task [after idle {
    	window.save_layout
    }]
}

# proc window.menu_macintosh_accelerator {menu pattern accelerator} {
#     global tcl_platform
#     if { $tcl_platform(os) == "Darwin" } {
#         $menu entryconfigure $pattern -accelerator $accelerator
#     }
# }

###
proc window.set_local_echo_from_menu {} {
    global client_echo
    if { $client_echo } {
        set value On
    } {
        set value Off
    }
    if { [set world [worlds.get_current]] != "" } {
        worlds.set_if_different $world LocalEcho $value
    }
}

proc window.set_client_mode_from_menu {} {
    global client_mode
    if { [set world [worlds.get_current]] != "" } {
        worlds.set_if_different $world ClientMode $client_mode
    }
}

proc window.set_key_bindings_from_menu {} {
    global window_binding
    if { [set world [worlds.get_current]] != "" } {
        worlds.set_if_different $world KeyBindings $window_binding
    }
    bindings.set $window_binding
}

proc window.set_default_font_from_menu {} {
    global window_fonts
    if { [set world [worlds.get_current]] != "" } {
        worlds.set_if_different $world DefaultFont $window_fonts
    }
    client.reconfigure_fonts
}

proc window.set_input_size_from_menu {} {
    global window_input_size_display
    if { [set world [worlds.get_current]] != "" } {
        worlds.set_if_different $world InputSize $window_input_size_display
    }
    window.input_resize $window_input_size_display
}

proc window.toggle_statusbar_from_menu {} {
    window.toggle_statusbar
    if { [set world [worlds.get_current]] != "" } {
        if { [window.get_statusbar_flag] } {
            set flag On
        } {
            set flag Off
        }
        worlds.set_if_different $world ShowStatusbars $flag
    }
}
#
###

proc window.buildWindow {} {
    window.set_statusbar_flag 1
    global tkmooVersion client_mode client_echo window_activity_flash_colour window_flash

    wm title    . "tkMOO-light"
    wm iconname . "tkMOO-light"
    . configure -bd 0

    wm geometry . "+0+0"

    #PLG:TODO window.configure_for_macintosh .

    menu .menu -bd 0 -tearoff 0 -relief raised -bd 1
    . configure -menu .menu

    .menu add cascade -label "Connect" -underline 0 -menu .menu.connections
    menu .menu.connections -tearoff 0 -bd 1

    .menu add cascade -label "Edit" -underline 0 -menu .menu.edit
    menu .menu.edit -tearoff 0 -bd 1
    .menu.edit add command -label "Cut" -command "ui.delete_selection .input" -accelerator "[window.accel Ctrl]+X"
    window.hidemargin .menu.edit
    .menu.edit add command -label "Copy" -command "ui.copy_selection .input" -accelerator "[window.accel Ctrl]+C"
    window.hidemargin .menu.edit
    .menu.edit add command -label "Paste" -command "ui.paste_selection .input" -accelerator "[window.accel Ctrl]+V"
    window.hidemargin .menu.edit
    .menu.edit add separator
    .menu.edit add command -label "Clear" -underline 1 -command "ui.clear_screen .output" -accelerator "[window.accel Ctrl]+L"
    window.hidemargin .menu.edit

    .menu add cascade -label "Tools" -underline 0 -menu .menu.tools
    menu .menu.tools -tearoff 0 -bd 1

    .menu add cascade -label "Preferences" -underline 0 -menu .menu.prefs
    menu .menu.prefs -tearoff 0 -bd 1

    window.menu_preferences_add "Toggle Statusbars" window.toggle_statusbar_from_menu

    .menu.prefs add cascade -label "Key Bindings" -menu .menu.prefs.bindings
    window.hidemargin .menu.prefs
    menu .menu.prefs.bindings -tearoff 0

    foreach binding [bindings.bindings] {
        .menu.prefs.bindings add radio -variable window_binding -value $binding -label "$binding" -command "window.set_key_bindings_from_menu"
    }

    .menu.prefs add cascade -label "Default Font" -menu .menu.prefs.fonts
    window.hidemargin .menu.prefs

    menu .menu.prefs.fonts -tearoff 0

    foreach font {fixedwidth proportional} {
        .menu.prefs.fonts add radio -variable window_fonts -value $font -label "$font" -command window.set_default_font_from_menu
    }

    .menu.prefs add cascade -label "Mode" -menu .menu.prefs.mode
    window.hidemargin .menu.prefs
    menu .menu.prefs.mode -tearoff 0

    foreach mode {line character} {
        .menu.prefs.mode add radio -variable client_mode -value $mode -label "$mode" -command "window.set_client_mode_from_menu"
    }

    .menu.prefs add cascade -label "Local Echo" -menu .menu.prefs.local
    window.hidemargin .menu.prefs
    menu .menu.prefs.local -tearoff 0

    .menu.prefs.local add radio -variable client_echo -value 1 -command "window.set_local_echo_from_menu" -label "on"
    .menu.prefs.local add radio -variable client_echo -command "window.set_local_echo_from_menu" -value 0 -label "off"

    .menu.prefs add cascade -label "Input Size" -menu .menu.prefs.size
    window.hidemargin .menu.prefs

    menu .menu.prefs.size -tearoff 0
    for {set i 1} {$i < 6} {incr i} {
        .menu.prefs.size add radio -variable window_input_size_display -value $i -label "$i" -command window.set_input_size_from_menu
    }

    .menu add cascade -label "Help" -underline 0 -menu .menu.help
    menu .menu.help -tearoff 0 -bd 1

	window.configure_help_menu

    global tcl_platform
    if { $tcl_platform(platform) == "windows" } {
	    frame .canyon -bd 2 -height 2 -relief sunken
    }

    #PLG window size
    text .output -cursor {} \
        -font [fonts.fixedwidth] \
        -width 110 -height 35 \
        -setgrid 1 \
        -relief flat \
        -bd 0 \
        -yscrollcommand ".scrollbar set" \
        -highlightthickness 0 \
        -wrap word

    text .input \
        -wrap word \
        -relief sunken \
        -height 1 \
        -highlightthickness 0 \
        -font [fonts.fixedwidth] \
        -background [colourdb.get pink]

    history.init .input 1

    scrollbar .scrollbar -command ".output yview" -highlightthickness 0

    window.set_scrollbar_look .scrollbar

    window.repack

	update
	pack propagate . 0

    bind .output <ButtonRelease-2> {
        if {!$tkPriv(mouseMoved)} { window.selection_to_input }
    }
    bindtags .output {Text .output . all}

    .output configure -state disabled

    window.focus .input

    .output tag configure window_margin -lmargin1 0m -lmargin2 3m
    .output tag configure window_highlight -foreground [colourdb.get red]

    bind . <FocusIn> {window.cancel_lite}
    bind . <FocusOut> {window.timeout_lite}

    bind . <Configure> { window.resize_event }

    wm protocol . WM_DELETE_WINDOW client.exit

    global window_clip_output_buffer
    set window_clip_output_buffer 0
    window.hyperlink.init
    window.initialise_text_widget .output
}

proc window.accel str {
    global tcl_platform
    if { $str == "Ctrl" && $tcl_platform(os) == "Darwin" } {
		return "Cmd"
    }
    return $str
}

proc window.focus win {
    global tcl_platform
    if { $tcl_platform(platform) == "windows" || $tcl_platform(os) == "Darwin" } {
    	after idle raise [winfo toplevel $win]
    }
    focus $win
}


proc window.cancel_lite {} {
    global window_timeout_lite window_timeout_lite_task

    if { [lsearch -exact [pack slaves .] .input] == -1 } {
        window.repack
    }
    set window_timeout_lite 0
}

proc window.timeout_lite {} {
    global window_timeout_lite window_timeout_lite_task
    if { $window_timeout_lite != 0 } { return };
    set task [util.unique_id task]
    set window_timeout_lite $task
    set timeout [worlds.get_generic 0 {} {} KioskTimeout]
    if { $timeout } {
        set timeout [expr $timeout * 1000]
        set window_timeout_lite_task [after $timeout window.timeout_lite_doit $task]
    }
}

proc window.timeout_lite_doit task {
    global window_timeout_lite
    if { $window_timeout_lite == $task } {
        window.repack_lite
        set window_timeout_lite 0
    }
}

set window_timeout_lite 0
proc window.repack_lite {} {
    global window_toolbars window_statusbars
    set slaves [pack slaves .]
    set tmp [list]
    foreach s $slaves {
        if { $s != ".output" } {
            lappend tmp $s
        }
    }
    set slaves $tmp

    . configure -menu {}

    foreach slave $slaves {
	pack forget $slave
    }
    pack configure .output -side bottom -fill both -expand on
}

#

set window_unsent_cmd [list 0 ""]

proc window.ui_input_return {} {
    global window_unsent_cmd
    set line [.input get 1.0 {end -1 char}]
    after idle ".input delete 1.0 end"
    history.add .input "$line"
    client.outgoing "$line"
    set window_unsent_cmd [list 0 ""]
}

proc window.ui_input_up {} {
    global window_unsent_cmd
    if { [lindex $window_unsent_cmd 0] == 0 } {
        set window_unsent_cmd [list 1 [.input get 1.0 {end -1c}]]
    }
    set prev [history.prev .input]
    .input delete 1.0 end
    .input insert insert $prev
}

proc window.ui_input_down {} {
    global window_unsent_cmd

    set next [history.next .input]
    if { $next == "" } {
        if { [lindex $window_unsent_cmd 0] == 1 } {
            set next [lindex $window_unsent_cmd 1]
            set window_unsent_cmd [list 0 ""]

            .input delete 1.0 end
            .input insert insert $next
	}
    } {
        .input delete 1.0 end
        .input insert insert $next
    }
}


proc window.toggle_statusbar {} {
    window.toggle_statusbar_flag
    window.repack
}

proc window.set_statusbar_flag value {
    global window_statusbar_flag
    set window_statusbar_flag $value
}

proc window.get_statusbar_flag {} {
    global window_statusbar_flag
    return $window_statusbar_flag
}

proc window.toggle_statusbar_flag {} {
    global window_statusbar_flag
    if { $window_statusbar_flag } {
    	set window_statusbar_flag 0
    } {
    	set window_statusbar_flag 1
    }
}

proc window.repack {} {
    global window_repack_task
    catch { after cancel $window_repack_task }
    set window_repack_task [after idle window.really_repack]
}

proc window.really_repack {} {
    global window_toolbars window_statusbars

    set window_current_position [.output yview]

    foreach slave [pack slaves .] {
    	pack forget $slave
    }

    . configure -menu .menu

    window.configure_for_macintosh .
    window.pack_for_macintosh .

    if { [window.get_statusbar_flag] == 1 } {

        foreach statusbar $window_statusbars {
            pack $statusbar -side bottom -fill x -in .
        }
    }

    pack .input -side bottom -fill x -in .

    foreach toolbar $window_toolbars {
        pack $toolbar -side top -fill x -in .
    }

    global tcl_platform
    if { $tcl_platform(platform) == "windows" } {
        pack .canyon -side top -fill x -in .
    }

    pack .scrollbar -side right -fill y -in .
    pack .output -side bottom -fill both -expand on -in .

    after idle .output yview moveto [lindex $window_current_position 1]
}

proc window.input_size {} {
    global window_input_size
    return $window_input_size
}

proc window.input_resize size {
    global window_input_size window_input_size_display

    if { $size == $window_input_size } {
        return 0
    }   
    .input configure -height $size 
    set window_input_size $size
    set window_input_size_display $size
    client.set_bindings
    return 0
}

proc window.dabbrev_search {win pattern} {
    set enough_words 10

    set from [$win index end]
    set psn $from
    set enough_lines [expr $from - 1000.0]
    set len 0

    while { 
	    [set psn [$win search -backwards -nocase -- $pattern $from 1.0]] != {}
            && $len < $enough_words
	    && $psn > $enough_lines
	    } {


	set pre [$win get "$psn wordstart" $psn]
	regsub -all {[^A-Za-z]*} $pre {} pre
	if { $pre == {} } {
	    set word [$win get $psn "$psn + 1 chars wordend"]
	    regsub -all {[^A-Za-z]*$} $word {} word
	    regsub -all {^[^A-Za-z]*} $word {} word
	    if { $word != "" } {
	        set word [string tolower $word]
                set words_db($word) 1
	        set len [llength [array names words_db]]
	    }
	}
	set from $psn
    }

    return [array names words_db]
}

proc window.dabbrev args {
    window.dabbrev_init
    set input [.input get 1.0 {end -1 char}]
    set partial_psn [string wordstart $input [string length $input]]
    set partial [string range $input $partial_psn end]
    if { $partial == "" } { 
        return
    }

    regsub -all {\?} $partial {\\?} new_partial
    regsub -all {\*} $new_partial {\\*} new_partial
    regsub -all {\+} $new_partial {\\+} new_partial
    regsub -all {\(} $new_partial {\\(} new_partial
    regsub -all {\)} $new_partial {\\)} new_partial
    regsub -all {\.} $new_partial {\\.} new_partial
    regsub -all {\[} $new_partial {\\[} new_partial



    set ttl 10
    set ttl 20

    regsub -all { } $new_partial {} new_partial



    if { $new_partial == "" } { 
	window.set_dabbrev_target ""
	window.set_dabbrev_matches ""
	window.set_dabbrev_current ""
        return
    }

    if { ([window.get_dabbrev_target] != "") &&
	 [string match -nocase "[window.get_dabbrev_target]*" $new_partial] } {


	 set l [window.get_dabbrev_matches]

         if { [lsearch -exact $args backward] != -1 } {
	     set last [lrange $l end end]
	     set l [lreplace $l end end]
	     set l [concat $last $l]
	 } else {
	     set first [lindex $l 0]
	     set l [lreplace $l 0 0]
	     lappend l $first
	 }
	 window.set_dabbrev_matches $l
	 window.set_dabbrev_current [lindex $l 0]
    } {

        set words [window.dabbrev_search .output $new_partial]

        if { [llength $words] == 0 } {
	    return
        }
        set words [lsort $words]
        if { [lindex $words 0] == [string tolower $new_partial] } {
	    set foo [lindex $words 0]
	    lappend words $foo
	    set words [lreplace $words 0 0]
        }
	window.set_dabbrev_target $new_partial
	window.set_dabbrev_matches $words
	window.set_dabbrev_current [lindex $words 0]
    }

    set remainder [string range [window.get_dabbrev_current] [string length [window.get_dabbrev_target]] end]

    .input delete "end - [string length $partial] char - 1 char" end

    .input insert end "[window.get_dabbrev_target]$remainder"
}

proc window.dabbrev_init {} {
    global dabbrev_db
    if { ![info exists dabbrev_db(initialised)] } {
	set dabbrev_db(initialised) 1
	window.set_dabbrev_target ""
	window.set_dabbrev_matches ""
	window.set_dabbrev_current ""
    }
}

proc window.set_dabbrev_target target {
    global dabbrev_db
    set dabbrev_db(target) $target
}
proc window.get_dabbrev_target {} {
    global dabbrev_db
    return $dabbrev_db(target)
}

proc window.set_dabbrev_matches matches {
    global dabbrev_db
    set dabbrev_db(matches) $matches
}
proc window.get_dabbrev_matches {} {
    global dabbrev_db
    return $dabbrev_db(matches)
}

proc window.set_dabbrev_current current {
    global dabbrev_db
    set dabbrev_db(current) $current
}
proc window.get_dabbrev_current {} {
    global dabbrev_db
    return $dabbrev_db(current)
}


proc window.selection_to_input {} {
    catch { .input insert insert [selection get] }
}

proc window.paste_selection {} {
    catch {
	set select [selection get]
	set length [string length $select]
        set select [string range $select 0 [expr $length -1]]
	incr length -1
	if { [string index $select $length] == "\n" } {
	    set select [string range $select 0 [expr $length -1]]
	}
	io.outgoing "@paste\n$select\n."
    }
}

proc window.clear_screen win {
    global window_db
    set window_db(".output,window_CR") 0
    $win configure -state normal
    $win delete 1.0 end
    $win configure -state disabled
}

proc window._last_char_is_visible {} {
    set last_char [.output index {end - 1 char}]
    if { [.output bbox $last_char] != {} } {
	return 1
    }
    return 0
}

set window_contributed_tags ""
proc window.contribute_tags tags {
    global window_contributed_tags
    set wct_list $window_contributed_tags
    foreach tag $tags {
	if { [lsearch -exact $wct_list $tag] == -1 } {
	    append window_contributed_tags " $tag"
	}
    }
    set window_contributed_tags [string trimleft $window_contributed_tags]
}

proc window.remove_matching_tags match {
    global window_contributed_tags
    set tmp ""
    set wct_list $window_contributed_tags
    foreach tag $wct_list {
	if { [string match $match $tag] == 0 } {
	    append tmp " $tag"
	}
    }
    set window_contributed_tags [string trimleft $tmp]
}

proc window.display_tagged { line {tags {}} } {
    global window_db
    if { $window_db(".output,window_CR") } {
	window._display "\n"
    } 
    set window_db(".output,window_CR") 1
    window._display $line

    foreach tag $tags {
	set names [lindex $tag 0]
	set range [lindex $tag 1]
	set from "end - 1 lines linestart + [lindex $range 0] chars"
	set to   "end - 1 lines linestart + [lindex $range 1] chars + 1 chars"
	foreach t $names {
            .output tag add $t $from $to
	}
    }
}

proc window._clip {} {
    global window_clip_output_buffer window_clip_output_buffer_size
    if { $window_clip_output_buffer } {
	set int_last_line [lindex [split [.output index end] "."] 0]
	set diff $int_last_line
	incr diff -$window_clip_output_buffer_size
	if { $diff > 0 } {
	    .output delete 1.0 $diff.0
	}
    }
}

proc window._display { line { tag ""} {win .output} } {
    if { $win == ".output" } {
        global window_contributed_tags
        set scroll [window._last_char_is_visible]

        .output configure -state normal
        .output insert end $line "window_margin $window_contributed_tags $tag"
        window._clip
        .output configure -state disabled

        if { $scroll } {
            .output yview -pickplace end
	    window.activity_stop_flashing
        } {
	    window.activity_begin_flashing
        }
    } {
        $win configure -state normal
        $win insert end $line "window_margin $tag"
        $win configure -state disabled
    }
}

proc window.display {{ line "" } { tag "" } {win .output}} {
    global window_db
    if { $window_db("$win,window_CR") } {
        window._display "\n" $win
    }
    set window_db("$win,window_CR") 0
    window._display $line $tag $win
}

proc window.displayCR {{ line "" } { tag "" } {win .output}} {
    global window_db
    if { $window_db("$win,window_CR") } {
        window._display "\n" $win
    }
    set window_db("$win,window_CR") 1
    window._display $line $tag $win
}

proc window.hyperlink.init {} {
    global window_hyperlink_db
    set window_hyperlink_db(command) ""
    set window_hyperlink_db(x) -1
    set window_hyperlink_db(y) -1
}

proc window.hyperlink.escape_tcl str {
    regsub -all {\\} $str {\\\\} str
    regsub -all {\;} $str {\\;} str
    regsub -all {\[} $str {\\[} str
    regsub -all {\$} $str {\\$} str
    return $str
}

proc window.hyperlink.activate {} {
    global window_hyperlink_db
    if { $window_hyperlink_db(command) != "" } {
        set cmd [window.hyperlink.escape_tcl $window_hyperlink_db(command)]
        eval $cmd
    }
}

proc window.hyperlink.set_command cmd {
    global window_hyperlink_db
    set window_hyperlink_db(command) $cmd
}

proc window.hyperlink.click {x y} {
    global window_hyperlink_db
    set window_hyperlink_db(x) $x
    set window_hyperlink_db(y) $y
}   

proc window.hyperlink.motion {win tag x y} {
    global window_hyperlink_db
    set colour_unselected #0000ee
    set hyperlink_foreground [worlds.get_generic $colour_unselected {} {} HyperlinkForeground]
    set delta 2 
    if { ([expr abs($window_hyperlink_db(x) - $x)] > $delta) || 
         ([expr abs($window_hyperlink_db(y) - $y)] > $delta) } {
        $win configure -cursor {}
        $win tag configure $tag -foreground $hyperlink_foreground
        window.hyperlink.set_command ""
    }
}

proc window.hyperlink.link {win tag cmd} {

    set cmd [window.hyperlink.escape_tcl $cmd]
    set colour_selected #ff0000
    set colour_unselected #0000ee

    set underline_hyperlink [worlds.get_generic hover {} {} UnderlineHyperlinks]
    set hyperlink_foreground [worlds.get_generic $colour_unselected {} {} HyperlinkForeground]

    if { $underline_hyperlink == "always" } {
	$win tag configure $tag -underline 1
    }

    $win tag configure $tag -foreground $hyperlink_foreground

    regsub -all {%} $cmd {%%} cmd  

    $win tag bind $tag <Enter> "
        $win configure -cursor hand2
	if { [lsearch -exact {hover always} $underline_hyperlink] != -1 } {
	    $win tag configure $tag -underline 1
	}
        window.hyperlink.set_command \"$cmd\"
    "
    $win tag bind $tag <Leave> "
        $win configure -cursor {}
	if { [lsearch -exact {hover never} $underline_hyperlink] != -1 } {
	    $win tag configure $tag -underline 0
	}
        window.hyperlink.set_command \"\"
    "
    $win tag bind $tag <1> "
        $win configure -cursor hand2
        $win tag configure $tag -foreground $colour_selected
        window.hyperlink.click %X %Y
        window.hyperlink.set_command \"$cmd\"
    "
    $win tag bind $tag <B1-Motion> "
        window.hyperlink.motion $win $tag %X %Y
    "
    $win tag bind $tag <B1-ButtonRelease> "
        $win tag configure $tag -foreground $hyperlink_foreground
        window.hyperlink.activate
    "

    $win tag lower $tag sel

    return $tag
}   
#
#





proc io.start {} {
    global io_output
    set io_output ""
}

proc io.outgoing line {
    set session ""
    catch {
    set session [db.get current session]
    }
    if { $session == "" } { return }
    set conn [db.get $session connection]
    if { $conn != "" } {
        puts $conn "$line"
        flush $conn
    }
}

proc io.receive_session-line session {
    set conn [db.get $session connection]

    if { $conn == "" } return
   

    set nchar -2	
    catch {set nchar [gets $conn line]}

    if { $nchar == -2 } {
	window.displayCR  "Connection timed out" window_highlight
	io.has_closed_session $session
        return
    }

    if { $nchar == -1 } {
        if { [eof $conn] } {
	    io.has_closed_session $session
            return
        }
	if { [fblocked $conn] } {
	    return
	}
	puts "io.receive-line: some error (I don't understand this fully)"
    }

    set event [util.unique_id event]
    db.set $event line $line
    db.set $event session $session
    client.incoming $event
}

proc io.receive-line {} {
    global io_output 

    if { $io_output == "" } return
   

    set nchar -2	
    catch {set nchar [gets $io_output line]}

    if { $nchar == -2 } {
	window.displayCR  "Connection timed out" window_highlight
	io.has_closed
        return
    }

    if { $nchar == -1 } {
        if { [eof $io_output] } {
	    io.has_closed
            return
        }
	if { [fblocked $io_output] } {
	    return
	}
	puts "io.receive-line: some error (I don't understand this fully)"
    }

    set event [util.unique_id event]
    db.set $event line $line
    client.incoming $event
}



set io_buffer ""

proc io.data_available_conn conn {
    return [fblocked $conn]
}
proc io.data_available {} {
    global io_output
    return [fblocked $io_output]
}


proc io.noCR {} {
    global io_noCR
    return $io_noCR
}

proc io.ensure_linemode { line } {
    global io_buffer io_buffer_returns
    if { [client.mode] == "line" } { return 0 }
    if { [io.noCR] == 1 } {
	set io_buffer_returns $line
	puts "io.ensure_linemode => 1"
	return 1
    }
    return 0
}

set io_noCR 0
proc io.read_buffer_session session {
    global io_output io_buffer io_noCR

    set buffer [db.get $session buffer]

    if { $buffer == "" } {
	return [list 0]
    }

    set conn [db.get $session connection]

    set first [string first "\n" $buffer]
    set io_noCR 0

    if { $first == -1 } {
	if { [io.data_available_conn $conn] == 1 } {
	    set io_noCR 1

	    set data $buffer
	    db.set $session buffer ""
	} {
	    return [list 0]
	}
    } {
	set data [string range $buffer 0 [expr $first - 1]]
	db.set $session buffer [string range $buffer [expr $first + 1] end]
    }
    return [list 1 $data]
}

set io_noCR 0
proc io.read_buffer {} {
    global io_output io_buffer io_noCR
    if { $io_buffer == "" } {
	return [list 0]
    }
    set first [string first "\n" $io_buffer]
    set io_noCR 0
    if { $first == -1 } {
	if { [io.data_available] == 1 } {
	    set io_noCR 1

	    set data $io_buffer
	    set io_buffer ""
	} {
	    return [list 0]
	}
    } {
	set data [string range $io_buffer 0 [expr $first - 1]]
	set io_buffer [string range $io_buffer [expr $first + 1] end]
    }
    return [list 1 $data]
}

proc io.receive_session-character session {
    global io_output io_buffer io_buffer_returns

    set conn [db.get $session connection]

    set data_size 100

    if { $conn == "" } { return }

    set buffer ""
    catch {
	set buffer [db.get $session buffer]
    }

    set data [read $conn $data_size]
    set buffer "$buffer$data"
    db.set $session buffer $buffer

    if { [eof $conn] == 1 } {
	io.has_closed
	return
    }


    set io_buffer_returns ""
    set data [io.read_buffer_session $session]
    while { [lindex $data 0] } {
	set line [lindex $data 1]
    
        set event [util.unique_id event]
        db.set $event line $line

        client.incoming $event
        set data [io.read_buffer_session $session]
    }
}

proc io.receive-character {} {
    global io_output io_buffer io_buffer_returns

    set data_size 100

    if { $io_output == "" } { return }

    set data [read $io_output $data_size]
    set io_buffer "$io_buffer$data"

    if { [eof $io_output] == 1 } {
	io.has_closed
	return
    }


    set io_buffer_returns ""
    set data [io.read_buffer]
    while { [lindex $data 0] } {
	set line [lindex $data 1]
    
        set event [util.unique_id event]
        db.set $event line $line

        client.incoming $event
        set data [io.read_buffer]
    }
}


proc io.receive_session session {
    io.receive_session-[client.mode] $session
}

proc io.receive {} {
    io.receive-[client.mode]
}



proc io.stop_session session {
    if { $session == "" } {
	return
    }
    set conn [db.get $session connection]
    if { $conn == "" } {
        return
    } 
    close $conn
    db.set $session connection ""
    client.client_disconnected_session $session
}

proc io.stop {} {
    global io_output
    if { $io_output == "" } {
        return;
    } 
    close $io_output
    set io_output ""
    client.client_disconnected
}

proc io.has_closed_session session {
    global io_output
    set conn [db.get $session connection]

    if { $conn != "" } {
        fileevent $conn readable ""
        set io_output ""
	db.set $session connection ""
	client.client_disconnected_session $session
    };
}

proc io.has_closed {} {
    global io_output

    if { $io_output != "" } {
        fileevent $io_output readable ""
        set io_output ""
	client.client_disconnected
    }
}

proc io.connect_session session {
    set host [db.get $session host]
    set port [db.get $session port]
    set conn ""
    catch { set conn [socket $host $port] }
    db.set $session connection $conn
    if { $conn != "" } {
	set current_session ""
	catch {
	set current_session [db.get current session]
	}
	if { $current_session != "" } {

            set this_world ""
            catch { set this_world [db.get $current_session world] }
            worlds.set_current $this_world

            client.disconnect_session $current_session

            set next_world ""
            catch { set next_world [db.get $session world] }
            worlds.set_current $next_world

	}
	io.set_connection $conn
        fconfigure $conn -blocking 0
        fileevent $conn readable "io.receive_session $session"

	client.client_connected_session $session
	return 0
    } {
        io.host_unreachable $host $port
	return 1
    }
}


proc io.connect { host port } {
    set conn ""
    catch { set conn [socket $host $port] }
    if { $conn != "" } {

        set current_world [worlds.get_current]
	io.disconnect
        worlds.set_current $current_world

	io.set_connection $conn
        fconfigure $conn -blocking 0
        fileevent $conn readable {io.receive}
	client.client_connected
	return 0
    } {
        io.host_unreachable $host $port
	return 1
    }
}

proc io.disconnect_session session {
    io.stop_session $session
}

proc io.disconnect {} {
    io.stop
}

proc io.set_connection {{conn ""}} {
    global io_output
    set io_output $conn
}


proc io.host_unreachable { host port } {
    client.host_unreachable $host $port
}
#
#

set util_unique_id 0

proc util.unique_id token {
    global util_unique_id
    incr util_unique_id
    return "$token$util_unique_id"
}

proc util.populate_array { array text } {
    upvar $array a
    set keyword ""

    foreach item $text {
        if { $keyword != "" } {
            set a($keyword) $item
            set keyword "" 
        } {     
            set keyword $item
            regsub ":" $keyword "" keyword
        }       
    }
}       

proc util._populate_array { array text } {
    upvar $array a
    set keyword ""

    set space [string first " " $text]
    set item [string range $text 0 [expr $space - 1]]
    set text [string range $text [expr $space + 1] end]

    while { $item != "" } {

        if { $keyword != "" } {
            set a($keyword) $item
            set keyword "" 
        } {     
            set keyword $item
            regsub ":" $keyword "" keyword
        }       

        set space [string first " " $text]
        set item [string range $text 0 [expr $space - 1]]
        set text [string range $text [expr $space + 1] end]
    }
    set a($keyword) $text
}       


proc util.version {} {
    global tkmooVersion
    return $tkmooVersion
}

proc util.buildtime {} {
    global tkmooBuildTime
    return $tkmooBuildTime
}

proc util.eight {} {
    global tcl_version
    if { $tcl_version >= 8.0 } {
        return 1
    }
    return 0
}


proc util.slice { list { n 0 } } {
    set tmp {}
    foreach item $list {
        lappend tmp [lindex $item $n]
    }
    return $tmp
}

proc util.assoc { list key { n 0 } } {
    foreach item $list {
        if { [lindex $item $n] == $key } {
            return $item
        }
    }
    return {}
}
#
#

client.register worlds start
client.register worlds stop

proc worlds.start {} {
    global worlds_worlds
    set worlds_worlds {}

    worlds.create_default_file

    worlds.load

    set current [worlds.get_current]
    if { $current != "" } {
	worlds.unset $current IsCurrentWorld
    }

    set file [worlds.file]
    worlds.update_mtime $file
}

proc worlds.stop {} {
    if { [worlds.save_needed] == 1 } {
        worlds.save
    }
}

proc worlds.get_generic { hardcoded option optionClass directive {which ""}} {
    set value $hardcoded
    catch {
        set d ""
        set default [worlds.get_default $directive]
        if { $default != {} } { set d [lindex $default 0] }
        if { $d != "" } { set value $d }
    }
    if { $option != {} && $optionClass != {} } {
        set o [option get . $option $optionClass]
        if { $o != "" } { set value $o }
    }
    if { $which == "" } {
        catch { set value [worlds.get [worlds.get_current] $directive] }
    } {
        catch { set value [worlds.get $which $directive] }
    }
    return $value
}

set worlds_default_tkm "
World: DEFAULT WORLD
IsDefaultWorld: 1
ConnectScript: connect %u %p

World: Localhost
Host: 127.0.0.1
Port: 7777
ShortList: On

World: JHM
Host: jhm.moo.mud.org
Port: 1709
ShortList: On

World: Diversity University
Host: moo.du.org
Port: 8888
ShortList: On 
"

proc worlds.default_tkm {} {
    global worlds_default_tkm
    return [split $worlds_default_tkm "\n"]
}

proc worlds.preferred_file {} {
    global tcl_platform env tkmooLibrary

    set dirs {}
    switch $tcl_platform(platform) {
	windows { 
	    set file worlds.tkm
            if { [info exists env(TKMOO_LIB_DIR)] } {
                lappend dirs [file join $env(TKMOO_LIB_DIR)]
            }
            if { [info exists env(HOME)] } {
                lappend dirs [file join $env(HOME) tkmoo]
            }
            lappend dirs [file join $tkmooLibrary]
	}
	unix -
	default { 
	    set file worlds.tkm
            if { [info exists env(TKMOO_LIB_DIR)] } {
                lappend dirs [file join $env(TKMOO_LIB_DIR)]
            }
            if { [info exists env(HOME)] } {
                lappend dirs [file join $env(HOME) .tkMOO-lite]
            }
            lappend dirs [file join $tkmooLibrary]
        }
    }

    foreach dir $dirs {
        if { [file exists $dir] &&
             [file isdirectory $dir] &&
             [file writable $dir] } {
            return [file join $dir $file]
        }
    }
    
    return [file join [pwd] $file]
}

proc worlds.file {} {
    global tkmooLibrary tcl_platform env

    set files {}

    switch $tcl_platform(platform) {
	windows {
            lappend files [file join [pwd] worlds.tkm]
            lappend files [worlds.preferred_file]
	}
	unix -
	default {
            lappend files [file join [pwd] worlds.tkm]
            lappend files [worlds.preferred_file]
	}
    }

    foreach file $files {
        if { [file exists $file] } {
	    return $file
        }
    }

    return ""
}

set worlds_last_read 0

proc worlds.update_mtime file {
    global worlds_last_read
    if { [catch { set mtime [file mtime $file] }] != 0 } {
	return
    }
    set worlds_last_read $mtime
}

proc worlds.file_changed file {
    global worlds_last_read
    if { [catch { set mtime [file mtime $file] }] != 0 } {
	window.displayCR "Can't stat file (.file_changed) $file" window_highlight
	return
    }
    if { $mtime != $worlds_last_read } {
        return 1
    } {
        return 0
    }
}

proc worlds.read_worlds file {
    set tmp {}
    set worlds_file ""
    catch { set worlds_file [open $file "r"] }
    if { $worlds_file == "" } {
	window.displayCR "Can't read file $file" window_highlight
	return $tmp
    }
    while { [gets $worlds_file line] != -1 } {
	lappend tmp $line
    }
    close $worlds_file
    return $tmp
}

proc worlds.new_world {} {
    return [util.unique_id world]
}

proc worlds.load {} {
    global worlds_worlds worlds_worlds_db tkmooLibrary

    set file [worlds.file]

    if { $file != "" } {
        if { [worlds.file_changed $file] == 0 } {
	    return 0
	} 
	set worlds_lines [worlds.read_worlds $file]
	worlds.update_mtime $file
    } {
	set worlds_lines [worlds.default_tkm]
    }

    catch { unset worlds_worlds_db }
    set worlds_worlds {}
    set index [worlds.new_world]

    set new_worlds [worlds.apply_lines $worlds_lines]
    if { $new_worlds != {} } {
	set worlds_worlds [concat $worlds_worlds $new_worlds]
    }

    worlds.make_default_world

    window.post_connect

    worlds.untouch

    return 1
}

proc worlds.apply_lines lines {
    global worlds_worlds_db
    set new_worlds {}
    foreach line $lines {
        if { [regexp {^ *#} $line] == 1 } {
	    continue
        }
	if { [regexp {^([^:]+): (.*)} $line _ key value] == 1 } {
            set lkey [string tolower $key]
	    if { $lkey == "world" } {
	        set world $value
                set index [worlds.new_world]
		lappend new_worlds $index
		worlds.set $index Name $world
            } {
	        if { [info exists worlds_worlds_db($index:$lkey)] } {
	            worlds.set $index $key "[worlds.get $index $key]\n$value"
		} {
		    worlds.set $index $key $value
		}
	    }
	}
    }
    return $new_worlds
}

proc worlds.create_default_file {} {
    global tcl_platform
    set file [worlds.file]
    if { $file != "" } {
	return
    }

    set file [worlds.preferred_file]

    set fd ""
    catch { set fd [open $file "w+"] }
    if { $fd == "" } {
	window.displayCR "Can't write to file $file" window_highlight
	return
    }


    puts $fd "# $file"
    puts $fd "# This file is created automatically by the preferences editor"
    puts $fd "# any changes you make by hand to this file will be lost."

    foreach line [worlds.default_tkm] {
	puts $fd $line
    }
    close $fd
    if { $tcl_platform(platform) == "unix" } {
        file attributes $file -permissions "rw-------"
    }
}


proc worlds.save {} {
    global worlds_worlds_db

    set file [worlds.file]
    if { $file == "" } {
        set file [worlds.preferred_file]
    }

    set worlds [worlds.worlds]

    set directives {}
    foreach key [array names worlds_worlds_db] {
	set wd [split $key ":"]
	set d [lindex $wd 1]
	if { $d == "name" } { continue }
	set all_used_directives($d) 1
    }
    catch { set directives [array names all_used_directives] }



    foreach d $directives {
        set get_directive [preferences.get_directive $d]
	set default_if_empty($d)      [util.assoc $get_directive default_if_empty]
	set directive_type($d)        [lindex [util.assoc $get_directive type] 1]
        set directive_has_default($d) [worlds.get_default $d]
    }

    set the_default_world [worlds.default_world]

    set fd ""
    catch { set fd [open $file "w+"] }
    if { $fd == "" } {
	window.displayCR "Can't write to file $file" window_highlight
	return
    }


    puts $fd "# $file"
    puts $fd "# This file is created automatically by the preferences editor"
    puts $fd "# any changes you make by hand to this file will be lost."


    foreach world $worlds {



	if { [info exists worlds_worlds_db($world:mustnotsave)] } {
	    continue
	}


	puts $fd "# ----"
	puts $fd "World: $worlds_worlds_db($world:name)"


        foreach directive $directives {
	    if { [info exists worlds_worlds_db($world:$directive)] } {


		if { ($worlds_worlds_db($world:$directive) == {}) &&
		     ($default_if_empty($directive) != {}) } {
		     continue
		}


                set has_default $directive_has_default($directive)
		if { ($world != $the_default_world) && ($has_default != {}) } {

		    set db 	$worlds_worlds_db($world:$directive)
		    set default [lindex $has_default 0]

		    set type $directive_type($directive)

		    if { $type == "boolean" } {
		        set db      [string tolower $db]
		        set default [string tolower $default]
		    }



		    if { $db == $default } {
		         continue
		    }
		}


		#
		set lines [split $worlds_worlds_db($world:$directive) "\n"]

		if { [llength $lines] > 1 } {



		    set last [lindex [lrange $lines end end] 0]


		    if { $last == {} } {
			set lines [lrange $lines 0 [expr [llength $lines] - 2]]
		    } {
		    }


		    foreach line $lines {

		            puts $fd "$directive: $line"

		    }
		} {
		    puts $fd "$directive: $worlds_worlds_db($world:$directive)"
		}
	    }
        }
    }
    close $fd
    window.post_connect
}

proc worlds.sync {} {
    worlds.save
    worlds.load
}

proc worlds.worlds { } {
    global worlds_worlds
    return $worlds_worlds
}

proc worlds.touch {} {
    global worlds_save_needed
    set worlds_save_needed 1
}

proc worlds.untouch {} {
    global worlds_save_needed
    set worlds_save_needed 0
}

proc worlds.save_needed {} {
    global worlds_save_needed
    return $worlds_save_needed
}

proc worlds.get { world key } {
    global worlds_worlds_db
    return $worlds_worlds_db($world:[string tolower $key])
}

#

proc worlds.get_default directive {
    set default [util.assoc [preferences.get_directive $directive] default]
    if { $default != {} } {
        set default [list [lindex $default 1]]
    }
    catch { set default [list [worlds.get [worlds.default_world] $directive]] }
    return $default
}

proc worlds.set_if_different { world key { value NULL }} {
    if { [catch {set v [worlds.get $world $key]}] ||
        $v != $value } {
        worlds.set $world $key $value
    }
}

proc worlds.set { world key { value NULL }} {
    global worlds_worlds_db
    if { ($value == {}) &&
         ([util.assoc [preferences.get_directive $key] default_if_empty] != {}) } {
        catch { unset worlds_worlds_db($world:[string tolower $key]) }
    } {
        set worlds_worlds_db($world:[string tolower $key]) $value
    }
    if { [string tolower $key] != "iscurrentworld" } {
        worlds.touch
    }
}

proc worlds.unset { world key } {
    global worlds_worlds_db
    catch { unset worlds_worlds_db($world:[string tolower $key]) }
    if { [string tolower $key] != "iscurrentworld" } {
        worlds.touch
    }
}

proc worlds.copy {world copy} {
    global worlds_worlds_db



    foreach key [array names worlds_worlds_db "$world:*"] {
	regsub "^$world:" $key {} param
	if { $param == "mustnotsave" } {
	    continue
	}
        set worlds_worlds_db($copy:$param) $worlds_worlds_db($key)
    }

    worlds.touch

    return $copy
}


proc worlds.delete world {
    global worlds_worlds_db worlds_worlds
    set index [lsearch -exact $worlds_worlds $world]
    if { $index != -1 } {
	set worlds_worlds [lreplace $worlds_worlds $index $index]
	foreach key [array names worlds_worlds_db "$world:*"] {
            unset worlds_worlds_db($key)
	}
        worlds.touch
    }
}

proc worlds.create_new_world {} {
    global worlds_worlds
    set world [worlds.new_world]
    lappend worlds_worlds $world
    worlds.touch
    return $world
}

proc worlds.get_current {} {
    global worlds_worlds
    foreach world $worlds_worlds {
	set is_current 0
	catch { set is_current [worlds.get $world IsCurrentWorld] }
	if { $is_current } {
	    return $world
	}
    }
    return ""
}

proc worlds.set_current world {
    set current [worlds.get_current]
    if { $current != "" } {
	worlds.unset $current IsCurrentWorld
    }
    if { $world != "" } {
        worlds.set $world IsCurrentWorld 1
    }
}

#

proc worlds.set_special {world directive {value 1}} {
    while { [set special [worlds.get_special $directive $value]] != "" } {
	worlds.unset $special $directive
    }
    worlds.set $world $directive $value
}

proc worlds.get_special {directive {value 1}} {
    global worlds_worlds
    foreach world $worlds_worlds {
	set is_special 0
	if { $value == 0 } {
	    set is_special 1
	}
	catch { set is_special [worlds.get $world $directive] }
	if { $is_special == $value } {
	    return $world
	}
    }
    return ""
}

proc worlds.match_world expr {
    global worlds_worlds
    set tmp {}
    foreach world $worlds_worlds {
	if { [string match $expr [worlds.get $world Name]] == 1 } {
	    lappend tmp $world
	}
    }
    return $tmp
}

proc worlds.default_world {} {
    global worlds_worlds
    foreach world $worlds_worlds {
	set default -1
	catch { set default [worlds.get $world IsDefaultWorld] }
	if { $default == 1 } {
            return $world
	}
    }
    return -1
}

proc worlds.make_default_world {} {
    if { [worlds.default_world] == -1 } {
	set world [worlds.create_new_world]
	worlds.set $world IsDefaultWorld 1
	worlds.set $world Name "DEFAULT WORLD"
	worlds.set $world ConnectScript "connect %u %p"
    }
}


## This is the little screwy editor window
##

client.register edit start
proc edit.start {} {
    global edit_functions
    set edit_functions [list]
    window.menu_tools_add "Editor" {edit.SCedit {} {} {} "Editor" "Editor"} "[window.accel Ctrl]+E"
    bind . <Command-e> {edit.SCedit {} {} {} "Editor" "Editor"}
    global edit_file_matches
    set edit_file_matches [list]
}

proc edit.register { event callback {priority 50} } {
    global edit_registry
    lappend edit_registry($event) [list $priority $callback]
}

proc edit.dispatch { win event args } {
    global edit_registry
    if { [info exists edit_registry($event)] } {
        foreach record [lsort -command edit.sort_registry $edit_registry($event)] {
            eval [lindex $record 1] $win $args
        }
    }
}

proc edit.sort_registry { a b } {
    return [expr [lindex $a 0] - [lindex $b 0]]
}

#


proc edit.add_file_match { title extensions {mactype {}} } {
    global edit_file_matches
    if { $mactype == {} } {
        lappend edit_file_matches [list $title $extensions $mactype]
    } {
        lappend edit_file_matches [list $title $extensions]
    }
}

proc edit.add_toolbar {editor toolbar} {
    global edit_toolbars
    if { [lsearch -exact $edit_toolbars($editor) $toolbar] == -1 } {
        lappend edit_toolbars($editor) $toolbar
    }
 }
proc edit.remove_toolbar {editor toolbar} {
    global edit_toolbars
    set index [lsearch -exact $edit_toolbars($editor) $toolbar]
    if { $index != -1 } {
        set edit_toolbars($editor) [lreplace $edit_toolbars($editor) $index $index]
    }
}   

proc edit.add_edit_function {title callback} {
    global edit_functions
    lappend edit_functions [list $title $callback]
}

proc edit.set_text { e lines } {
    set CR ""
    foreach line $lines {
        $e.t insert end "$CR$line"
	set CR "\n"
    }
}

proc edit.get_text e { 
    set lines {}
    set last [$e.t index end]
    for {set n 1} {$n < $last} {incr n} {
        set line [$e.t get "$n.0" "$n.0 lineend"]
        lappend lines $line
    }   
    return $lines
}

proc edit.SCedit { pre lines post title icon_title {e ""}} {
    if { $e == "" } {
        set e [edit.create $title $icon_title]
    }

    if { $pre == "" } {
	if { $post == "" } {
	    set data $lines
	} {
	    set data [concat $lines [list $post]]
	}
    } {
	if { $post == "" } {
	    set data [concat [list $pre] $lines]
	} {
	    set data [concat [list $pre] $lines [list $post]]
	}
    }

    wm title $e $title
    wm iconname $e $icon_title

    edit.set_text $e $data

    $e.t mark set insert 1.0
    edit.show_line_number $e

    focus $e.t

    set from 1.0
    set to [$e.t index end]
    edit.dispatch $e load [list [list range [list $from $to]]]

    return $e
}

proc edit.destroy e {
    global edit_db

    foreach record [array names edit_db "$e,*" ] {
        unset edit_db($record)
    }

    destroy $e
}

proc edit.set_type { e type } {
    global edit_db
    set edit_db($e,type) $type
}

proc edit.get_type e {
    global edit_db
    if { [info exists edit_db($e,type)] } {
        return $edit_db($e,type)
    } {
        return ""
    }
}


proc edit.fs_set_current_filename {e filename} {
    global edit_db
    set edit_db($e,filename) $filename
}

proc edit.fs_get_current_filename e {
    global edit_db
    if { [info exists edit_db($e,filename)] } {
        return $edit_db($e,filename)
    }
    return ""
}

proc edit.fs_open e {
    global edit_file_matches
    set filetypes { 
	{{Text Files} {.txt} TEXT} 
	{{All Files} {*} TEXT} 
    }
    if { $edit_file_matches != {} } {
	set filetypes [concat $filetypes $edit_file_matches]
    }
    set initialdir [pwd]
    set initialfile ""
    set display "Select text file to open"
    set filename [tk_getOpenFile -filetypes $filetypes \
                                 -initialdir $initialdir \
                                 -initialfile $initialfile \
				 -parent $e \
                                 -title "$display"]

    if { $filename == "" } {
	return;
    }

    edit.fs_set_current_filename $e $filename


    set tmp {}
    set fh ""
    catch { set fh [open $filename "r"] }
    if { $fh == "" } {
        window.displayCR "Can't open $filename..." window_highlight
        return
    }

    while { [gets $fh line] != -1 } {
        lappend tmp $line
    }
    close $fh

    $e.t delete 1.0 end

    set CR ""
    foreach line $tmp {
        $e.t insert insert "$CR$line"
        set CR "\n"
    }

    $e.t mark set insert 1.0
    edit.show_line_number $e
}

proc edit.fs_save e {
    set filename [edit.fs_get_current_filename $e]
    if { $filename == "" } {
	edit.fs_save_as $e
	return
    }

    set tmp {}
    set len [lindex [split [$e.t index end] "." ] 0]
    for {set i 1} {$i < $len} {incr i} {
	set line [$e.t get "$i.0" "$i.0 lineend"]
	lappend tmp $line
    }

    set fh ""
    catch { set fh [open $filename "w"] }
    if { $fh == "" } {
        window.displayCR "Can't open $filename..." window_highlight
        return
    }

    set CR ""
    foreach line $tmp {
        puts -nonewline $fh "$CR$line"
	set CR "\n"
    }
    close $fh

}

proc edit.fs_save_as e {
    global edit_file_matches
    set filetypes { 
	{{Text Files} {.txt} TEXT} 
	{{All Files} {*} TEXT} 
    }
    if { $edit_file_matches != {} } {
	set filetypes [concat $filetypes $edit_file_matches]
    }
    set file [edit.fs_get_current_filename $e]
    if { $file == "" } {
	set initialdir [pwd]
	set initialfile ""
    } {
	set initialdir [file dirname $file]
	set initialfile [file tail $file]
    }
    set display "Select text file to save"
    set filename [tk_getSaveFile -filetypes $filetypes \
                                 -initialdir $initialdir \
                                 -initialfile $initialfile \
				 -parent $e \
                                 -title "$display"]
    if { $filename == "" } {
	return
    }

    set tmp {}
    set len [lindex [split [$e.t index end] "." ] 0]
    for {set i 1} {$i < $len} {incr i} {
	set line [$e.t get "$i.0" "$i.0 lineend"]
	lappend tmp $line
    }

    set fh ""
    catch { set fh [open $filename "w"] }
    if { $fh == "" } {
        window.displayCR "Can't open $filename..." window_highlight
        return
    }

    set CR ""
    foreach line $tmp {
        puts -nonewline $fh "$CR$line"
	set CR "\n"
    }
    close $fh

    edit.fs_set_current_filename $e $filename
}

proc edit.create { title icon_title } {
    global tkmooLibrary

    global edit_toolbars

    ### something like...

    set w .[util.unique_id "e"]

    set edit_toolbars($w) {}

    toplevel $w
    #PLG:TODO window.configure_for_macintosh $w

    window.place_nice $w

    $w configure -bd 0 -highlightthickness 0

    wm title $w $title
    wm iconname $w $icon_title

    menu $w.controls -tearoff 0 -relief raised -bd 1
    $w configure -menu $w.controls

    ## add the File menu
    #
    $w.controls add cascade -label "File" -menu $w.controls.file -underline 0
    menu $w.controls.file -tearoff 0

    $w.controls.file add command -label "Open..." -underline 0 -command "edit.fs_open $w"
	window.hidemargin $w.controls.file

    $w.controls.file add command -label "Save" -underline 0 -command "edit.fs_save $w" -accelerator "[window.accel Ctrl]+S"
	window.hidemargin $w.controls.file

    $w.controls.file add command -label "Save As..." -underline 5 -command "edit.fs_save_as $w"
	window.hidemargin $w.controls.file

    $w.controls.file add separator
	window.hidemargin $w.controls.file

    #PLG $w.controls.file add command -label "Send" -underline 1 -command "edit.send $w" -accelerator "[window.accel Ctrl]+E"
    # This is bullshit... it gets filled in later, by ....
    #  - proc macmoose.invoke_verb_editor
    #  - proc macmoose.do_prop_info
    #
    # WARNING!!! the order of the "File" menu here is also directly related to the function above in the
    # sense that the entry fields are HARDCODED into the functions!
    #
    $w.controls.file add command -label "Send" -accelerator "Cmd+D"
    window.hidemargin $w.controls.file

    #PLG $w.controls.file add command -label "Send and Close" -underline 10 -command "edit.send_and_close $w" -accelerator "[window.accel Ctrl]+L"
    $w.controls.file add command -label "Send and Close" -accelerator "Cmd+L"
    window.hidemargin $w.controls.file

    $w.controls.file add command -label "Close" -underline 0 -command "edit.destroy $w" -accelerator "[window.accel Ctrl]+W"
	bind $w <Command-w> "edit.destroy $w"
    window.hidemargin $w.controls.file

    $w.controls add cascade -label "Edit" -menu $w.controls.edit -underline 0

    menu $w.controls.edit -tearoff 0

    $w.controls.edit add command -label "Cut" -accelerator "[window.accel Ctrl]+X" -command "edit.do_cut $w"
	window.hidemargin $w.controls.edit
    $w.controls.edit add command -label "Copy" -accelerator "[window.accel Ctrl]+C" -command "edit.do_copy $w"
	window.hidemargin $w.controls.edit
    $w.controls.edit add command -label "Paste" -accelerator "[window.accel Ctrl]+V" -command "edit.do_paste $w"
	window.hidemargin $w.controls.edit

    global edit_functions
    if { $edit_functions != {} } {
    	$w.controls.edit add separator
    	window.hidemargin $w.controls.edit
    	foreach function $edit_functions {
    	    set title [lindex $function 0]
    	    set callback [lindex $function 1]
    	    $w.controls.edit add command -label "$title" -command "$callback $w"
    	    window.hidemargin $w.controls.edit
    	}
    }

    ## add the View menu 
    #
    $w.controls add cascade -label "View" -menu $w.controls.view -underline 0
    menu $w.controls.view -tearoff 0

    $w.controls.view add command -label "Find" -underline 0 -command "edit.find $w" -accelerator "[window.accel Ctrl]+F"
    bind $w <Command-f> "edit.find $w"
	window.hidemargin $w.controls.view

    $w.controls.view add command -label "Goto" -underline 0 -command "edit.goto $w" -accelerator "[window.accel Ctrl]+G"
    bind $w <Command-g> "edit.goto $w"
	window.hidemargin $w.controls.view

    ## add the Window menu
    #
    $w.controls add cascade -label "Window" -menu $w.controls.windows -underline 0
    menu $w.controls.windows -tearoff 0

    $w.controls.windows add separator
    window.hidemargin $w.controls.windows

    $w.controls.windows add command -label "Root" -underline 0 -command "window.focus .input" -accelerator "[window.accel Ctrl]+0"
    bind $w <Command-0> "window.focus .input"
    window.hidemargin $w.controls.windows

    $w.controls.windows add command -label "Object" -underline 0 -command "" -accelerator "[window.accel Ctrl]+O"
    #PLG:TODO bind $w <Command-O> "window.focus .input"
    window.hidemargin $w.controls.windows

    ## manipulate the text output called .t

    #PLG window size
    text $w.t -font [fonts.fixedwidth] -height 35 -width 110 -yscrollcommand "$w.scrollbar set" -highlightthickness 0 -setgrid true

    scrollbar $w.scrollbar -command "$w.t yview" -highlightthickness 0
    window.set_scrollbar_look $w.scrollbar

    label $w.position -bd 2 -relief groove -text "position: 1.0" -anchor e

    bind $w.t <KeyPress> 	"after idle edit.show_line_number $w"
    bind $w.t <KeyRelease> 	"after idle edit.show_line_number $w"
    bind $w.t <ButtonPress> 	"after idle edit.show_line_number $w"
    bind $w.t <ButtonRelease> 	"after idle edit.show_line_number $w"

    bind $w.t <Control-v>	"edit.do_paste $w; break"

    edit.repack $w

    return $w
}

proc edit.repack editor {
    global edit_toolbars

    set slaves [pack slaves $editor]

    if { $slaves != "" } {
	eval pack forget $slaves
    }

    window.pack_for_macintosh $editor

    foreach toolbar $edit_toolbars($editor) {
	pack $editor.$toolbar -side top -fill x
    }

    pack $editor.position -fill x -side bottom
    pack $editor.scrollbar -side right -fill y
    pack $editor.t -side left -expand 1 -fill both
}

proc edit.show_line_number w {
    if { [winfo exists $w] == 0 } { return }
    set line_number [$w.t index insert]
    $w.position configure -text "position: $line_number"
}

proc edit.old.show_line_number w {
    set line_number [$w.t index insert]
    $w.controls.line configure -text "position: $line_number"
}


proc edit.dot_quote_line line {
    if { $line == "." } { return ".." };
    return $line
}

proc edit.dot_quote_lines lines {
    set tmp {}
    foreach line $lines {
	lappend tmp [edit.dot_quote_line $line]
    }
    return $tmp
}


proc edit.send w {
    set last [$w.t index end]
    for {set n 1} {$n < $last} {incr n} {
        set line [$w.t get "$n.0" "$n.0 lineend"]
        io.outgoing $line
    }
}

proc edit.send_and_close w {
    set last [$w.t index end]
    for {set n 1} {$n < $last} {incr n} {
        set line [$w.t get "$n.0" "$n.0 lineend"]
        io.outgoing $line
    }
    edit.destroy $w
}

proc edit.configure_send { e label command {underline 0} } {
    $e.controls.file entryconfigure "Send" -label $label -command $command -underline $underline
    bind $e <Command-d> $command
}

proc edit.configure_send_and_close { e label command {underline 0} } {
    $e.controls.file entryconfigure "Send and Close" -label $label -command $command -underline $underline
    bind $e <Command-l> $command
}

proc edit.configure_close { e label command {underline 0} } {
    $e.controls.file entryconfigure "Close" -label $label -command $command -underline $underline
    bind $e <Command-w> $command
}

###

proc edit.find w {
    set f $w.find

    if { [winfo exists $f] == 0 } {
        toplevel $f
    
    	#PLG window.configure_for_macintosh $f

    	window.bind_escape_to_destroy $f

    	window.place_nice $f $w

        $f configure -bd 0 -highlightthickness 0

        wm title $f "Find and Replace"
        wm iconname $f "Find and Replace"
        frame $f.t -bd 0 -highlightthickness 0
            label $f.t.l -text "Find:" -width 8 -anchor w
            entry $f.t.e -width 40 \
	        -font [fonts.fixedwidth]
            pack $f.t.l -side left
            pack $f.t.e -side right

        frame $f.m -bd 0 -highlightthickness 0
            label $f.m.l -text "Replace:" -width 8 -anchor w
            entry $f.m.e -width 40 \
	        -font [fonts.fixedwidth]
            pack $f.m.l -side left
            pack $f.m.e -side right
    
        frame $f.b -bd 0 -highlightthickness 0
            button $f.b.ffind -text "Find >" -command "edit.do_find $w forwards"
            button $f.b.bfind -text "< Find" -command "edit.do_find $w backwards"
            button $f.b.replace -text "Replace" -command "edit.do_replace $w"
            button $f.b.replacea -text "Replace all" -command "edit.do_replace_all $w"
            button $f.b.close -text "Close" -command "destroy $f"

            pack $f.b.ffind $f.b.bfind $f.b.replace $f.b.replacea $f.b.close \
		-side left -padx 5 -pady 5
    
        pack $f.t -side top -fill x
        pack $f.m -side top -fill x
        pack $f.b -side bottom 
    }

    after idle "wm deiconify $f; window.focus $f.t.e"

    $f.t.e delete 0 end
    catch {$f.t.e insert 0 [selection get]}
}

proc edit.do_find { w direction } {
    set string [$w.find.t.e get]
    if { $string == "" } {
	return 0
    }


    switch $direction {
	forwards {
	    set from [$w.t index "insert + 1 char"]
	}
	backwards {
	    set from [$w.t index "insert - 1 char"]
	}
    }

    set psn [$w.t search -$direction -count length -- $string $from]
    if {$psn != ""} {
        $w.t tag remove sel 0.0 end
	tkTextSetCursor $w.t $psn
        $w.t tag add sel $psn "$psn + $length char"
        edit.show_line_number $w
	return 1
    }
    return 0
}

proc edit.do_replace w {
    set string [$w.find.m.e get]
    catch {
	tk_textCut $w.t
	$w.t insert insert $string
    }
}

proc edit.do_replace_all w {
    set find [$w.find.t.e get]
    set replace [$w.find.m.e get]

    if { $find == $replace } { return }

    $w.t mark set edit_URHERE insert 
    $w.t mark gravity edit_URHERE left

    set lreplace [string length $replace]

    set psn "0.0"
    while { [set psn [$w.t search -forwards -count length -- $find $psn end]] != "" } {
	$w.t tag remove sel 0.0 end
	tkTextSetCursor $w.t $psn
	$w.t tag add sel $psn "$psn + $length char"
	edit.do_replace $w
	set psn [$w.t index "$psn + $lreplace char"]
    }

    $w.t mark set insert edit_URHERE
    $w.t mark unset edit_URHERE

    $w.t see insert

    edit.show_line_number $w
}

###

proc edit.goto w {
    set f $w.goto


    if { [winfo exists $f] == 0 } {
        toplevel $f
	window.configure_for_macintosh $f

	window.bind_escape_to_destroy $f

	window.place_nice $f $w

        $f configure -bd 0 -highlightthickness 0

        wm title $f "Goto Line Number"
        wm iconname $f "Goto Line"
        frame $f.t -bd 0 -highlightthickness 0
            label $f.t.l -text "Line Number:"
            entry $f.t.e -font [fonts.fixedwidth]
            pack $f.t.l -side left
            pack $f.t.e -side right

        frame $f.b -bd 0 -highlightthickness 0
	    button $f.b.goto -text "Goto" -command "edit.do_goto $w"
            button $f.b.close -text "Close" -command "destroy $f"

            pack $f.b.goto $f.b.close -side left \
		-padx 5 -pady 5

        pack $f.t -side top -fill x
        pack $f.b -side bottom 

        bind $f <Return> "edit.do_goto $w"
    }

    after idle "wm deiconify $f; window.focus $f.t.e"

    $f.t.e delete 0 end
    catch {$f.t.e insert 0 [selection get]}
}

proc edit.do_goto w {
    set string [$w.goto.t.e get]
    if { $string == "" } {
	return
    }
    catch { tkTextSetCursor $w.t $string.0 }
    destroy $w.goto
    edit.show_line_number $w
}

###

proc edit.do_cut w {
    if { [lsearch -exact [$w.t tag names] sel] != -1 } {
    set from [$w.t index sel.first]
    }
    ui.delete_selection $w.t
}
proc edit.do_copy w {
    ui.copy_selection $w.t
}
proc edit.do_paste w {
    set from [$w.t index insert]
    ui.paste_selection $w.t
    set to [$w.t index insert]
    edit.dispatch $w load [list [list range [list $from $to]]]
}
#
#

proc initapi.rcfile {} {
    global tcl_platform env

    set files {}
    switch $tcl_platform(platform) {
        macintosh {
            lappend files [file join [pwd] tkMOO-light.RC]
	    if { [info exists env(PREF_FOLDER)] } {
                lappend files [file join $env(PREF_FOLDER) tkMOO-light.RC]
	    }
        }
        windows {
	    lappend files [file join [pwd] tkmoo.res]
	    if { [info exists env(TKMOO_LIB_DIR)] } {
                lappend files [file join $env(TKMOO_LIB_DIR) tkmoo tkmoo.res]
	    }
	    if { [info exists env(HOME)] } {
                lappend files [file join $env(HOME) tkmoo tkmoo.res]
	    }
        }
        unix -
        default {
            lappend files [file join [pwd] .tkmoolightrc]
	    if { [info exists env(TKMOO_LIB_DIR)] } {
                lappend files [file join $env(TKMOO_LIB_DIR) .tkmoolightrc]
	    }
	    if { [info exists env(HOME)] } {
                lappend files [file join $env(HOME) .tkmoolightrc]
	    }
        }
    }

    foreach file $files {
        if { [file exists $file] } {
            return $file
        }
    }
    
    return ""
}

default.options

set rcfile [initapi.rcfile]

if { ($rcfile != "") && [file readable $rcfile] } {
    option readfile $rcfile userDefault
}

window.buildWindow
#
#


proc ui.page_top win {
    tkTextSetCursor $win 1.0
}
proc ui.page_end win {
    tkTextSetCursor $win {end - 1 char}
}

proc ui.paste_selection win { 
    tk_textPaste $win 
    global tcl_platform
    if { $tcl_platform(platform) == "macintosh" && "$win" == ".input" } {
        focus .input
    }
}

proc ui.delete_selection win { 
    tk_textCut $win
}

proc ui.copy_selection win { 
    set selection ""
    catch { set selection [selection get] }
 
    if { "x$selection" != "x" } { 
        clipboard clear
        clipboard append $selection
    } {
        tk_textCopy $win
    }
}

proc ui.page_down win { 
    tkTextSetCursor $win [tkTextScrollPages $win 1]
}

proc ui.page_up win { 
    tkTextSetCursor $win [tkTextScrollPages $win -1]
}

proc ui.clear_screen win { 
    window.clear_screen $win
}

proc ui.delete_line win {
    $win delete {insert linestart} {insert lineend}
}

proc ui.delete_line_entry win {
    $win delete 0 end
}

proc ui.left_char win {
    tkTextSetCursor $win insert-1c
}

proc ui.right_char win {
    tkTextSetCursor $win insert+1c
}

proc ui.up_line win {
    tkTextSetCursor $win [tkTextUpDownLine $win -1]
}

proc ui.down_line win {
    tkTextSetCursor $win [tkTextUpDownLine $win 1]
}

proc ui.start_line win {
    tkTextSetCursor $win {insert linestart}
}

proc ui.end_line win {
    tkTextSetCursor $win {insert lineend}
}

proc ui.left_word_start win {
    $win mark set insert {insert-1c wordstart}
    while { [$win get insert {insert+1c}] == " " } {
	ui.left_char $win
    }
    $win mark set insert {insert wordstart}
}

proc ui.left_word_start_entry win {
    tkEntrySetCursor $win  [string wordstart [$win get] [expr [$win index insert] - 1]]
}

proc ui.right_word_start win {
    $win mark set insert {insert wordend}
    while { [$win get insert {insert+1c}] == " " } {
	ui.right_char $win
    }
}

proc ui.right_word_start_entry win {
    tkEntrySetCursor $win [string wordend [$win get] [$win index insert]]
}

proc ui.delete_to_end win {
    if [$win compare insert == {insert lineend}] {
        $win delete insert
    } else {
        $win delete insert {insert lineend}
    }
}

proc ui.delete_to_end_entry win {
    $win delete insert end
}

proc ui.delete_to_beginning win {
    $win delete {insert linestart} insert
}

proc ui.delete_to_beginning_entry win {
    $win delete 0 insert
}

proc ui.delete_word_right win {
    $win delete insert {insert wordend}
}

proc ui.delete_word_left win {
    $win delete {insert -1c wordstart} insert
}

proc ui.delete_char_right win {
    $win delete insert {insert +1c} 
}

proc ui.delete_char_left win {
    $win delete {insert -1c} insert
}
#
#


proc request.get { tag key } {
    global request_data
    return $request_data($tag.$key)
}

proc request.set { tag key value } {
    global request_data
    set request_data($tag.$key) $value
}

proc request.create tag {
    global request_data
    set request_data($tag.lines) ""
}

proc request.destroy tag {
    global request_data
    foreach name [array names request_data "$tag.*"] {
        unset request_data($name)
    }
}

proc request.duplicate { source target } {
    global request_data
    foreach key [array names request_data "$source.*"] {
	regsub "^$source\." $key {} key
        set request_data($target.$key) $request_data($source.$key)
    }
}

proc request.current {} {
    set which current
    catch { set which [request.get current tag] }
    return $which
}
set image_data(3218.xbm) {#define 32_width 31
#define 32_height 31
static char 32_bits[] = {
 0x00,0xf0,0x07,0x00,0x00,0x8e,0x3f,0x00,0x80,0x81,0xff,0x00,0x40,0x80,0xff,
 0x01,0x20,0x80,0xff,0x03,0x10,0x80,0xff,0x07,0x08,0x80,0xff,0x09,0x04,0x80,
 0xff,0x10,0x04,0x80,0x7f,0x10,0x02,0x80,0x3f,0x20,0x02,0x80,0x1f,0x20,0x02,
 0x80,0x0f,0x20,0x01,0x80,0x07,0x40,0x01,0x80,0x03,0x40,0x01,0x80,0x01,0x40,
 0x01,0x80,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,
 0x40,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x04,0x00,
 0x00,0x10,0x04,0x00,0x00,0x10,0x08,0x00,0x00,0x08,0x10,0x00,0x00,0x04,0x20,
 0x00,0x00,0x02,0x40,0x00,0x00,0x01,0x80,0x01,0xc0,0x00,0x00,0x0e,0x38,0x00,
 0x00,0xf0,0x07,0x00};
}
set image_data(3228.xbm) {#define 32_width 31
#define 32_height 31
static char 32_bits[] = {
 0x00,0xf0,0x07,0x00,0x00,0x0e,0x38,0x00,0x80,0x01,0xc0,0x00,0x40,0x00,0x00,
 0x01,0x20,0x00,0x00,0x02,0x10,0x00,0x00,0x06,0x08,0x00,0x00,0x0f,0x04,0x00,
 0x80,0x1f,0x04,0x00,0xc0,0x1f,0x02,0x00,0xe0,0x3f,0x02,0x00,0xf0,0x3f,0x02,
 0x00,0xf8,0x3f,0x01,0x00,0xfc,0x7f,0x01,0x00,0xfe,0x7f,0x01,0x00,0xff,0x7f,
 0x01,0x80,0xff,0x7f,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,
 0x40,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x04,0x00,
 0x00,0x10,0x04,0x00,0x00,0x10,0x08,0x00,0x00,0x08,0x10,0x00,0x00,0x04,0x20,
 0x00,0x00,0x02,0x40,0x00,0x00,0x01,0x80,0x01,0xc0,0x00,0x00,0x0e,0x38,0x00,
 0x00,0xf0,0x07,0x00};
}
set image_data(3238.xbm) {#define 32_width 31
#define 32_height 31
static char 32_bits[] = {
 0x00,0xf0,0x07,0x00,0x00,0x0e,0x38,0x00,0x80,0x01,0xc0,0x00,0x40,0x00,0x00,
 0x01,0x20,0x00,0x00,0x02,0x10,0x00,0x00,0x04,0x08,0x00,0x00,0x08,0x04,0x00,
 0x00,0x10,0x04,0x00,0x00,0x10,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x02,
 0x00,0x00,0x20,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,
 0x01,0x80,0xff,0x7f,0x01,0x00,0xff,0x7f,0x01,0x00,0xfe,0x7f,0x01,0x00,0xfc,
 0x7f,0x02,0x00,0xf8,0x3f,0x02,0x00,0xf0,0x3f,0x02,0x00,0xe0,0x3f,0x04,0x00,
 0xc0,0x1f,0x04,0x00,0x80,0x1f,0x08,0x00,0x00,0x0f,0x10,0x00,0x00,0x06,0x20,
 0x00,0x00,0x02,0x40,0x00,0x00,0x01,0x80,0x01,0xc0,0x00,0x00,0x0e,0x38,0x00,
 0x00,0xf0,0x07,0x00};
}
set image_data(3248.xbm) {#define 32_width 31
#define 32_height 31
static char 32_bits[] = {
 0x00,0xf0,0x07,0x00,0x00,0x0e,0x38,0x00,0x80,0x01,0xc0,0x00,0x40,0x00,0x00,
 0x01,0x20,0x00,0x00,0x02,0x10,0x00,0x00,0x04,0x08,0x00,0x00,0x08,0x04,0x00,
 0x00,0x10,0x04,0x00,0x00,0x10,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x02,
 0x00,0x00,0x20,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,
 0x01,0x80,0x00,0x40,0x01,0x80,0x01,0x40,0x01,0x80,0x03,0x40,0x01,0x80,0x07,
 0x40,0x02,0x80,0x0f,0x20,0x02,0x80,0x1f,0x20,0x02,0x80,0x3f,0x20,0x04,0x80,
 0x7f,0x10,0x04,0x80,0xff,0x10,0x08,0x80,0xff,0x09,0x10,0x80,0xff,0x07,0x20,
 0x80,0xff,0x03,0x40,0x80,0xff,0x01,0x80,0x81,0xff,0x00,0x00,0x8e,0x3f,0x00,
 0x00,0xf0,0x07,0x00};
}
set image_data(3258.xbm) {#define 32_width 31
#define 32_height 31
static char 32_bits[] = {
 0x00,0xf0,0x07,0x00,0x00,0x0e,0x38,0x00,0x80,0x01,0xc0,0x00,0x40,0x00,0x00,
 0x01,0x20,0x00,0x00,0x02,0x10,0x00,0x00,0x04,0x08,0x00,0x00,0x08,0x04,0x00,
 0x00,0x10,0x04,0x00,0x00,0x10,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x02,
 0x00,0x00,0x20,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,
 0x01,0x80,0x00,0x40,0x01,0xc0,0x00,0x40,0x01,0xe0,0x00,0x40,0x01,0xf0,0x00,
 0x40,0x02,0xf8,0x00,0x20,0x02,0xfc,0x00,0x20,0x02,0xfe,0x00,0x20,0x04,0xff,
 0x00,0x10,0x84,0xff,0x00,0x10,0xc8,0xff,0x00,0x08,0xf0,0xff,0x00,0x04,0xe0,
 0xff,0x00,0x02,0xc0,0xff,0x00,0x01,0x80,0xff,0xc0,0x00,0x00,0xfe,0x38,0x00,
 0x00,0xf0,0x07,0x00};
}
set image_data(3268.xbm) {#define 32_width 31
#define 32_height 31
static char 32_bits[] = {
 0x00,0xf0,0x07,0x00,0x00,0x0e,0x38,0x00,0x80,0x01,0xc0,0x00,0x40,0x00,0x00,
 0x01,0x20,0x00,0x00,0x02,0x10,0x00,0x00,0x04,0x08,0x00,0x00,0x08,0x04,0x00,
 0x00,0x10,0x04,0x00,0x00,0x10,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x02,
 0x00,0x00,0x20,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,
 0xff,0xff,0x00,0x40,0xff,0x7f,0x00,0x40,0xff,0x3f,0x00,0x40,0xff,0x1f,0x00,
 0x40,0xfe,0x0f,0x00,0x20,0xfe,0x07,0x00,0x20,0xfe,0x03,0x00,0x20,0xfc,0x01,
 0x00,0x10,0xfc,0x00,0x00,0x10,0x78,0x00,0x00,0x08,0x30,0x00,0x00,0x04,0x20,
 0x00,0x00,0x02,0x40,0x00,0x00,0x01,0x80,0x01,0xc0,0x00,0x00,0x0e,0x38,0x00,
 0x00,0xf0,0x07,0x00};
}
set image_data(3278.xbm) {#define 32_width 31
#define 32_height 31
static char 32_bits[] = {
 0x00,0xf0,0x07,0x00,0x00,0x0e,0x38,0x00,0x80,0x01,0xc0,0x00,0x40,0x00,0x00,
 0x01,0x20,0x00,0x00,0x02,0x30,0x00,0x00,0x04,0x78,0x00,0x00,0x08,0xfc,0x00,
 0x00,0x10,0xfc,0x01,0x00,0x10,0xfe,0x03,0x00,0x20,0xfe,0x07,0x00,0x20,0xfe,
 0x0f,0x00,0x20,0xff,0x1f,0x00,0x40,0xff,0x3f,0x00,0x40,0xff,0x7f,0x00,0x40,
 0xff,0xff,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,
 0x40,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x04,0x00,
 0x00,0x10,0x04,0x00,0x00,0x10,0x08,0x00,0x00,0x08,0x10,0x00,0x00,0x04,0x20,
 0x00,0x00,0x02,0x40,0x00,0x00,0x01,0x80,0x01,0xc0,0x00,0x00,0x0e,0x38,0x00,
 0x00,0xf0,0x07,0x00};
}
set image_data(3288.xbm) {#define 32_width 31
#define 32_height 31
static char 32_bits[] = {
 0x00,0xf0,0x07,0x00,0x00,0xfe,0x38,0x00,0x80,0xff,0xc0,0x00,0xc0,0xff,0x00,
 0x01,0xe0,0xff,0x00,0x02,0xf0,0xff,0x00,0x04,0xc8,0xff,0x00,0x08,0x84,0xff,
 0x00,0x10,0x04,0xff,0x00,0x10,0x02,0xfe,0x00,0x20,0x02,0xfc,0x00,0x20,0x02,
 0xf8,0x00,0x20,0x01,0xf0,0x00,0x40,0x01,0xe0,0x00,0x40,0x01,0xc0,0x00,0x40,
 0x01,0x80,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,0x40,0x01,0x00,0x00,
 0x40,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x02,0x00,0x00,0x20,0x04,0x00,
 0x00,0x10,0x04,0x00,0x00,0x10,0x08,0x00,0x00,0x08,0x10,0x00,0x00,0x04,0x20,
 0x00,0x00,0x02,0x40,0x00,0x00,0x01,0x80,0x01,0xc0,0x00,0x00,0x0e,0x38,0x00,
 0x00,0xf0,0x07,0x00};
}
set image_data(arro.xbm) {#define arro_width 16
#define arro_height 16
static unsigned char arro_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x08, 0x00, 0x10, 0x00, 0x20, 0x00,
   0x40, 0x00, 0x80, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00, 0x04, 0x00, 0x08,
   0x00, 0x90, 0x00, 0xa0, 0x00, 0xc0, 0x00, 0xf0};
}
set image_data(atoz.xbm) {#define text_width 16
#define text_height 16
static unsigned char text_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x0c, 0x00, 0x14, 0x00, 0x12,
   0x00, 0x11, 0x00, 0x21, 0x80, 0x20, 0xc0, 0x3f, 0x20, 0x20, 0x20, 0x40,
   0x10, 0x40, 0x08, 0x40, 0x08, 0xc0, 0x1c, 0xe0};
}
set image_data(bishop.xbm) {#define bishop_width 32
#define bishop_height 32
static unsigned char bishop_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc0, 0x01, 0x00,
   0x00, 0xc0, 0x01, 0x00, 0x00, 0xf0, 0x07, 0x00, 0x00, 0xe8, 0x0f, 0x00,
   0x00, 0xdc, 0x1f, 0x00, 0x00, 0xbc, 0x1f, 0x00, 0x00, 0xfc, 0x1f, 0x00,
   0x00, 0xf8, 0x0f, 0x00, 0x00, 0xf8, 0x0f, 0x00, 0x00, 0xf8, 0x0f, 0x00,
   0x00, 0xf8, 0x0f, 0x00, 0x00, 0xf0, 0x07, 0x00, 0x00, 0xf0, 0x07, 0x00,
   0x00, 0xf0, 0x07, 0x00, 0x00, 0xf0, 0x07, 0x00, 0x00, 0xe0, 0x03, 0x00,
   0x00, 0xe0, 0x03, 0x00, 0x00, 0xe0, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0xe0, 0x03, 0x00, 0x00, 0xe0, 0x03, 0x00, 0x00, 0xe0, 0x03, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0xe0, 0x03, 0x00, 0x00, 0xf0, 0x07, 0x00,
   0x00, 0xf8, 0x0f, 0x00, 0x00, 0xfc, 0x1f, 0x00, 0x00, 0xfe, 0x3f, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
}
set image_data(burst.xbm) {#define burst_width 48
#define burst_height 48
#define burst_x_hot 19
#define burst_y_hot 27
static unsigned char burst_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x03, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x03, 0x0c, 0x00, 0x00,
   0x00, 0xc0, 0x0f, 0x0f, 0x3c, 0x00, 0x00, 0xc0, 0x0f, 0x0f, 0x3c, 0x00,
   0x00, 0xc0, 0xfc, 0x3f, 0x3f, 0x00, 0x00, 0xc0, 0xfc, 0x3f, 0x3f, 0x00,
   0x00, 0xf0, 0x00, 0xf0, 0x33, 0x00, 0x00, 0xf0, 0x00, 0xf0, 0x33, 0x00,
   0xfc, 0x3f, 0x00, 0x00, 0x3c, 0x00, 0xfc, 0x3f, 0x00, 0x00, 0x3c, 0x00,
   0x0f, 0x00, 0x00, 0x00, 0x3c, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x3c, 0x00,
   0x3f, 0x00, 0x00, 0x00, 0x3c, 0x00, 0x3f, 0x00, 0x00, 0x00, 0x3c, 0x00,
   0x3c, 0x00, 0x00, 0x00, 0x3c, 0x00, 0x3c, 0x00, 0x00, 0x00, 0x3c, 0x00,
   0x30, 0x00, 0x00, 0x00, 0xf0, 0x00, 0x30, 0x00, 0x00, 0x00, 0xf0, 0x00,
   0x3c, 0x00, 0x00, 0x00, 0xff, 0x00, 0x3c, 0x00, 0x00, 0x00, 0xff, 0x00,
   0x0c, 0x00, 0x00, 0xc0, 0x3f, 0x00, 0x0c, 0x00, 0x00, 0xc0, 0x3f, 0x00,
   0x0f, 0x00, 0x00, 0xc0, 0x03, 0x00, 0x0f, 0x00, 0x00, 0xc0, 0x03, 0x00,
   0xff, 0x00, 0x00, 0xc0, 0x03, 0x00, 0xff, 0x00, 0x00, 0xc0, 0x03, 0x00,
   0xfc, 0x00, 0x00, 0xff, 0x03, 0x00, 0xfc, 0x00, 0x00, 0xff, 0x03, 0x00,
   0xc0, 0xfc, 0x00, 0xff, 0x03, 0x00, 0xc0, 0xfc, 0x00, 0xff, 0x03, 0x00,
   0xc0, 0xff, 0xc3, 0xf3, 0x03, 0x00, 0xc0, 0xff, 0xc3, 0xf3, 0x03, 0x00,
   0xc0, 0xcf, 0xff, 0x03, 0x00, 0x00, 0xc0, 0xcf, 0xff, 0x03, 0x00, 0x00,
   0x00, 0x03, 0xff, 0x00, 0x00, 0x00, 0x00, 0x03, 0xff, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x30, 0x00, 0x00, 0x00};
}
set image_data(chess.xbm) {#define chess_width 40
#define chess_height 40
static unsigned char chess_bits[] = {
   0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83,
   0x0f, 0x3e, 0xf8, 0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83, 0x0f, 0x3e,
   0xf8, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f,
   0x7c, 0xf0, 0xc1, 0x07, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f, 0x7c, 0xf0,
   0xc1, 0x07, 0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83, 0x0f, 0x3e, 0xf8,
   0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83,
   0x0f, 0x3e, 0xf8, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f, 0x7c, 0xf0, 0xc1,
   0x07, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f,
   0x7c, 0xf0, 0xc1, 0x07, 0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83, 0x0f,
   0x3e, 0xf8, 0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83, 0x0f, 0x3e, 0xf8,
   0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f, 0x7c,
   0xf0, 0xc1, 0x07, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f, 0x7c, 0xf0, 0xc1,
   0x07, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0,
   0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0xe0, 0x83, 0x0f,
   0x3e, 0xf8, 0xe0, 0x83, 0x0f, 0x3e, 0xf8, 0x1f, 0x7c, 0xf0, 0xc1, 0x07,
   0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f, 0x7c, 0xf0, 0xc1, 0x07, 0x1f, 0x7c,
   0xf0, 0xc1, 0x07, 0x1f, 0x7c, 0xf0, 0xc1, 0x07};
}
set image_data(dir.xbm) {#define dir_width 48
#define dir_height 48
#define dir_x_hot 20
#define dir_y_hot 30
static unsigned char dir_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0xf0, 0xff, 0x0f, 0x00, 0x00, 0x00, 0xf0, 0xff, 0x0f, 0x00, 0x00, 0x00,
   0x0c, 0x00, 0x30, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x30, 0x00, 0x00, 0x00,
   0x0f, 0x00, 0xf0, 0xff, 0x3f, 0x00, 0x0f, 0x00, 0xf0, 0xff, 0x3f, 0x00,
   0xf7, 0xff, 0x3f, 0x00, 0xc0, 0x00, 0xdf, 0x7b, 0x2f, 0x00, 0xc0, 0x00,
   0x73, 0xff, 0x0d, 0x00, 0xc0, 0x03, 0xf3, 0xff, 0x0f, 0x00, 0xc0, 0x03,
   0x03, 0x00, 0x00, 0x00, 0xf0, 0x0f, 0x03, 0x00, 0x00, 0x00, 0x70, 0x0f,
   0x03, 0x00, 0x00, 0x00, 0xc0, 0x0f, 0x03, 0x00, 0x00, 0x00, 0xc0, 0x0f,
   0x03, 0x00, 0x00, 0x00, 0xf0, 0x0d, 0x03, 0x00, 0x00, 0x00, 0xd0, 0x0f,
   0x03, 0x00, 0x00, 0x00, 0xc0, 0x0f, 0x03, 0x00, 0x00, 0x00, 0x40, 0x0f,
   0x03, 0x00, 0x00, 0x00, 0xf0, 0x0d, 0x03, 0x00, 0x00, 0x00, 0xf0, 0x0f,
   0x03, 0x00, 0x00, 0x00, 0xc0, 0x0f, 0x03, 0x00, 0x00, 0x00, 0xc0, 0x0f,
   0x03, 0x00, 0x00, 0x00, 0xf0, 0x0e, 0x03, 0x00, 0x00, 0x00, 0xe0, 0x0f,
   0x03, 0x00, 0x00, 0x00, 0xc0, 0x0f, 0x03, 0x00, 0x00, 0x00, 0xc0, 0x0d,
   0x03, 0x00, 0x00, 0x00, 0xf0, 0x0f, 0x03, 0x00, 0x00, 0x00, 0xb0, 0x0f,
   0xc3, 0xcc, 0xcc, 0xcc, 0xcc, 0x0f, 0xc3, 0xcc, 0xcc, 0xcc, 0xcc, 0x0d,
   0xfc, 0xff, 0xff, 0xff, 0xff, 0x0f, 0xbc, 0xbf, 0xbf, 0xbf, 0xdb, 0x0f,
   0xf0, 0xfb, 0xfb, 0xfb, 0x7f, 0x0f, 0xf0, 0xff, 0xff, 0xff, 0xff, 0x0d,
   0x40, 0x7f, 0x7f, 0xef, 0xfe, 0x0f, 0xc0, 0xef, 0xef, 0xff, 0xfb, 0x0f};
}
set image_data(down.gif) {R0lGODlhBQAJAPAAAAAAAP///yH5BAEAAAEALAAAAAAFAAkAAAIMjAMHidsLXTRQMVoAADs=
}
set image_data(iburst.xbm) {#define iburst_width 24
#define iburst_height 24
#define iburst_x_hot 9
#define iburst_y_hot 13
static unsigned char iburst_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x21, 0x00, 0x80, 0x33, 0x06, 0x80, 0x7e, 0x07,
   0xc0, 0xc0, 0x05, 0x7e, 0x00, 0x06, 0x03, 0x00, 0x06, 0x07, 0x00, 0x06,
   0x06, 0x00, 0x06, 0x04, 0x00, 0x0c, 0x06, 0x00, 0x0f, 0x02, 0x80, 0x07,
   0x03, 0x80, 0x01, 0x0f, 0x80, 0x01, 0x0e, 0xf0, 0x01, 0xe8, 0xf0, 0x01,
   0xf8, 0xd9, 0x01, 0xb8, 0x1f, 0x00, 0x10, 0x0f, 0x00, 0x00, 0x04, 0x00};
}
set image_data(idaho.xbm) {#define idaho_width 24
#define idaho_height 24
#define idaho_x_hot 7
#define idaho_y_hot 13
static unsigned char idaho_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0x1f, 0x00, 0x01, 0x28, 0x00,
   0x01, 0x48, 0x00, 0x01, 0x80, 0x00, 0x01, 0x08, 0x01, 0x01, 0xf8, 0x03,
   0xf9, 0xb3, 0x03, 0x01, 0xe0, 0x03, 0x51, 0xc3, 0x03, 0x01, 0x00, 0x03,
   0xf9, 0x1f, 0x02, 0x01, 0x00, 0x02, 0x79, 0x1f, 0x02, 0x01, 0x00, 0x02,
   0xf9, 0x1f, 0x02, 0x01, 0x00, 0x02, 0xc1, 0x1f, 0x02, 0x01, 0x00, 0x02,
   0xc1, 0x1f, 0x02, 0x01, 0x00, 0x02, 0x01, 0x00, 0x02, 0xfc, 0xff, 0x03};
}
set image_data(idir.xbm) {#define idir_width 24
#define idir_height 24
#define idir_x_hot 9
#define idir_y_hot 14
static unsigned char idir_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfc, 0x03, 0x00, 0x02, 0x04, 0x00,
   0x03, 0xfc, 0x07, 0xff, 0x07, 0x08, 0xfd, 0x03, 0x18, 0x01, 0x00, 0x3c,
   0x01, 0x00, 0x38, 0x01, 0x00, 0x3c, 0x01, 0x00, 0x38, 0x01, 0x00, 0x3c,
   0x01, 0x00, 0x38, 0x01, 0x00, 0x2c, 0x01, 0x00, 0x38, 0x01, 0x00, 0x3c,
   0xa9, 0xaa, 0x3a, 0xfe, 0xff, 0x3f, 0xdc, 0xdd, 0x3f, 0xf8, 0xbf, 0x3e};
}
set image_data(iimage2.xbm) {#define iimage2_width 24
#define iimage2_height 24
#define iimage2_x_hot 8
#define iimage2_y_hot 14
static unsigned char iimage2_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x28, 0x00,
   0x01, 0x40, 0x00, 0x00, 0x88, 0x00, 0x01, 0x00, 0x01, 0x00, 0x58, 0x03,
   0xf9, 0xf1, 0x03, 0xbc, 0x01, 0x02, 0x04, 0x01, 0x02, 0xcc, 0x0f, 0x02,
   0x4c, 0x08, 0x02, 0x38, 0x1f, 0x02, 0xa0, 0x1f, 0x02, 0x60, 0x9f, 0x02,
   0xa1, 0x9e, 0x02, 0xc0, 0xff, 0x02, 0x00, 0xf7, 0x02, 0x01, 0xbc, 0x02,
   0x00, 0xae, 0x02, 0x00, 0xff, 0x02, 0x01, 0x00, 0x02, 0xfc, 0xff, 0x03};
}
set image_data(image2.xbm) {#define image2_width 48
#define image2_height 48
#define image2_x_hot 17
#define image2_y_hot 27
static unsigned char image2_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x08, 0x21, 0x04, 0x02, 0x00, 0x00,
   0x00, 0x00, 0x40, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00,
   0x01, 0x00, 0x00, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00,
   0x00, 0x00, 0x40, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00,
   0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00,
   0xa0, 0xaa, 0x40, 0x33, 0x0f, 0x00, 0x50, 0x92, 0x00, 0x33, 0x0b, 0x00,
   0x41, 0x55, 0x03, 0xff, 0x0f, 0x00, 0x20, 0xa9, 0x03, 0xff, 0x0f, 0x00,
   0x50, 0x45, 0x03, 0x00, 0x0c, 0x00, 0xa0, 0x54, 0x03, 0x00, 0x0c, 0x00,
   0x90, 0xaa, 0x03, 0x20, 0x0c, 0x00, 0x41, 0x25, 0x03, 0x00, 0x0c, 0x00,
   0x50, 0xf2, 0x7f, 0x00, 0x0c, 0x00, 0x40, 0xd5, 0xbf, 0x00, 0x0c, 0x00,
   0x50, 0x3a, 0xe0, 0x02, 0x0c, 0x00, 0x50, 0x35, 0xb0, 0x01, 0x0c, 0x00,
   0xc0, 0x0f, 0xff, 0x03, 0x0c, 0x00, 0xc1, 0x0f, 0xfd, 0x03, 0x0c, 0x00,
   0x00, 0xcc, 0x57, 0x03, 0x0c, 0x00, 0x00, 0xcc, 0xff, 0x03, 0x0c, 0x00,
   0x00, 0xbc, 0xfd, 0xc3, 0x0c, 0x00, 0x00, 0xf8, 0xb7, 0xd3, 0x0c, 0x00,
   0x01, 0xec, 0xfe, 0xe3, 0x0c, 0x00, 0x00, 0xbc, 0xb7, 0xf3, 0x0c, 0x00,
   0x00, 0xf0, 0xff, 0xdd, 0x0c, 0x00, 0x00, 0xf0, 0xed, 0xee, 0x0c, 0x00,
   0x00, 0x80, 0xbf, 0xf5, 0x0c, 0x00, 0x00, 0xc0, 0x7f, 0xdb, 0x0c, 0x00,
   0x01, 0x00, 0xd0, 0xed, 0x0c, 0x00, 0x00, 0x00, 0x60, 0xdb, 0x0c, 0x00,
   0x00, 0x00, 0xdc, 0xee, 0x0c, 0x00, 0x00, 0x00, 0xb4, 0xf5, 0x0c, 0x00,
   0x00, 0x00, 0xff, 0xff, 0x0c, 0x00, 0x00, 0x00, 0xff, 0xff, 0x0c, 0x00,
   0x01, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x00,
   0xf0, 0xff, 0xff, 0xff, 0x0d, 0x00, 0xf0, 0xff, 0xff, 0xdf, 0x0f, 0x00};
}
set image_data(iperson.xbm) {#define iperson_width 24
#define iperson_height 24
#define iperson_x_hot 10
#define iperson_y_hot 12
static unsigned char iperson_bits[] = {
   0xf0, 0xff, 0x00, 0xf0, 0xff, 0x00, 0xd8, 0x4a, 0x01, 0x2c, 0xb5, 0x02,
   0xd7, 0x7f, 0x0d, 0xeb, 0xff, 0x12, 0xf7, 0xff, 0x0d, 0xeb, 0xf5, 0x12,
   0xf7, 0xfb, 0x2d, 0xeb, 0xf5, 0x52, 0xd7, 0xfa, 0xad, 0x2b, 0xfd, 0x72,
   0xd7, 0x7e, 0x0d, 0xd7, 0x7e, 0x0d, 0x2c, 0xbf, 0x12, 0xd8, 0x4e, 0x0d,
   0x30, 0xbf, 0x02, 0xe0, 0x4a, 0x0d, 0x20, 0xb5, 0x02, 0xe0, 0x4e, 0x00,
   0x20, 0xbf, 0x00, 0xe0, 0x4e, 0x00, 0x30, 0xb5, 0x00, 0xd0, 0x4a, 0x01};
}
set image_data(king.xbm) {#define king_width 32
#define king_height 32
static unsigned char king_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0c, 0x80, 0x01, 0x30,
   0x1e, 0xc0, 0x03, 0x78, 0x1e, 0xc0, 0x03, 0x78, 0x0c, 0x80, 0x01, 0x30,
   0x00, 0x00, 0x00, 0x00, 0x0c, 0x80, 0x01, 0x30, 0x1c, 0xc0, 0x03, 0x38,
   0x3c, 0xe0, 0x07, 0x3c, 0x7c, 0xf0, 0x0f, 0x3e, 0xfc, 0xf8, 0x1f, 0x3f,
   0xfc, 0xfd, 0xbf, 0x3f, 0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f,
   0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f,
   0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f,
   0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f,
   0xf8, 0xff, 0xff, 0x1f, 0x00, 0x00, 0x00, 0x00, 0xf8, 0xff, 0xff, 0x1f,
   0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f, 0xf8, 0xff, 0xff, 0x1f,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
}
set image_data(knight.xbm) {#define knight_width 32
#define knight_height 32
static unsigned char knight_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x00,
   0x00, 0x00, 0x7c, 0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0xe0, 0xff, 0x00,
   0x00, 0xf8, 0xff, 0x01, 0x00, 0xff, 0xfd, 0x03, 0xc0, 0xff, 0xff, 0x03,
   0xe0, 0xff, 0xff, 0x07, 0xf0, 0xff, 0xff, 0x07, 0xf0, 0xff, 0xff, 0x07,
   0xf0, 0xfe, 0xff, 0x03, 0x30, 0xfe, 0xff, 0x03, 0x80, 0xff, 0xff, 0x03,
   0xe0, 0xff, 0xff, 0x03, 0xf0, 0x8f, 0xff, 0x03, 0xe0, 0xc0, 0xff, 0x03,
   0x00, 0xc0, 0xff, 0x03, 0x00, 0xe0, 0xff, 0x07, 0x00, 0xf0, 0xff, 0x07,
   0x00, 0xf8, 0xff, 0x07, 0x00, 0xfc, 0xff, 0x07, 0x00, 0xfe, 0xff, 0x07,
   0x00, 0xff, 0xff, 0x07, 0x80, 0xff, 0xff, 0x07, 0x80, 0xff, 0xff, 0x0f,
   0xc0, 0xff, 0xff, 0x0f, 0xe0, 0xff, 0xff, 0x0f, 0xf0, 0xff, 0xff, 0x0f,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
}
set image_data(left.gif) {R0lGODlhBQAJAPAAAAAAAP///yH5BAEAAAEALAAAAAAFAAkAAAIMjAMHidsLXTRQMVoAADs=
}
set image_data(left.xbm) {#define left_width 5
#define left_height 9
static unsigned char left_bits[] = {
   0xf0, 0xf8, 0xfc, 0xfe, 0xff, 0xfe, 0xfc, 0xf8, 0xf0};
}
set image_data(line.xbm) {#define line_width 16
#define line_height 16
static unsigned char line_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x08, 0x00, 0x10, 0x00, 0x20, 0x00,
   0x40, 0x00, 0x80, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00, 0x04, 0x00, 0x08,
   0x00, 0x10, 0x00, 0x20, 0x00, 0x40, 0x00, 0x80};
}
set image_data(oval.xbm) {#define oval_width 16
#define oval_height 16
static unsigned char oval_bits[] = {
   0x00, 0x00, 0x80, 0x03, 0x60, 0x0c, 0x18, 0x30, 0x08, 0x20, 0x04, 0x40,
   0x04, 0x40, 0x02, 0x80, 0x02, 0x80, 0x02, 0x80, 0x04, 0x40, 0x04, 0x40,
   0x08, 0x20, 0x18, 0x30, 0x60, 0x0c, 0x80, 0x03};
}
set image_data(pawn.xbm) {#define pawn_width 32
#define pawn_height 32
static unsigned char pawn_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xe0, 0x07, 0x00,
   0x00, 0xf8, 0x1f, 0x00, 0x00, 0xfc, 0x3f, 0x00, 0x00, 0xfe, 0x7f, 0x00,
   0x00, 0xfe, 0x7f, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00,
   0x00, 0xff, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00,
   0x00, 0xff, 0xff, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0xfe, 0x7f, 0x00,
   0x00, 0xfe, 0x7f, 0x00, 0x00, 0xfc, 0x3f, 0x00, 0x00, 0xf8, 0x1f, 0x00,
   0x00, 0xf8, 0x1f, 0x00, 0x00, 0xfc, 0x3f, 0x00, 0x00, 0xfc, 0x3f, 0x00,
   0x00, 0xfe, 0x7f, 0x00, 0x00, 0xfe, 0x7f, 0x00, 0x00, 0xff, 0xff, 0x00,
   0x00, 0xff, 0xff, 0x00, 0x80, 0xff, 0xff, 0x01, 0x80, 0xff, 0xff, 0x01,
   0xc0, 0xff, 0xff, 0x03, 0xc0, 0xff, 0xff, 0x03, 0xe0, 0xff, 0xff, 0x07,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
}
set image_data(person.xbm) {#define person_width 48
#define person_height 48
static char person_bits[] = {
 0x00,0xff,0xff,0xff,0x00,0x00,0x00,0xff,0xff,0xff,0x00,0x00,0x00,0xff,0xff,
 0xff,0x00,0x00,0xe0,0x73,0xce,0x18,0x03,0x00,0xe0,0x73,0xce,0x18,0x03,0x00,
 0xf8,0x8c,0x31,0xe7,0x0c,0x00,0xf8,0x8c,0x31,0xe7,0x0c,0x00,0x1f,0xf3,0xff,
 0x1f,0x73,0x00,0x1f,0xf3,0xff,0x1f,0x73,0x00,0xe7,0xfc,0xff,0xff,0x8c,0x01,
 0xe7,0xfc,0xff,0xff,0x8c,0x01,0x1f,0xff,0xff,0xff,0x73,0x00,0x1f,0xff,0xff,
 0xff,0x73,0x00,0x1f,0xff,0xff,0xff,0x73,0x00,0xe7,0xfc,0x31,0xff,0x8c,0x01,
 0xe7,0xfc,0x31,0xff,0x8c,0x01,0x1f,0xff,0xcf,0xff,0x73,0x0e,0x1f,0xff,0xcf,
 0xff,0x73,0x0e,0xe7,0xfc,0x31,0xff,0x8c,0x31,0xe7,0xfc,0x31,0xff,0x8c,0x31,
 0x1f,0x73,0xce,0xff,0x73,0xce,0x1f,0x73,0xce,0xff,0x73,0xce,0xe7,0x8c,0xf1,
 0xff,0x8c,0x3f,0xe7,0x8c,0xf1,0xff,0x8c,0x3f,0x1f,0x73,0xfe,0x1f,0x73,0x00,
 0x1f,0x73,0xfe,0x1f,0x73,0x00,0x1f,0x73,0xfe,0x1f,0x73,0x00,0xf8,0x8c,0xff,
 0xe7,0x8c,0x01,0xf8,0x8c,0xff,0xe7,0x8c,0x01,0xe0,0x73,0xfe,0x18,0x73,0x00,
 0xe0,0x73,0xfe,0x18,0x73,0x00,0x00,0x8f,0xff,0xe7,0x0c,0x00,0x00,0x8f,0xff,
 0xe7,0x0c,0x00,0x00,0x7c,0xce,0x18,0x73,0x00,0x00,0x7c,0xce,0x18,0x73,0x00,
 0x00,0x8c,0x31,0xe7,0x0c,0x00,0x00,0x8c,0x31,0xe7,0x0c,0x00,0x00,0x8c,0x31,
 0xe7,0x0c,0x00,0x00,0x7c,0xfe,0x18,0x00,0x00,0x00,0x7c,0xfe,0x18,0x00,0x00,
 0x00,0x8c,0xff,0xe7,0x00,0x00,0x00,0x8c,0xff,0xe7,0x00,0x00,0x00,0x7c,0xfe,
 0x18,0x00,0x00,0x00,0x7c,0xfe,0x18,0x00,0x00,0x00,0x8f,0x31,0xe7,0x00,0x00,
 0x00,0x8f,0x31,0xe7,0x00,0x00,0x00,0x73,0xce,0x18,0x03,0x00,0x00,0x73,0xce,
 0x18,0x03,0x00};
}
set image_data(queen.xbm) {#define queen_width 32
#define queen_height 32
static unsigned char queen_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x01, 0x00, 0x18, 0xc0, 0x03, 0x18,
   0x3c, 0xc0, 0x03, 0x3c, 0x3c, 0x80, 0x01, 0x3c, 0x18, 0x00, 0x00, 0x18,
   0x00, 0xc0, 0x03, 0x00, 0x08, 0xe0, 0x07, 0x10, 0x18, 0xe0, 0x07, 0x18,
   0x38, 0xf0, 0x0f, 0x1c, 0x70, 0xf0, 0x0f, 0x0e, 0xf0, 0xf8, 0x1f, 0x0f,
   0xf0, 0xf9, 0x9f, 0x0f, 0xf0, 0xff, 0xff, 0x0f, 0xf0, 0xff, 0xff, 0x0f,
   0xf0, 0xff, 0xff, 0x0f, 0xe0, 0xff, 0xff, 0x07, 0xe0, 0xff, 0xff, 0x07,
   0xe0, 0xff, 0xff, 0x07, 0xe0, 0xff, 0xff, 0x07, 0xe0, 0xff, 0xff, 0x07,
   0xe0, 0xff, 0xff, 0x07, 0xc0, 0xff, 0xff, 0x03, 0xc0, 0xff, 0xff, 0x03,
   0x80, 0xff, 0xff, 0x01, 0x00, 0x00, 0x00, 0x00, 0xc0, 0xff, 0xff, 0x03,
   0xe0, 0xff, 0xff, 0x07, 0xe0, 0xff, 0xff, 0x07, 0xc0, 0xff, 0xff, 0x03,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
}
set image_data(rect.xbm) {#define rect_width 16
#define rect_height 16
static unsigned char rect_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0xfc, 0xff, 0x04, 0x80, 0x04, 0x80, 0x04, 0x80,
   0x04, 0x80, 0x04, 0x80, 0x04, 0x80, 0x04, 0x80, 0x04, 0x80, 0x04, 0x80,
   0x04, 0x80, 0x04, 0x80, 0x04, 0x80, 0xfc, 0xff};
}
set image_data(right.gif) {R0lGODlhBQAJAPAAAAAAAP///yH5BAEAAAEALAAAAAAFAAkAAAIMRB5gp9v2YlJsJRQKADs=
}
set image_data(right.xbm) {#define right_width 5
#define right_height 9
static unsigned char right_bits[] = {
   0xe1, 0xe3, 0xe7, 0xef, 0xff, 0xef, 0xe7, 0xe3, 0xe1};
}
set image_data(rook.xbm) {#define rook_width 32
#define rook_height 32
static unsigned char rook_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xfc, 0xe0, 0x07, 0x3f,
   0xfc, 0xe0, 0x07, 0x3f, 0xfc, 0xe0, 0x07, 0x3f, 0xfc, 0xff, 0xff, 0x3f,
   0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f, 0xfc, 0xff, 0xff, 0x3f,
   0xfc, 0xff, 0xff, 0x3f, 0xc0, 0xff, 0xff, 0x03, 0xc0, 0xff, 0xff, 0x03,
   0xc0, 0xff, 0xff, 0x03, 0xc0, 0xff, 0xff, 0x03, 0xc0, 0xff, 0xff, 0x03,
   0xc0, 0xff, 0xff, 0x03, 0xc0, 0xff, 0xff, 0x03, 0xc0, 0xff, 0xff, 0x03,
   0xc0, 0xff, 0xff, 0x03, 0xc0, 0xff, 0xff, 0x03, 0xc0, 0xff, 0xff, 0x03,
   0x00, 0x00, 0x00, 0x00, 0xf8, 0xff, 0xff, 0x1f, 0xf8, 0xff, 0xff, 0x1f,
   0xf8, 0xff, 0xff, 0x1f, 0xf8, 0xff, 0xff, 0x1f, 0xf8, 0xff, 0xff, 0x1f,
   0xf8, 0xff, 0xff, 0x1f, 0xf8, 0xff, 0xff, 0x1f, 0xf8, 0xff, 0xff, 0x1f,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
}
set image_data(slct.xbm) {#define slct_width 16
#define slct_height 16
static unsigned char slct_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x1c, 0x00, 0xfc, 0x03, 0xfc, 0x1f, 0xf8, 0x07,
   0xf8, 0x00, 0xf8, 0x01, 0xb8, 0x03, 0x38, 0x07, 0x30, 0x0e, 0x10, 0x1c,
   0x10, 0x38, 0x00, 0x70, 0x00, 0xe0, 0x00, 0xc0};
}
set image_data(text.xbm) {#define text_width 48
#define text_height 48
#define text_x_hot 17
#define text_y_hot 28
static unsigned char text_bits[] = {
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
   0xff, 0xff, 0xff, 0x03, 0x00, 0x00, 0xff, 0xff, 0xff, 0x03, 0x00, 0x00,
   0x03, 0x00, 0xc0, 0x0c, 0x00, 0x00, 0x03, 0x00, 0xc0, 0x0c, 0x00, 0x00,
   0x03, 0x00, 0xc0, 0x30, 0x00, 0x00, 0x03, 0x00, 0xc0, 0x30, 0x00, 0x00,
   0x03, 0x00, 0x80, 0xc0, 0x00, 0x00, 0x03, 0x00, 0xc0, 0xc0, 0x00, 0x00,
   0x03, 0x00, 0xc0, 0x00, 0x03, 0x00, 0x03, 0x00, 0xc0, 0x00, 0x03, 0x00,
   0x03, 0x00, 0xc0, 0xff, 0x0f, 0x00, 0x03, 0x00, 0x40, 0xff, 0x0f, 0x00,
   0xc3, 0xff, 0x0f, 0x6d, 0x0f, 0x00, 0xc3, 0xff, 0x0f, 0xff, 0x0f, 0x00,
   0x03, 0x00, 0x00, 0xfc, 0x0d, 0x00, 0x03, 0x00, 0x00, 0xfc, 0x0f, 0x00,
   0x83, 0xbb, 0x0f, 0xd0, 0x0f, 0x00, 0xc3, 0xff, 0x0e, 0x70, 0x0f, 0x00,
   0x03, 0x00, 0x00, 0x00, 0x0f, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0d, 0x00,
   0xc3, 0xff, 0xff, 0x03, 0x0c, 0x00, 0xc3, 0xfe, 0xff, 0x03, 0x0c, 0x00,
   0x03, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0c, 0x00,
   0xc3, 0xbf, 0xf7, 0x03, 0x0c, 0x00, 0xc3, 0xfb, 0xbf, 0x03, 0x0c, 0x00,
   0x03, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0c, 0x00,
   0xc3, 0xff, 0xff, 0x03, 0x0c, 0x00, 0xc3, 0xef, 0xfe, 0x03, 0x0c, 0x00,
   0x03, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0c, 0x00,
   0x03, 0xf0, 0xff, 0x03, 0x0c, 0x00, 0x01, 0xf0, 0xb7, 0x03, 0x0c, 0x00,
   0x03, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0c, 0x00,
   0x03, 0xf0, 0xff, 0x03, 0x0c, 0x00, 0x03, 0x60, 0xff, 0x03, 0x0c, 0x00,
   0x03, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0c, 0x00,
   0x03, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x03, 0x00, 0x00, 0x00, 0x0c, 0x00,
   0xf0, 0xff, 0xff, 0xff, 0x0d, 0x00, 0xf0, 0xff, 0xdb, 0xdd, 0x0f, 0x00};
}
set image_data(up.gif) {R0lGODlhBQAJAPAAAAAAAP///yH5BAEAAAEALAAAAAAFAAkAAAIMRB5gp9v2YlJsJRQKADs=
}
#
#

client.register xmcp11 start
client.register xmcp11 client_connected
client.register xmcp11 incoming

proc xmcp11.client_connected {} {
    global xmcp11_use xmcp11_use_log xmcp11_authentication_key xmcp11_active

    request.set current xmcp11_multiline_procedure ""
    request.set current xmcp11_lines ""

    set use [string tolower [worlds.get_generic on {} {} UseModuleXMCP11]]

    if { $use == "on" } {
        set xmcp11_use 1
    } elseif { $use == "off" } {
        set xmcp11_use 0
    }
    ###

    set xmcp11_active 0

    set xmcp11_use_log 0
    set xmcp11_authentication_key ""
    return [modules.module_deferred]
}

proc xmcp11.start {} {
    global xmcp11_use
    set xmcp11_use 0
    ###
    .output tag configure xmcp11_mcp	-foreground [colourdb.get darkgreen]
    .output tag configure xmcp11_type	-foreground [colourdb.get red]
    .output tag configure xmcp11_value	-foreground [colourdb.get blue]
    .output tag configure xmcp11_default
    window.menu_tools_add "@xmcp_challenge"  {io.outgoing {@xmcp_challenge}}
}

proc xmcp11.logCR { line tag io } { 
    global xmcp11_use_log 

    if { $xmcp11_use_log == 0 } {
	return
    }
    window.displayCR $line $tag
}

proc xmcp11.log { line tag io } { 
    global xmcp11_use_log 

    if { $xmcp11_use_log == 0 } {
	return
    }
    window.display $line $tag
}

proc xmcp11.incoming event {
    global xmcp11_use xmcp11_active

    if { $xmcp11_use == 0 } {
        return [modules.module_deferred]
    }

    set line [db.get $event line]

    if { [string match {\$*} $line] == 0 } {
        return [modules.module_deferred]
    }

    if { [regexp {^\$#\$([-a-zA-Z0-9*]*) *(.*)} $line throwaway type rest] } {


        if { ($type != "xmcp") && ($xmcp11_active == 0) } {
	    return [modules.module_deferred]
	}

        xmcp11.log "\$#\$" xmcp11_mcp "<"
        xmcp11.log "$type " xmcp11_type ""
	request.set current _type $type
        if { [xmcp11.parse $rest] } {
            if { [info procs "xmcp11.do_$type"] != {} } {
                xmcp11.do_$type
            } {
                return [modules.module_deferred]
            }
        }
        set last [string index $type [expr [string length $type] - 1]]
        if { $last == "*" } {
	    request.set current xmcp11_lines ""
	    ###
	    catch {
	    if { [set tag [request.get current tag]] } {
		request.duplicate current $tag
	    }
	    }
	    #
	    ###
	} {
            xmcp11.unset_header
        }
        return [modules.module_ok]
    }

    return [modules.module_deferred]
}

proc xmcp11.parse header {
    set first [lindex $header 0]
    if {![regexp ":" $first]} {
	request.set current _authentication-key $first
        xmcp11.log "$first " xmcp11_mcp ""
        set header [lrange $header 1 end]
    } {
	request.set current _authentication-key NULL
    }

    set keyword ""
    foreach item $header {
        if { $keyword != "" } {
	    request.set current $keyword $item
            xmcp11.log "$keyword: " xmcp11_mcp ""
            xmcp11.log "$item " xmcp11_value ""
            set keyword ""
        } {
            set keyword $item
            regsub ":" $keyword "" keyword
        }
    }
    xmcp11.logCR "" xmcp11_default ""
    return 1
}



proc xmcp11.authenticated { {flag verbose} } {
    global xmcp11_authentication_key 
    if { [request.get current _authentication-key] == $xmcp11_authentication_key } {
        return 1
    }
    if { $flag == "verbose" } {
        xmcp11.no_auth_dialog [request.get current _type] [request.get current _authentication-key]
    }
    return 0
}

proc xmcp11.no_auth_dialog { message key } {
    tk_dialog .xmcp11_no_auth_dialog "XMCP/1.1 Authentication Error" \
        "XMCP/1.1 message '$message' not authenticated by key '$key'.  Message ignored." \
        info 0 OK
}

###
proc xmcp11.unset_header {} {
    request.destroy current

    request.set current xmcp11_multiline_procedure ""
    request.set current xmcp11_lines ""
}

proc xmcp11.do_xmcp {} {
    global xmcp11_authentication_key xmcp11_active

    set authenticate "@xmcp_authentication_key"

    if { [request.get current version] == "1.1" } {
        scan [winfo id .] "0x%x" xmcp11_authentication_key
        io.outgoing "$authenticate $xmcp11_authentication_key"
        xmcp11.log "$#$" xmcp11_mcp ">"
        xmcp11.log "$authenticate " xmcp11_method ""
        xmcp11.logCR "$xmcp11_authentication_key" xmcp11_value ""

	set xmcp11_active 1


        set xscript ""
        catch { set xscript [worlds.get [worlds.get_current] XMCP11_AfterAuth] }
        if { $xscript != "" } {
            io.outgoing $xscript
        }
    }
}

proc xmcp11.do_data {} {

    set tag [request.get current tag]
    set lines "NOLINES"
    catch { set lines [request.get $tag xmcp11_lines] }
    if { $lines == "NOLINES" } {
    } {
    request.set $tag xmcp11_lines [concat $lines [list [request.get current data]]]
    }
}

proc xmcp11.do_END {} {
    set which current
    catch { set which [request.get current tag] }
    catch {
        set callback [request.get $which xmcp11_multiline_procedure]
        if { $callback != "" } {
	    request.set $which _lines [request.get $which xmcp11_lines]
            if { [info procs "xmcp11.do_callback_$callback"] != {} } {
                xmcp11.do_callback_$callback
            }
        }
    }
    request.destroy $which
}

###


proc xmcp11.controls {} {
    return {"XMCP/1.1" "xmcp11.callback"}
}

proc xmcp11.callback {} {
    set c .modules_xmcp11_controlpanel
    catch { destroy $c }

    toplevel $c

    window.place_nice $c

    $c configure -bd 0

    wm title    $c "XMCP/1.1 Control Panel"
    wm iconname $c "XMCP/1.1"

    frame $c.buttons

    checkbutton $c.buttons.usemcp \
	-padx 0 \
        -text "use xmcp/1.1" \
        -variable xmcp11_use

    checkbutton $c.buttons.xmcp11active \
	-padx 0 \
        -text "xmcp/1.1 active" \
        -variable xmcp11_active

    checkbutton $c.buttons.uselog \
	-padx 0 \
        -text "log xmcp/1.1" \
        -variable xmcp11_use_log

    button $c.buttons.close \
        -text "Close" \
        -command "destroy $c";
 
    pack append $c.buttons \
        $c.buttons.usemcp	{left padx 4} \
        $c.buttons.xmcp11active	{left padx 4} \
        $c.buttons.uselog	{left padx 4} \
        $c.buttons.close	{left padx 4}

    pack append $c \
        $c.buttons {fillx pady 4}
}
#
#

client.register mcp start
client.register mcp client_connected
client.register mcp incoming


#
#

proc mcp.client_connected {} {
    global mcp_log mcp_use mcp_use_log mcp_active mcp_authentication_key

    set mcp_authentication_key ""

    request.set current mcp_multiline_procedure ""
    request.set current mcp_lines ""

    set use [string tolower [worlds.get_generic off {} {} UseModuleMCP]]

    if { $use == "on" } {   
        set mcp_use 1
    } elseif { $use == "off" } {
        set mcp_use 0
    }
    ###

    set mcp_active 0

    set mcp_use_log 0
    return [modules.module_deferred]
}

proc mcp.start {} {
    global mcp_use mcp_use_log
    set mcp_use 1
    set mcp_use_log 0
    ###
    .output tag configure mcp_mcp	-foreground [colourdb.get darkgreen]
    .output tag configure mcp_type	-foreground [colourdb.get red]
    .output tag configure mcp_value	-foreground [colourdb.get blue]
    .output tag configure mcp_default

    preferences.register mcp {Out of Band} {
        { {directive UseModuleMCP} 
            {type boolean}
            {default Off}
            {display "Use MCP/1.0"} }
    }   
}


proc mcp.logCR { line tag io } { 
    global mcp_log mcp_use_log 

    if { $mcp_use_log == 0 } {
	return
    }
    window.displayCR $line $tag
}

proc mcp.log { line tag io } { 
    global mcp_log mcp_use_log 

    if { $mcp_use_log == 0 } {
	return
    }
    window.display $line $tag
}

proc mcp.incoming event {
    global mcp_log mcp_use mcp_active


    if { $mcp_use == 0 } {
        return [modules.module_deferred]
    }

    set line [db.get $event line]

    if { ([string match {#*} $line] == 0) && 
	 ([string match {@*} $line] == 0) } {
        return [modules.module_deferred]
    }

    if { [regexp {^#\$#([-a-zA-Z0-9*]*) *(.*)} $line throwaway type rest] } {


        if { ($type != "mcp") && ($mcp_active == 0) } {
            return [modules.module_deferred]
	}

        mcp.log "#$#" mcp_mcp "<"
        mcp.log "$type " mcp_type ""
        if { [mcp.parse $rest] } {
            catch mcp.do_$type
        }
        set last [string index $type [expr [string length $type] - 1]]
        if { $last == "*" } {
	    request.set current mcp_lines ""
	    ###
	    catch {
	    if { [set tag [request.get current tag]] } {
		request.duplicate current $tag
	    }
	    }
	    #
	    ###
	} {
            mcp.unset_header
        }
        return [modules.module_ok]
    }

    if { [regexp {^@@@(.*)} $line throwaway tail] } {
        if { [request.get current mcp_multiline_procedure] != "" } {
            mcp.log "@@@" mcp_mcp "<"
            mcp.logCR "$tail" mcp_default ""
            request.set current mcp_lines [concat [request.get current mcp_lines] [list $tail]]
            return [modules.module_ok]
        }
    }

    return [modules.module_deferred]
}

proc mcp.parse header {
    set first [lindex $header 0]
    if {![regexp ":" $first]} {
	request.set current _authentication-key $first
        mcp.log "$first " mcp_mcp ""
        set header [lrange $header 1 end]
    } {
	request.set current _authentication-key NULL
    }

    set keyword ""
    foreach item $header {
        if { $keyword != "" } {
	    request.set current $keyword $item
            mcp.log "$keyword: " mcp_mcp ""
            mcp.log "$item " mcp_value ""
            set keyword ""
        } {
            set keyword $item
            regsub ":" $keyword "" keyword
        }
    }
    mcp.logCR "" mcp_default ""
    return 1
}

proc mcp.authenticated {} {
    global mcp_authentication_key 
    if { [request.get current _authentication-key] == $mcp_authentication_key } {
        return 1
    }
    return 0
}

###
proc mcp.unset_header {} {
    request.destroy current

    request.set current mcp_multiline_procedure ""
    request.set current mcp_lines ""
}

###
###

proc mcp.do_mcp {} {
    global mcp_authentication_key mcp_active

    if { [request.get current version] == "1.0" } {
        scan [winfo id .] "0x%x" mcp_authentication_key
        io.outgoing "#$#authentication-key $mcp_authentication_key"
        mcp.log "#$#" mcp_mcp ">"
        mcp.log "authentication-key " mcp_method ""
        mcp.logCR "$mcp_authentication_key" mcp_value ""
	set mcp_active 1
    }
}

proc mcp.do_data {} {
    set tag [request.get current tag]
    request.set $tag mcp_lines [concat [request.get $tag mcp_lines] [list [request.get current data]]]
}

proc mcp.do_END {} {
    set which current
    catch {
    set which [request.get current tag]
    }
    if { [request.get $which mcp_multiline_procedure] != "" } {
	request.set $which _lines [request.get $which mcp_lines]
	mcp.do_callback_[request.get $which mcp_multiline_procedure]
    }
    request.destroy $which
}

###


proc mcp.controls {} {
    return {"MCP/1.0" "mcp.callback"}
}

proc mcp.callback {} {
    set c .modules_mcp_controlpanel
    catch { destroy $c }

    toplevel $c

    window.place_nice $c

    $c configure -bd 0

    wm title    $c "MCP/1.0 Control Panel"
    wm iconname $c "MCP/1.0"

    frame $c.buttons

    checkbutton $c.buttons.usemcp \
	-padx 0 \
        -text "use mcp" \
        -variable mcp_use

    checkbutton $c.buttons.mcpactive \
	-padx 0 \
        -text "mcp active" \
        -variable mcp_active

    checkbutton $c.buttons.uselog \
	-padx 0 \
        -text "log mcp" \
        -variable mcp_use_log

    button $c.buttons.close \
        -text "Close" \
        -command "destroy $c";
 
    pack append $c.buttons \
        $c.buttons.usemcp	{left padx 4} \
        $c.buttons.mcpactive	{left padx 4} \
        $c.buttons.uselog	{left padx 4} \
        $c.buttons.close	{left padx 4}

    pack append $c \
        $c.buttons {fillx pady 4}
}
#
#


proc mcp.do_edit* {} {
    if { [mcp.authenticated] == 1 } {
        request.set current mcp_multiline_procedure "edit*"
    }
}

proc mcp.do_callback_edit* {} {
    set which [request.current]
    
    set pre [request.get $which upload]
    set lines [request.get $which _lines]
    set post "."

    set title [request.get $which name]
    set icon_title [request.get $which name]

    edit.SCedit $pre $lines $post $title $icon_title
}
#
#

###                     
#
#
#
####

proc mcp.do_display-url {} {
    set netscape "netscape"

    if { [mcp.authenticated] == 1 } {
        set url [request.get current url]
        set xwin ""
        catch { set xwin [request.get current xwin] }
        if { $xwin != "" } {
            exec "$netscape" "-id $mcp_header(xwin) -noraise -remote openURL($ur
l)" &
        } {
            exec "$netscape" "-remote openURL($url)" &
        }
    }
}

#
#

client.register desktop start
proc desktop.start {} {
     global desktop_width desktop_height desktop_margin \
	 desktop_icon_width desktop_icon_height desktop_text_width \
	 desktop_data desktop_synthesise_callbacks

    set desktop_width	500
    set desktop_height	600
    set desktop_margin	10
    set desktop_icon_width	48
    set desktop_icon_height	48
    set desktop_text_width	100

    array set desktop_data "
        folder,bitmap 	dir.xbm
        note,bitmap 	text.xbm
        thing,bitmap 	burst.xbm
        player,bitmap 	person.xbm
        whiteboard,bitmap image2.xbm
        folder,fg 	[colourdb.get darkgreen]
        note,fg 	[colourdb.get blue]
        thing,fg 	[colourdb.get white]
        player,fg 	[colourdb.get red]
        whiteboard,fg 	[colourdb.get orange]
        folder,drag 	idir.xbm
        note,drag 	idaho.xbm
        thing,drag 	iburst.xbm
        player,drag 	iperson.xbm
        whiteboard,drag iimage2.xbm
    "

    set desktop_synthesise_callbacks 1
}

proc desktop.set_handler { desk handler } {
    global desktop_handler
    set desktop_handler($desk) $handler
}
proc desktop.get_handler desk {
    global desktop_handler
    return $desktop_handler($desk)
}

proc draganddrop.get { item property } {
    global draganddrop_data
    return $draganddrop_data($item:$property)
}

proc draganddrop.set { item property value } {
    global draganddrop_data
    set draganddrop_data($item:$property) $value
}

proc draganddrop.destroy item {
    global draganddrop_data
    foreach name [array names draganddrop_data "$item:*"] {
        unset draganddrop_data($name)
    }
}


proc desktop.create { title object type } {
    global tkmooLibrary \
        desktop_current desktop_data \
        desktop_width desktop_height desktop_item_callback

    set dt .[util.unique_id "dt"]

    toplevel $dt

    window.place_nice $dt

    $dt configure -bd 0 -highlightthickness 0

    wm title $dt $title
    wm iconname $dt $title

    bind $dt <Destroy> "desktop.destroy $dt"

    frame $dt.frame -bd 0 -highlightthickness 0

    set canvas $dt.frame.canvas

    canvas $canvas \
    	-background [option get . desktopBackground DesktopBackground] \
    	-relief flat \
        -bd 0 -highlightthickness 0 \
    	-scrollregion { 0 0 500 800 } \
    	-width 500 -height 300 \
    	-yscrollcommand "$dt.frame.vscroll set" \
    	-xscrollcommand "$dt.frame.bottom.hscroll set" 

    scrollbar $dt.frame.vscroll -command "$canvas yview" -highlightthickness 0
    window.set_scrollbar_look $dt.frame.vscroll

    frame $dt.frame.bottom \
	-bd 0 -highlightthickness 0

    frame $dt.frame.bottom.padding

    scrollbar $dt.frame.bottom.hscroll -command "$canvas xview" \
	-highlightthickness 0 \
	-orient horizontal
    window.set_scrollbar_look $dt.frame.bottom.hscroll

	pack $dt.frame.bottom.padding -side right
	pack $dt.frame.bottom.hscroll -side left -fill x -expand 1

    pack $dt.frame.bottom -side bottom -fill x
    pack $dt.frame.vscroll -side right -fill y

    bind $canvas <2>		"$canvas scan mark %x %y"
    bind $canvas <B2-Motion>	"$canvas scan dragto %x %y"

    pack $canvas -expand yes -fill both
    pack $dt.frame -expand yes -fill both

    set desktop_current ""

    draganddrop.set $canvas drop 1	
    set desktop_item_callback($canvas:objid) $object

    set desktop_item_callback($canvas:Drop) "@move that to this"

    set desktop_item_callback($canvas:type) $type

    after idle "desktop.padding_resize $dt"

    return $dt
}

proc desktop.padding_resize desktop {
    if { [winfo exists $desktop] == 1 } {
        set internal [$desktop.frame.vscroll cget -width]
        set external [$desktop.frame.vscroll cget -bd]
        set full [expr $internal + 2*$external]
        $desktop.frame.bottom.padding configure -width $full -height $full
    }
}

proc desktop.garbage_collect_icons dt {
    global desktop_item_callback
    foreach name [array names desktop_item_callback] {
        catch {
            if { [regexp "^$dt.frame.canvas.(nt.*):objid" $name throwaway icon] == 1 } {
	        destroy $dt.frame.canvas.$icon
            }
        }
        if { [regexp "^$dt.frame.canvas\\..*" $name throwaway] == 1 } {
            unset desktop_item_callback($name)
        }
    }
}

proc desktop.garbage_collect_all dt {
    global desktop_item_callback
    foreach name [array names desktop_item_callback "$dt.frame.canvas*"] {
        unset desktop_item_callback($name)
    }
}

proc desktop.destroy dt {
    global desktop_desktop 

    draganddrop.destroy $dt
    foreach foo [array names desktop_desktop] {
        if { $desktop_desktop($foo) == $dt } {
            io.outgoing "remove $foo from desk"
            unset desktop_desktop($foo)
	    desktop.garbage_collect_all $dt
            break
        }
    }
}

proc desktop.item { type text x y obj dt eOne eThree eDrop eDropped ePick } {
    global tkmooLibrary \
        desktop_data \
	desktop_item_callback \
	desktop_icon_width desktop_icon_height desktop_text_width \
	image_data

    set new_tag [util.unique_id "nt"]

    set canvas $dt.frame.canvas
    set graphic $canvas.$new_tag

    canvas $graphic \
	-background [option get . desktopBackground DesktopBackground] \
	-width $desktop_icon_width -height $desktop_icon_height \
        -highlightthickness 0 


    bindtags $graphic $graphic

    bind $graphic <1>                       "desktop.itemPick $dt %x %y %X %Y"
    bind $graphic <B1-Motion>               "desktop.itemDrag $dt %x %y %X %Y"
    bind $graphic <B1-ButtonRelease>        "desktop.itemDrop $dt %x %y %X %Y"
    bind $graphic <Double-1>                "desktop.itemOpen $dt %x %y %X %Y" 
    bind $graphic <Double-B3-ButtonRelease> "desktop.itemOpen3 $dt %x %y %X %Y"

    set i [image create bitmap \
	-foreground $desktop_data($type,fg) \
	-data $image_data($desktop_data($type,bitmap))]
    $graphic create image \
	[expr int($desktop_icon_width/2)] [expr int($desktop_icon_height/2)] \
	-image $i \
	-tags "$new_tag object"


    set ex $x
    set wy [expr $y + 40]
    set nn [$canvas create window $ex $wy \
	        -window $graphic \
	        -anchor s]

    $canvas create text $x $wy -text $text \
        -tags "$new_tag" -width $desktop_text_width \
	-anchor n \
	-justify center \
        -font [fonts.plain]

    set desktop_item_callback($canvas:$nn) $graphic

    draganddrop.set $graphic drag 1

    if { $type == "folder" } {
	draganddrop.set $graphic drop 1
    }

    if { $eDrop != "-" } {
	draganddrop.set $graphic drop 1
    };

    if { $eDropped != "-" } {
	draganddrop.set $graphic dropped 1
    };

    set desktop_item_callback($graphic:Open1)   $eOne
    set desktop_item_callback($graphic:Open3)   $eThree
    set desktop_item_callback($graphic:Drop)    $eDrop
    set desktop_item_callback($graphic:Dropped) $eDropped
    set desktop_item_callback($graphic:Pick)    $ePick

    set desktop_item_callback($graphic:type)    $type

    set desktop_item_callback($graphic:objid) $obj

    return $graphic
}

###
proc desktop.item_callback { hook item dt } {
    global desktop_item_callback
    if { ! [info exists desktop_item_callback($dt.$item:$hook)]} {
        window.displayOutput "no $dt.$item:$hook\n" ""
        update
    }
    return $desktop_item_callback($dt.$item:$hook)
}

proc desktop.build_callback { text this that } {
    regsub -all -nocase {this} $text $this foo
    regsub -all -nocase {that} $foo $that callback
    return $callback
}


proc desktop.itemOpen {dt x y X Y} {
    global desktop_item_callback

    set where [winfo containing $X $Y]

    set cb "-"
    catch { set cb [desktop.get_callback $where Open1] }
    if { $cb != "-" } {
	set objid $desktop_item_callback($where:objid)
        set new_cb [desktop.build_callback $cb $objid THAT] 
        io.outgoing $new_cb
    }
}

proc desktop.itemOpen3 {dt x y X Y} {
    global desktop_item_callback

    set where [winfo containing $X $Y]

    set cb "-"
    catch { set cb [desktop.get_callback $where Open3] }
    if { $cb != "-" } {
        set objid $desktop_item_callback($where:objid)
    	set new_cb [desktop.build_callback $cb $objid THAT]
    	io.outgoing $new_cb
    }
}

proc desktop.itemPick {dt x y X Y} {
    global desktop_lastX desktop_lastY desktop_current \
	desktop_height desktop_width desktop_margin \
	tkmooLibrary desktop_item_callback desktop_dragging

    set desktop_dragging 0

    set where [winfo containing $X $Y]

    catch {
    if { [draganddrop.get $where drag] == 1 } {
        set desktop_current $where

        set cb "-"
        catch { set cb [desktop.get_callback $where Pick] }
        if { $cb != "-" } {
            set objid $desktop_item_callback($where:objid)
            set new_cb [desktop.build_callback $cb $objid THAT]
            io.outgoing $new_cb
        }
    }
    }
}



proc desktop.itemDrag {dt x y X Y} {
    global desktop_current \
	desktop_width   \
	desktop_item_callback desktop_data \
	desktop_dragging \
	tkmooLibrary 

    if { $desktop_current == "" } { return }

    if { $desktop_dragging == 0 } {
	set desktop_dragging 1
        set where $desktop_current
        $where configure -cursor icon
    }
}


proc desktop.itemDrop {dt x y X Y} {
    global desktop_current \
	desktop_dragging \
	desktop_item_callback

    set desktop_dragging 0

    if { $desktop_current == "" } { return }

    set where [winfo containing $X $Y]
    $desktop_current configure -cursor {}

    set check_list ""


    set can_dropped 0
    catch { set can_dropped [draganddrop.get $desktop_current dropped] }

    if { $can_dropped == 1 } {

        set cb "-"
        catch { set cb [desktop.get_callback $desktop_current Dropped] }

        if { $cb != "-" } {
            set iobjid $desktop_item_callback($desktop_current:objid)
            set dobjid $desktop_item_callback($where:objid)
            set new_cb [desktop.build_callback $cb $iobjid $dobjid]
            io.outgoing $new_cb

            ###
            set old_location ""
            if { [regexp {^(.*)\.nt} $desktop_current throwaway location] == 1 } {
                set old_location $desktop_item_callback($location:objid)
            }

	    set check_list "$check_list $dobjid $iobjid $old_location"
        }

    } {
    }


    set can_drop 0
    catch { set can_drop [draganddrop.get $where drop] }

    if { $can_drop == 1 } {

        set cb "-"
        catch {
            set cb [desktop.get_callback $where Drop]
            set iobjid $desktop_item_callback($where:objid)
            set dobjid $desktop_item_callback($desktop_current:objid)
        }

        if { $iobjid == $dobjid } {
        } {

            if { $cb != "-" } {
                set new_cb [desktop.build_callback $cb $iobjid $dobjid]
                io.outgoing $new_cb
        

                set old_location ""
                if { [regexp {^(.*)\.nt} $desktop_current throwaway location] == 1 } {
                    set old_location $desktop_item_callback($location:objid)
                }
        
	        set check_list "$check_list $dobjid $iobjid $old_location"
            }
	}

    } {
    }

    if { $check_list != "" } {
        io.outgoing "check $check_list on desk"
    }

    set desktop_current ""
}

###

proc desktop.SCremove { object } {
    global desktop_desktop
    catch { destroy $desktop_desktop($object) }
}

proc desktop.SCdesktop { name type object parent location lines } {
    global desktop_desktop desktop_item_callback

    if { [info exists desktop_desktop($object)] } {
        set dt $desktop_desktop($object)

        $dt.frame.canvas delete all
	draganddrop.destroy $dt.frame.canvas
	draganddrop.set $dt.frame.canvas drop 1
	desktop.garbage_collect_icons $dt
    } {
        set dt [desktop.create $name $object $type]
        set desktop_desktop($object) $dt
    }


    wm title $dt "Desktop: $name"

    set xxx -1
    set yyy -1
    
    foreach line $lines {
        set xxx [expr int( ($xxx + 1) % 5)]

        if { $xxx == 0 } {
            set yyy [expr int( ($yyy + 1) )]
        }

        set xcoord [expr $xxx * 100 + 50]
        set ycoord [expr $yyy * 100 + 20]


            catch {unset object_data}

        catch {unset object_data}

	array set object_data {
	    location	""
	    parent	""
	    type	""
	    name	""
	    1		-
	    drop	-
	    dropped	-
	    3		-
	    pick	-
	}

        util.populate_array object_data $line

        set object	$object_data(object)
        set name	$object_data(name)
        set type	$object_data(type)
        set xone	$object_data(1)
        set xdrop	$object_data(drop)
        set xdropped	$object_data(dropped)
        set xthree	$object_data(3)
        set xpick	$object_data(pick)

        switch $type {
            note {
                desktop.item "note" "$name" $xcoord $ycoord \
                    "$object" $dt $xone $xthree $xdrop $xdropped $xpick
            }
            player {
                desktop.item "player" "$name" $xcoord $ycoord \
                    "$object" $dt $xone $xthree $xdrop $xdropped $xpick
            }
            whiteboard {
                desktop.item "whiteboard" "$name" $xcoord $ycoord \
                    "$object" $dt $xone $xthree $xdrop $xdropped $xpick
            }
            folder {
                desktop.item "folder" "$name" $xcoord $ycoord \
                    "$object" $dt $xone $xthree $xdrop $xdropped $xpick
            }
            default {
                desktop.item "thing" "$name" $xcoord $ycoord \
                    "$object" $dt $xone $xthree $xdrop $xdropped $xpick
            }
        }
    }
    after idle "wm deiconify $dt; raise $dt"
    return $dt
}

proc desktop.synthesise_callback { type event } {
    array set callback {
	Open1	-
	Open3	-
	Drop	-
	Dropped	-
	Pick	-
    }
    switch $type {
        note {
            set callback(Open1) "read this"
            set callback(Open3) "@edit this"
        }
        player {
            set callback(Open1) "put this on desk"
            set callback(Drop) "@move that to this"
        }
        whiteboard { 
            set callback(Open1) "watch this"
            set callback(Open3) "ignore this"
        }
        folder {
            set callback(Open1) "put this on desk"
            set callback(Drop) "put that in this"
        }
        room {
            set callback(Open1) "put this on desk"
            set callback(Drop) "@move that to this"
        }
        thing {
        } 
        default {
	    puts "desktop.synthesise_callback: Unknown type '$type'"
        } 
    }
    return $callback($event)
}


proc desktop.get_callback { item event } {
    global desktop_item_callback desktop_synthesise_callbacks
    set type $desktop_item_callback($item:type)
    set callback [desktop.synthesise_callback $type $event]


    if { $desktop_synthesise_callbacks == 0 } {
        catch { set callback $desktop_item_callback($item:$event) }
    }
    return $callback
}

#
#

###
proc xmcp11.do_desktop-remove {} {
    if { [xmcp11.authenticated] == 1 } {
        desktop.SCremove [request.get current object]
    }
}

proc xmcp11.do_desktop* {} {
    if { [xmcp11.authenticated] == 1 } {
        request.set current xmcp11_multiline_procedure "desktop*"
    }
}

proc xmcp11.do_callback_desktop* {} {
    set which [request.current]
    set name     [request.get $which name]
    set type     [request.get $which type]
    set object   [request.get $which object]
    set parent   [request.get $which parent]
    set location [request.get $which location]
    set lines    [request.get $which _lines]

    set desktop [desktop.SCdesktop $name $type $object $parent \
        $location $lines]
    desktop.set_handler $desktop xmcp11
}

#
#

proc mcp.do_desktop-remove {} {
        if { [mcp.authenticated] == 1 } {
        	desktop.SCremove [request.get current object]
        }
}

proc mcp.do_desktop* {} {
	if { [mcp.authenticated] == 1 } {
		request.set current mcp_multiline_procedure "desktop*"
	}
}

proc mcp.do_callback_desktop* {} {
	set which [request.current]
	set name     [request.get $which name]
	set type     [request.get $which type]
	set object   [request.get $which object]
	set parent   [request.get $which parent]
	set location [request.get $which location]
	set lines    [request.get $which _lines]

	set desktop [desktop.SCdesktop $name $type $object $parent \
		$location $lines]
        desktop.set_handler $desktop mcp
}
#
#

client.register whiteboard start
proc whiteboard.start {} {
    global whiteboard_funky
    global whiteboard_funky_bitmaps
    global whiteboard_width
    global whiteboard_height
    global whiteboard_margin

    set whiteboard_funky 1

    array set whiteboard_funky_bitmaps {
        line	line.xbm
        rectangle	rect.xbm
        oval	oval.xbm
        arrow	arro.xbm
        text	atoz.xbm
        move	slct.xbm
    }

    set whiteboard_width 600
    set whiteboard_height 400
    set whiteboard_margin 10
}

proc whiteboard.set_handler { whiteboard handler } {
    global whiteboard_handler
    set whiteboard_handler($whiteboard) $handler
}
proc whiteboard.get_handler whiteboard {
    global whiteboard_handler
    return $whiteboard_handler($whiteboard)
}


proc whiteboard.initialise {} {
    global whiteboard_colours whiteboard_contrast whiteboard_colour
    set whiteboard_colours { red orange yellow green blue black white }
    array set whiteboard_contrast {
	red	black
	orange	black
	yellow	black
	green	black
	blue	white
	black	white
	white	black
    }
    set whiteboard_colour           black
}

### hooks for XMCP or regular XMCP
#
#

proc whiteboard.SCshow { object title } {
    global whiteboard_whiteboard
    if { [info exists whiteboard_whiteboard($object)] } {
        set wb $whiteboard_whiteboard($object)
        $wb.draw.canvas delete all
    } {
        set wb [whiteboard.create $title]
        set whiteboard_whiteboard($object) $wb
    }
    after idle "wm deiconify $wb; raise $wb"
    return $wb
}

proc whiteboard.SCline { object x1 y1 x2 y2 colour } {
    global whiteboard_whiteboard
    if { [info exists whiteboard_whiteboard($object)] } {
        set dt $whiteboard_whiteboard($object)
        $dt.draw.canvas create line $x1 $y1 $x2 $y2 \
            -width 2 -fill [colourdb.get $colour]
    }
}

proc whiteboard.SCdelete { object id } {
    global whiteboard_whiteboard 
    if { [info exists whiteboard_whiteboard($object)] } {
        set dt $whiteboard_whiteboard($object)
        set item [whiteboard.id_to_item $id]
        $dt.draw.canvas delete $item
    }
}

proc whiteboard.SCmove { object id dx dy } {
    global whiteboard_whiteboard 
    if { [info exists whiteboard_whiteboard($object)] } {
        set dt $whiteboard_whiteboard($object)
        set item [whiteboard.id_to_item $id]
        $dt.draw.canvas move $item $dx $dy
    } {
        window.displayOutput "Can't find o: $object, i: $id\n" ""
    }
}  

proc whiteboard.SCdraw { object x1 y1 x2 y2 colour pen id text } {
    global whiteboard_whiteboard whiteboard_id
    if { [info exists whiteboard_whiteboard($object)] } {
        set dt $whiteboard_whiteboard($object)
        switch $pen {
            arrow {
                set identifier [$dt.draw.canvas create line \
                    $x1 $y1 $x2 $y2 \
                    -width 2 -fill [colourdb.get $colour] -arrow last] 
            }
            line {
                set identifier [$dt.draw.canvas create line \
                    $x1 $y1 $x2 $y2 \
                    -width 2 -fill [colourdb.get $colour]]
            }
            rectangle {
                set identifier [$dt.draw.canvas create rectangle \
                    $x1 $y1 $x2 $y2 \
                    -width 2 -outline [colourdb.get $colour]]
            }
            oval {
                set identifier [$dt.draw.canvas create oval \
                    $x1 $y1 $x2 $y2 \
                    -width 2 -outline [colourdb.get $colour]]
            }
            text {
                set identifier [$dt.draw.canvas create text $x1 $y1 \
                    -text "$text" -fill [colourdb.get $colour]]
            }
        }
        set whiteboard_id($identifier) $id
    }
}

proc whiteboard.SCclean object {
    global whiteboard_whiteboard
    if { [info exists whiteboard_whiteboard($object)] } {
        set dt $whiteboard_whiteboard($object)
        $dt.draw.canvas delete all
    }
}

proc whiteboard.SCgallery { object lines } {
    global whiteboard_whiteboard

    set loader $whiteboard_whiteboard($object).load

    catch {destroy $loader}

    toplevel $loader

    window.place_nice $loader

    $loader configure -bd 0 

    wm title $loader "Gallery"

    frame $loader.f
    scrollbar $loader.f.s -command "$loader.f.l yview" \
	-highlightthickness 0
    window.set_scrollbar_look $loader.f.s

    listbox $loader.f.l -yscroll "$loader.f.s set" \
	-highlightthickness 0 \
	-setgrid 1 \
	-background #ffffff \
	-height 10
    pack $loader.f.s -side right -fill y 
    pack $loader.f.l -side left -fill x

    entry $loader.e -font [fonts.fixedwidth]

    frame $loader.c 
    frame $loader.c.t
    button $loader.c.t.load -width 5 -text "Load" \
        -command "whiteboard.gallery_load $whiteboard_whiteboard($object)"

    button $loader.c.t.save -width 5 -text "Save" -command "destroy $loader" \
	-command "whiteboard.gallery_save $whiteboard_whiteboard($object)"

    frame $loader.c.b
    button $loader.c.b.delete -width 5 -text "Delete" \
	-command "whiteboard.gallery_remove $whiteboard_whiteboard($object)"

    button $loader.c.b.close -width 5 -text "Close" -command "destroy $loader"

    pack $loader.c.t.load -side left
    pack $loader.c.t.save -side right
    pack $loader.c.b.delete -side left
    pack $loader.c.b.close -side right

    pack $loader.c.t -side top -fill x
    pack $loader.c.b -side bottom -fill x

    pack $loader.f -fill x
    pack $loader.e -fill x
    pack $loader.c -fill x

    bind $loader.f.l <ButtonRelease-1> {
        set name [%W get @%x,%y]
        set wb [lindex [split %W "."] 1]
        set loader .$wb.load
        $loader.e delete 0 end
        $loader.e insert insert "$name"
    }

    bind $loader.f.l <Double-ButtonRelease-1> {
        set name [%W get @%x,%y]
        set wb [lindex [split %W "."] 1]
        set loader .$wb.load
        $loader.e delete 0 end
        $loader.e insert insert "$name"
	whiteboard.gallery_load .$wb
    }

    foreach l $lines {
	catch { unset foo }
	util.populate_array foo $l
	$loader.f.l insert end $foo(name)
    }
}

#
#

proc whiteboard.id_to_item id {
    global whiteboard_id
    set item ""
    foreach item [array names whiteboard_id] {
        if { $whiteboard_id($item) == $id } {
            break
        }
    }
    return $item
}

proc whiteboard.save {} {
}

proc whiteboard.get_gallery wb {
    set object [whiteboard.obj_from_dt $wb]
    io.outgoing "xmcp_gallery $object"
}

proc whiteboard.gallery_load wb {
    set object [whiteboard.obj_from_dt $wb]
    set what [$wb.load.e get]
    if { $what != "" } {
        io.outgoing "load \"$what\" in  $object"
    }
}

proc whiteboard.gallery_save wb {
    set object [whiteboard.obj_from_dt $wb]
    set what [$wb.load.e get]
    if { $what != "" } {
        io.outgoing "save $object as \"$what\""
    }
}

proc whiteboard.gallery_remove wb {
    set object [whiteboard.obj_from_dt $wb]
    set what [$wb.load.e get]
    if { $what != "" } {
        io.outgoing "remove \"$what\" from $object"
    }
}


proc whiteboard.refresh wb {
    set object [whiteboard.obj_from_dt $wb]
    io.outgoing "watch $object"
}

proc whiteboard.create title {
    if { ![util.use_native_menus] } {
	return [whiteboard.old.create $title]
    }
    global whiteboard_contrast whiteboard_colours tkmooLibrary \
        desktop_bitmap \
        whiteboard_width whiteboard_height whiteboard_margin \
        whiteboard_funky_bitmaps
    global image_data

    whiteboard.initialise

    set wb .[util.unique_id "wb"]

    toplevel $wb

    window.place_nice $wb

    $wb configure -bd 0 -highlightthickness 0

    wm title $wb "Whiteboard: $title"
    wm iconname $wb "$title"
    ###

    bind $wb <Destroy> "whiteboard.destroy $wb %W"

    ###
    frame $wb.draw -bd 0 -highlightthickness 0

	canvas $wb.draw.canvas \
		-scrollregion { 0 0 1000 800 } \
		-yscrollcommand "$wb.draw.vscroll set" \
		-xscrollcommand "$wb.draw.bottom.hscroll set" \
		-relief sunken -borderwidth 1 \
		-width 500 -height 300 \
		-highlightthickness 0 \
		-bg [colourdb.get lightblue]

        scrollbar $wb.draw.vscroll -command "$wb.draw.canvas yview" \
	    -highlightthickness 0
        window.set_scrollbar_look $wb.draw.vscroll

	frame $wb.draw.bottom \
	    -bd 0 -highlightthickness 0

	    frame $wb.draw.bottom.padding -height 8 -width 12 \
		-bd 0 -highlightthickness 0

        scrollbar $wb.draw.bottom.hscroll -command "$wb.draw.canvas xview" \
	    -highlightthickness 0 \
            -orient horizontal
        window.set_scrollbar_look $wb.draw.bottom.hscroll

        pack $wb.draw.bottom.padding \
	    -side right

	pack $wb.draw.bottom.hscroll \
	    -side left \
	    -fill x -expand 1

        pack $wb.draw.bottom -side bottom -fill x
        pack $wb.draw.vscroll -side right -fill y

	pack $wb.draw.canvas -fill both -expand 1
	bind $wb.draw.canvas <1>	        "whiteboard.pen-down $wb %x %y"
	bind $wb.draw.canvas <B1-Motion>        "whiteboard.pen-drag $wb %x %y"
	bind $wb.draw.canvas <B1-ButtonRelease> "whiteboard.pen-up   $wb %x %y"
	bind $wb.draw.canvas <3>		"whiteboard.delete   $wb %x %y"


	###
	menu $wb.control -tearoff 0 -relief raised -bd 1
	$wb configure -menu $wb.control


	$wb.control add cascade \
	    -label "File" \
	    -underline 0 \
	    -menu $wb.control.file

	menu $wb.control.file
	$wb.control.file add command \
	    -label "Gallery" \
	    -underline 0 \
	    -command "whiteboard.get_gallery $wb"
	window.hidemargin $wb.control.file

	$wb.control.file add command \
	    -label "Quit" \
	    -underline 0 \
	    -command "destroy $wb"
	window.hidemargin $wb.control.file

	$wb.control add cascade \
	    -label "Edit" \
	    -underline 0 \
	    -menu $wb.control.edit

	menu $wb.control.edit
	$wb.control.edit add command \
	    -label "Cut" \
	    -command "whiteboard.clean $wb"
	window.hidemargin $wb.control.edit
	$wb.control.edit add command \
	    -label "Copy" \
	    -command "whiteboard.clean $wb"
	window.hidemargin $wb.control.edit
	$wb.control.edit add command \
	    -label "Paste" \
	    -command "whiteboard.clean $wb"
	window.hidemargin $wb.control.edit
	$wb.control.edit add separator
	$wb.control.edit add command \
	    -label "Clear" \
	    -command "whiteboard.clean $wb"
	window.hidemargin $wb.control.edit
	$wb.control.edit add command \
	    -label "Refresh" \
	    -command "whiteboard.refresh $wb"
	window.hidemargin $wb.control.edit

	$wb.control.edit entryconfigure "Cut" -state disabled
	$wb.control.edit entryconfigure "Paste" -state disabled
	$wb.control.edit entryconfigure "Copy" -state disabled

	$wb.control add cascade \
            -label "Pen" \
            -underline 0 \
            -menu $wb.control.pen

        menu $wb.control.pen
        foreach pen { line rectangle oval arrow text move } {
	    set i [image create bitmap bitmap_$pen -data $image_data($whiteboard_funky_bitmaps($pen))]
            $wb.control.pen add command \
		-image $i \
                -underline 0 \
                -command "whiteboard.set_pen $wb $pen"
	    window.hidemargin $wb.control.pen
	}

	$wb.control add cascade \
            -label "Colour" \
            -underline 0 \
            -menu $wb.control.colour

	menu $wb.control.colour

	foreach colour $whiteboard_colours {
	    $wb.control.colour add command \
	        -label   "$colour" \
	        -underline 0 \
	        -background [colourdb.get $colour] \
	        -foreground [colourdb.get $whiteboard_contrast($colour)] \
	        -command "whiteboard.set_colour $wb $colour"
	    window.hidemargin $wb.control.colour
	}

	###

	whiteboard.set_colour $wb black
	whiteboard.set_pen $wb line



	###

	pack $wb.draw -side bottom -expand yes -fill both

        after idle "whiteboard.padding_resize $wb"

	return $wb
}

proc whiteboard.padding_resize whiteboard {
    if { [winfo exists $whiteboard] == 1 } {
        set internal [$whiteboard.draw.vscroll cget -width]
        set external [$whiteboard.draw.vscroll cget -bd]
        set full [expr $internal + 2*$external]
        $whiteboard.draw.bottom.padding configure -width $full -height $full
    }
}

proc whiteboard.old.create title {
    global whiteboard_contrast whiteboard_colours tkmooLibrary \
        desktop_bitmap \
        whiteboard_width whiteboard_height whiteboard_margin \
        whiteboard_funky_bitmaps
    global image_data

    whiteboard.initialise

    set wb .[util.unique_id "wb"]

    toplevel $wb

    window.place_nice $wb

    $wb configure -bd 0

    wm title $wb "Whiteboard: $title"
    wm iconname $wb "$title"
    ###

    bind $wb <Destroy> "whiteboard.destroy $wb %W"

    ###
    frame $wb.draw

	canvas $wb.draw.canvas \
		-scrollregion { 0 0 1000 800 } \
		-yscrollcommand "$wb.draw.vscroll set" \
		-xscrollcommand "$wb.draw.bottom.hscroll set" \
		-relief sunken -borderwidth 2 \
		-width 500 -height 300 \
		-highlightthickness 0 \
		-bg [colourdb.get lightblue]

        scrollbar $wb.draw.vscroll -command "$wb.draw.canvas yview" \
	    -highlightthickness 0
        window.set_scrollbar_look $wb.draw.vscroll

	frame $wb.draw.bottom
	    frame $wb.draw.bottom.padding -height 14 -width 14

        scrollbar $wb.draw.bottom.hscroll -command "$wb.draw.canvas xview" \
	    -highlightthickness 0 \
            -orient horizontal
        window.set_scrollbar_look $wb.draw.bottom.hscroll

        pack $wb.draw.bottom.padding -side right
	pack $wb.draw.bottom.hscroll -side left -fill x -expand 1

        pack $wb.draw.bottom -side bottom -fill x

        pack $wb.draw.vscroll -side right -fill y

	pack $wb.draw.canvas -fill both -expand 1
	bind $wb.draw.canvas <1>	        "whiteboard.pen-down $wb %x %y"
	bind $wb.draw.canvas <B1-Motion>        "whiteboard.pen-drag $wb %x %y"
	bind $wb.draw.canvas <B1-ButtonRelease> "whiteboard.pen-up   $wb %x %y"
	bind $wb.draw.canvas <3>		"whiteboard.delete   $wb %x %y"


	###
	frame $wb.control


	menubutton $wb.control.file \
	    -text "File" \
	    -underline 0 \
	    -menu $wb.control.file.m

	menu $wb.control.file.m
	$wb.control.file.m add command \
	    -label "Gallery" \
	    -underline 0 \
	    -command "whiteboard.get_gallery $wb"
	window.hidemargin $wb.control.file.m
	$wb.control.file.m add command \
	    -label "Quit" \
	    -underline 0 \
	    -command "destroy $wb"
	window.hidemargin $wb.control.file.m

	menubutton $wb.control.edit \
	    -text "Edit" \
	    -underline 0 \
	    -menu $wb.control.edit.m

	menu $wb.control.edit.m
	$wb.control.edit.m add command \
	    -label "Cut" \
	    -command "whiteboard.clean $wb"
	window.hidemargin $wb.control.edit.m
	$wb.control.edit.m add command \
	    -label "Copy" \
	    -command "whiteboard.clean $wb"
	window.hidemargin $wb.control.edit.m
	$wb.control.edit.m add command \
	    -label "Paste" \
	    -command "whiteboard.clean $wb"
	window.hidemargin $wb.control.edit.m
	$wb.control.edit.m add separator
	$wb.control.edit.m add command \
	    -label "Clear" \
	    -command "whiteboard.clean $wb"
	window.hidemargin $wb.control.edit.m
	$wb.control.edit.m add command \
	    -label "Refresh" \
	    -command "whiteboard.refresh $wb"
	window.hidemargin $wb.control.edit.m

	$wb.control.edit.m entryconfigure "Cut" -state disabled
	$wb.control.edit.m entryconfigure "Paste" -state disabled
	$wb.control.edit.m entryconfigure "Copy" -state disabled

	menubutton $wb.control.pen \
		-text "Pen" \
		-underline 0 \
		-menu $wb.control.pen.menu

        menu $wb.control.pen.menu
        foreach pen { line rectangle oval arrow text move } {
	    set i [image create bitmap bitmap_$pen -data $image_data($whiteboard_funky_bitmaps($pen))]
            $wb.control.pen.menu add command \
		-image $i \
                -underline 0 \
                -command "whiteboard.set_pen $wb $pen"
	    window.hidemargin $wb.control.pen.menu
	}

	menubutton $wb.control.colour \
		-text "Colour" \
		-underline 0 \
		-menu $wb.control.colour.menu

	menu $wb.control.colour.menu

	foreach colour $whiteboard_colours {
	    $wb.control.colour.menu add command \
	        -label   "$colour" \
	        -underline 0 \
	        -background [colourdb.get $colour] \
	        -foreground [colourdb.get $whiteboard_contrast($colour)] \
	        -command "whiteboard.set_colour $wb $colour"
	    window.hidemargin $wb.control.colour.menu
	}


	###
	frame $wb.control.indicator
	label $wb.control.indicator.pen -anchor center -text "pen"
	pack $wb.control.indicator.pen

	whiteboard.set_colour $wb black
	whiteboard.set_pen $wb line

	pack append $wb.control \
		$wb.control.file left \
		$wb.control.edit left \
		$wb.control.pen left \
		$wb.control.colour left

	pack $wb.control.indicator -fill x


	###

	pack $wb.control -side top -fill x
	pack $wb.draw -side bottom -expand yes -fill both

	return $wb
}

proc whiteboard.clean wb {
    set object [whiteboard.obj_from_dt $wb]
    whiteboard.CSclean $object
}

proc whiteboard.set_colour { wb colour } {
    global whiteboard_colour whiteboard_contrast
    set whiteboard_colour $colour
    $wb.control.colour configure \
	-background [colourdb.get $colour] \
        -foreground [colourdb.get $whiteboard_contrast($colour)]
}

proc whiteboard.set_pen { wb pen } {
    global whiteboard_pen whiteboard_funky_bitmaps tkmooLibrary
    set whiteboard_pen $pen
    return 
    $wb.control.indicator.pen configure \
	-bitmap @[file join $tkmooLibrary images $whiteboard_funky_bitmaps($pen)]
}

proc whiteboard.destroy { dt win } {
    global whiteboard_whiteboard whiteboard_id


    catch {
        foreach item [array names whiteboard_id] {
            unset whiteboard_id($item)
        }
    }

    catch {
	set object [whiteboard.obj_from_dt $dt]
	unset whiteboard_whiteboard($object)
	whiteboard.CSignore $object
    }
}


#
#

proc whiteboard.pen-down { dt x y } {
    global whiteboard_x1 whiteboard_y1 \
        whiteboard_funky \
        whiteboard_x2 whiteboard_y2 \
        whiteboard_pen whiteboard_item_to_move

    set cx [expr int([$dt.draw.canvas canvasx $x])]
    set cy [expr int([$dt.draw.canvas canvasy $y])]

    if { $whiteboard_funky } {
        set x $cx
        set y $cy
    }

    set whiteboard_x1 $x
    set whiteboard_y1 $y
    set whiteboard_x2 $x
    set whiteboard_y2 $y

    if { $whiteboard_pen == "move" } {
        set item [$dt.draw.canvas find withtag current]
        if { $item != "" } {
            set whiteboard_item_to_move $item
            whiteboard.clone $dt $item
        }
    }
}

#

proc whiteboard.bounds_check { a maxa margin } {
    return $a

    if { $a < $margin } { return $margin }
    if { $a > [set foo [expr $maxa - $margin]] } { return $foo }
    return $a
}

proc whiteboard.pen-drag { dt x y } {
    global whiteboard_x1 whiteboard_y1 whiteboard_x2 whiteboard_y2 \
        whiteboard_funky \
        whiteboard_pen whiteboard_item_to_move \
        whiteboard_width whiteboard_height whiteboard_margin

    set cx [expr int([$dt.draw.canvas canvasx $x])]
    set cy [expr int([$dt.draw.canvas canvasy $y])]

    if { $whiteboard_funky } {
        set x $cx
        set y $cy
    }

    set x [whiteboard.bounds_check $x $whiteboard_width $whiteboard_margin]
    set y [whiteboard.bounds_check $y $whiteboard_height $whiteboard_margin]

    set whiteboard_x2 $x
    set whiteboard_y2 $y


    $dt.draw.canvas delete ghost

    switch $whiteboard_pen {
	text {
            #do nothing
	}
	move {
            if { $whiteboard_item_to_move == "" } { return };

            set clone [whiteboard.clone $dt $whiteboard_item_to_move]
            set dx [expr $whiteboard_x2 - $whiteboard_x1]
            set dy [expr $whiteboard_y2 - $whiteboard_y1]
            $dt.draw.canvas move $clone $dx $dy
	}
	arrow {
            $dt.draw.canvas create line \
            $whiteboard_x1 $whiteboard_y1 \
            $whiteboard_x2 $whiteboard_y2 -tag ghost -arrow last
	}
	default {
            $dt.draw.canvas create $whiteboard_pen \
            $whiteboard_x1 $whiteboard_y1 \
            $whiteboard_x2 $whiteboard_y2 -tag ghost 
	}
    }
}

proc whiteboard.pen-up { dt x y } {
    global whiteboard_x1 whiteboard_y1 whiteboard_x2 whiteboard_y2 \
        whiteboard_funky \
        whiteboard_colour whiteboard_pen \
        whiteboard_item_to_move whiteboard_id \
        whiteboard_width whiteboard_height whiteboard_margin

    set cx [expr int([$dt.draw.canvas canvasx $x])]
    set cy [expr int([$dt.draw.canvas canvasy $y])]

    if { $whiteboard_funky } {
        set x $cx
        set y $cy
    }

    $dt.draw.canvas delete ghost

    set x [whiteboard.bounds_check $x $whiteboard_width $whiteboard_margin]
    set y [whiteboard.bounds_check $y $whiteboard_height $whiteboard_margin]

    set whiteboard_x2 $x
    set whiteboard_y2 $y

    set object [whiteboard.obj_from_dt $dt]

    if { $whiteboard_pen == "text" } {
        whiteboard.get_text $object $whiteboard_colour \
            $whiteboard_pen $whiteboard_x1 $whiteboard_y1
    } elseif { $whiteboard_pen == "move" } {
        if { $whiteboard_item_to_move == "" } { 
	    return 
	}
        set dx [expr $whiteboard_x2 - $whiteboard_x1]
        set dy [expr $whiteboard_y2 - $whiteboard_y1]
        whiteboard.CSmove $object $whiteboard_id($whiteboard_item_to_move) \
	    $dx $dy
    } {
        whiteboard.CSdraw_not_text $object $whiteboard_colour \
            $whiteboard_pen \
            $whiteboard_x1 $whiteboard_y1 \
            $whiteboard_x2 $whiteboard_y2
    }
    set whiteboard_item_to_move ""
}


proc whiteboard.get_text { object colour pen x1 y1 } {
    global whiteboard_scratch

    set win .wb_g_t

    catch { destroy $win };

    toplevel $win

    window.place_nice $win

    $win configure -bd 0

	wm title $win "Enter text"
	wm iconname $win "Enter Text"

    frame $win.entries
    label $win.entries.t -text "Text:"
	text $win.entries.text \
	    -highlightthickness 0 \
	    -width 40 \
	    -height 5 \
	    -font [fonts.get fixedwidth] \
	    -background [colourdb.get pink]

    focus $win.entries.text

    pack $win.entries.t    -side left
    pack $win.entries.text -side left

    ###
    set whiteboard_scratch($win:object) $object
    set whiteboard_scratch($win:colour) $colour
    set whiteboard_scratch($win:pen) $pen
    set whiteboard_scratch($win:x1) $x1
    set whiteboard_scratch($win:y1) $y1

    ###

    button $win.connect -text "Ok" \
        -command { 
	whiteboard.set_text 
	whiteboard.destroy_text
	}

    button $win.cancel -text "Cancel" -command "whiteboard.destroy_text"

    pack $win.entries
    pack $win.connect -side left
    pack $win.cancel -side right
}

proc whiteboard.destroy_text {} {
    global whiteboard_scratch
    set win .wb_g_t
    unset whiteboard_scratch
    destroy $win
}

proc whiteboard.set_text {} {
    global whiteboard_scratch
    set win .wb_g_t

    set object $whiteboard_scratch($win:object) 
    set colour $whiteboard_scratch($win:colour)
    set pen    $whiteboard_scratch($win:pen)
    set x1     $whiteboard_scratch($win:x1)
    set y1     $whiteboard_scratch($win:y1)

        set text [$win.entries.text get 1.0 end]
        regsub -all "\n" $text "\\\\\\n" text

    whiteboard.CSdraw_yes_text \
	$object $colour $pen $x1 $y1 "$text"
}

proc whiteboard.obj_from_dt dt {
    global whiteboard_whiteboard
    set object ""
    foreach object [array names whiteboard_whiteboard] {
        if { $whiteboard_whiteboard($object) == $dt } {
            break
        }
    }       
    return $object
}

proc whiteboard.delete { dt x y } {
    global whiteboard_id 
    set item [$dt.draw.canvas find withtag current]

    if { $item == "" } {
        return
    }
    set object [whiteboard.obj_from_dt $dt]
    whiteboard.CSdelete $object $whiteboard_id($item)
}


proc whiteboard.clone { dt id } {
    set type [$dt.draw.canvas type $id]
    set coords [$dt.draw.canvas coords $id]
    set x1 [lindex $coords 0]
    set y1 [lindex $coords 1]
    set x2 [lindex $coords 2]
    set y2 [lindex $coords 3]
    set clone ""
    switch $type {
        arrow {
            set clone [$dt.draw.canvas create line $x1 $y1 $x2 $y2 \
                -fill "red" -tag ghost -arrow last]
        }
        line {
            set clone [$dt.draw.canvas create line $x1 $y1 $x2 $y2 \
                -fill "red" -tag ghost]
        }
        rectangle {
            set clone [$dt.draw.canvas create rectangle $x1 $y1 $x2 $y2 \
                -outline "red" -tag ghost]
        }
        oval {
            set clone [$dt.draw.canvas create oval $x1 $y1 $x2 $y2 \
                -outline "red" -tag ghost]
        }
        text {
            set text [$dt.draw.canvas itemcget $id -text]
            set clone [$dt.draw.canvas create text $x1 $y1 -text $text \
                -fill "red" -tag ghost]
        }
        default {
            puts "Unknown type $type"
        }
    }
    return $clone
}
#
#

proc xmcp11.do_whiteboard-gallery* {} {
    if { [xmcp11.authenticated] == 1 } {
        request.set current xmcp11_multiline_procedure "whiteboard-gallery*"
    }
}

proc xmcp11.do_callback_whiteboard-gallery* {} {
    set which [request.current]
    set object [request.get $which object]
    set lines [request.get $which _lines]
    whiteboard.SCgallery $object $lines
}

proc xmcp11.do_whiteboard-show {} {
    if { [xmcp11.authenticated] != 1 } { return }

    set which [request.current]

    set name "no title"
    catch { set name [request.get $which name] }
    set object [request.get $which object]

    set whiteboard [whiteboard.SCshow $object $name]
    whiteboard.set_handler $whiteboard xmcp11
}

proc xmcp11.do_whiteboard-line {} {
    if { [xmcp11.authenticated] != 1 } { return }

    set which [request.current]
    set object [request.get $which object]
    set x1 [request.get $which x1]
    set y1 [request.get $which y1]
    set x2 [request.get $which x2]
    set y2 [request.get $which y2]
    set colour [request.get $which colour]

    whiteboard.SCline $object \
        $x1 $y1 \
        $x2 $y2 $colour
}

proc xmcp11.do_whiteboard-delete {} {
    if { [xmcp11.authenticated] != 1 } { return }

    set which [request.current]
    set object [request.get $which object]
    set id [request.get $which id]

    whiteboard.SCdelete $object $id
}

proc xmcp11.do_whiteboard-move {} {
    if { [xmcp11.authenticated] != 1 } { return }

    set which [request.current]
    set object [request.get $which object]
    set id [request.get $which id]
    set dx [request.get $which dx]
    set dy [request.get $which dy]
	
    whiteboard.SCmove $object $id \
        $dx $dy
}

proc xmcp11.do_whiteboard-draw {} {
    if { [xmcp11.authenticated] != 1 } { return }

    set which [request.current]
    set text "UNDEFINED"
    catch { 
	set text [request.get $which text]
	regsub -all "\\\\n" $text "\n" text 
    }
    set x2 "UNDEFINED"
    set y2 "UNDEFINED"
    catch { set x2 [request.get $which x2] }
    catch { set y2 [request.get $which y2] }

    set object [request.get $which object]
    set x1 [request.get $which x1]
    set y1 [request.get $which y1]
    set colour [request.get $which colour]
    set pen [request.get $which pen]
    set id [request.get $which id]

    whiteboard.SCdraw $object \
        $x1 $y1 \
        $x2 $y2 \
        $colour $pen \
        $id $text
}

proc xmcp11.do_whiteboard-clean {} {
    if { [xmcp11.authenticated] != 1 } { return }

    set which [request.current]
    set object [request.get $which object]
    whiteboard.SCclean $object
}

###
#
proc whiteboard.CSignore { object } {
    io.outgoing "ignore $object"
}

proc whiteboard.CSmove { object id dx dy } {
    io.outgoing "move $id $dx $dy on $object"
}

proc whiteboard.CSdraw_not_text { object colour pen x1 y1 x2 y2 } {
    io.outgoing "draw $colour $pen $x1 $y1 $x2 $y2 on $object"
}

proc whiteboard.CSdraw_yes_text { object colour pen x1 y1 text } {
    io.outgoing "draw $colour $pen $x1 $y1 \"$text\" on $object"
}

proc whiteboard.CSdelete { object id } {
    io.outgoing "delete $id in $object"
}

proc whiteboard.CSclean { object } {
    io.outgoing "clean $object"
}
#
#

#
#
#

client.register awns start 60

proc awns.start {} {
    awns.create_worlds_entry
    window.menu_help_add "Visit Moo.Awns.Com" awns.do_connect
}

proc awns.create_worlds_entry {} {
    set host "moo.awns.com"

    if { [set world [awns.worlds_entry]] == -1 } {
        set world [worlds.create_new_world]
        worlds.set $world ShortList On
        worlds.set $world IsGuestAtMooDotAwnsDotCom 1
    }


    worlds.set_if_different $world Name "Guest@Moo.Awns.Com"
    worlds.set_if_different $world Host $host
    worlds.set_if_different $world Port 8888
    worlds.set_if_different $world Login guest
    worlds.set_if_different $world ConnectScript "connect %u %p"

    open.fill_listbox
    window.post_connect
}

proc awns.worlds_entry {} {
    global worlds_worlds
    foreach world $worlds_worlds {
        set is -1
        catch { set is [worlds.get $world IsGuestAtMooDotAwnsDotCom] }
        if { $is == 1 } {
            return $world
        }
    }
    return -1
}

proc awns.do_connect {} {
    awns.create_worlds_entry
    set world [awns.worlds_entry]
    client.connect_world $world
}
#
#

client.register local_edit start 40
client.register local_edit client_connected 40
client.register local_edit incoming 40

proc local_edit.start {} {
    global local_edit_use local_edit_receiving
    set local_edit_use 0
    set local_edit_receiving 0

    preferences.register local_edit {Out of Band} {
	{ {directive UseModuleLocalEdit}
	    {type boolean}
	    {default Off}
	    {display "Old-style local edit"} }
        }
}

proc local_edit.client_connected {} {
    global local_edit_use local_edit_receiving

    set local_edit_receiving 0

    request.set current local_edit_multiline_procedure ""
    request.set current local_edit_lines ""

    set use [string tolower [worlds.get_generic off {} {} UseModuleLocalEdit]]

    if { $use == "on" } {
        set local_edit_use 1
    } elseif { $use == "off" } {
        set local_edit_use 0
    }

    ###
    return [modules.module_deferred]
}

proc local_edit.incoming event {
    global local_edit_use local_edit_receiving

    if { $local_edit_use == 0 } {
        return [modules.module_deferred]
    }

    set line [db.get $event line]

    if { $local_edit_receiving == 1 } {
        request.set current local_edit_lines [concat [request.get current local_edit_lines] [list $line]]

	if { $line == "." } {
	    set local_edit_receiving 0
	    set type [request.get current _type]
	    catch local_edit.do_callback_$type
            local_edit.unset_header
	}

        return [modules.module_ok]
    }

    if { [string match {#*} $line] == 0 } {
	return [modules.module_deferred]
    }

    if { [regexp {^#\$# ([-a-zA-Z0-9*]*) *(.*)} $line throwaway type rest] } {
	if { ([info procs "local_edit.do_$type"] != {}) && 
	     [local_edit.parse $rest] } {
	    request.set current _type $type
            local_edit.do_$type
            set local_edit_receiving 1

            request.set current local_edit_lines ""
            return [modules.module_ok]
	}
    }

    return [modules.module_deferred]
}

proc local_edit.parse header {
    request.set current _authentication-key NULL
    if { [regexp {name: (.+) upload: (.+)$} $header throwaway name upload] == 1 } {
	request.set current name $name
	request.set current upload $upload
	return 1
    }
    return 1
}

proc local_edit.authenticated {} {
    global local_edit_authentication_key 
    return 1
    if { [request.get current _authentication-key] == $local_edit_authentication_key } {
        return 1
    }
    return 0
}

proc local_edit.unset_header {} {
    request.destroy current

    request.set current local_edit_multiline_procedure ""
    request.set current local_edit_lines ""
}

###

proc local_edit.controls {} {
    return {"LocalEdit" "local_edit.callback"}
}

proc local_edit.callback {} {
    set c .modules_local_edit_controlpanel
    catch { destroy $c }

    toplevel $c

    window.place_nice $c

    $c configure -bd 0

    wm title    $c "LocalEdit Control Panel"
    wm iconname $c "LocalEdit"

    frame $c.buttons

    checkbutton $c.buttons.usele \
	-padx 0 \
        -text "use local_edit" \
        -variable local_edit_use

    button $c.buttons.close \
        -text "Close" \
        -command "destroy $c";
 
    pack append $c.buttons \
        $c.buttons.usele	{left padx 4} \
        $c.buttons.close	{left padx 4}

    pack append $c \
        $c.buttons {fillx pady 4}
}
#
#

proc local_edit.do_edit {} {
    if { [local_edit.authenticated] == 1 } {
        request.set current local_edit_multiline_procedure "edit"
    }
}

proc local_edit.do_callback_edit {} {
    set which current
    catch { set which [request.get current tag] }
    set pre [request.get $which upload]

    set lines [request.get $which local_edit_lines]
    set post ""

    set title [request.get $which name]
    set icon_title [request.get $which name]

    edit.SCedit "$pre" $lines "$post" $title $icon_title
}
#
#

client.register tkmootag start 60
client.register tkmootag client_connected
client.register tkmootag incoming
client.register tkmootag reconfigure_fonts


proc tkmootag.client_connected {} {
    global tkmootag_use tkmootag_lineTagList tkmootag_fixed

    set use [string tolower [worlds.get_generic on {} {} UseModuleTKMOOTAG]]
    if { $use == "on" } {
        set tkmootag_use 1
    } elseif { $use == "off" } {
        set tkmootag_use 0
    }

    set tkmootag_fixed 0

    set tkmootag_lineTagList {}

    tkmootag.reconfigure_fonts

    return [modules.module_deferred]
}

proc tkmootag.initialise_text_widget w {
    $w tag configure tkmootag_jtext_default -font [fonts.plain]
    $w tag configure tkmootag_header -font [fonts.header]
    $w tag configure tkmootag_header -foreground [colourdb.get darkgreen]
    $w tag configure tkmootag_bold -foreground [colourdb.get red]
    $w tag configure tkmootag_italic -foreground [colourdb.get orange]
    $w tag configure tkmootag_symbol -foreground [colourdb.get orange]
}

proc tkmootag.reconfigure_fonts {} {
    tkmootag.initialise_text_widget .output
    return [modules.module_deferred]
}

proc tkmootag.start {} {
    global tkmootag_use
    set tkmootag_use 1


    tkmootag.initialise_text_widget .output


    mcp21.register dns-com-awns-jtext 1.0 \
        dns-com-awns-jtext tkmootag.do_dns_com_awns_jtext
}

proc tkmootag.do_dns_com_awns_jtext {} {
}

proc tkmootag.incoming event {
    global tkmootag_use

    if { $tkmootag_use == 0 } {
        return [modules.module_deferred]
    }

    set line [db.get $event line]

    if { [string match {t*} $line] == 0 } {
        return [modules.module_deferred]
    }

    if { [regexp {^tkmootag: (.*)} $line throwaway msg] } {
	tkmootag.writeTextLine $msg .output {end - 1 chars}
        return [modules.module_ok]
    }

    return [modules.module_deferred]
}

#





proc tkmootag.car list { lindex $list 0 }
proc tkmootag.cdr list { concat [lrange $list 1 end] }

proc tkmootag.writeText {section t mark} {
  set tagName [tkmootag.car $section]
  if {[string index $tagName 0] == "~"} then {
    window.display "" {} $t
    set start [$t index $mark]
    window.display [string range $section 3 [expr [string length $section] - 2]] tkmootag_jtext_default $t
    return $start
  }
  set tagName [tkmootag.car [tkmootag.car $section]]
  return [tkmootag.writeText_$tagName [tkmootag.car $section] $t $mark]
}

proc tkmootag.writeText_bold {section t mark} {
  global tkmootag_lineTagList
  set start [tkmootag.writeText [tkmootag.cdr $section] $t $mark]
  lappend tkmootag_lineTagList [list tkmootag_bold $start [$t index $mark]]
  return $start
}

proc tkmootag.writeText_italic {section t mark} {
  global tkmootag_lineTagList
  set start [tkmootag.writeText [tkmootag.cdr $section] $t $mark]
  lappend tkmootag_lineTagList [list tkmootag_italic $start [$t index $mark]]
  return $start
}

proc tkmootag.writeText_header {section t mark} {
  global tkmootag_lineTagList
  set start [tkmootag.writeText [tkmootag.cdr $section] $t $mark]
  lappend tkmootag_lineTagList [list tkmootag_header $start [$t index $mark]]
  return $start
}

proc tkmootag.writeText_arrow {section t mark} {
  global tkmootag_lineTagList
  set start [$t index $mark]
  window.display "\254" {} $t
  lappend tkmootag_lineTagList [list tkmootag_symbol $start [$t index $mark]]
  return $start
}

proc tkmootag.writeText_link {section t mark} {
    global tkmootag_lineTagList

    set start [tkmootag.writeText [tkmootag.cdr [tkmootag.cdr $section]] $t $mark]
    set newTag [util.unique_id tkmootag]
    set callback [tkmootag.car [tkmootag.cdr $section]]



    regsub -all {\\} $callback "" callback

    window.hyperlink.link $t $newTag tkmootag.do_hyperlink
    $t tag bind $newTag <Leave> "+tkmootag.set_hyperlink_callback \"\""
    regsub -all { } $callback {\ } callback
    set callback [tkmootag.escape_tcl_meta $callback]
    $t tag bind $newTag <Enter> "+tkmootag.set_hyperlink_callback $callback"


    lappend tkmootag_lineTagList [list $newTag $start [$t index $mark]]

    return $start
}

proc tkmootag.escape_tcl_meta str {
    regsub -all {\$} $str {\\$} str
    return $str
}

proc tkmootag.do_hyperlink {} {
    global tkmootag_hyperlink_callback
    tkmootag.do_callback $tkmootag_hyperlink_callback
}

proc tkmootag.set_hyperlink_callback str {
    global tkmootag_hyperlink_callback
    set tkmootag_hyperlink_callback $str
}

proc tkmootag.do_callback str {
    global mcp_authentication_key

    set overlap [mcp21.report_overlap]
    set version [util.assoc $overlap dns-com-awns-jtext]
    if { ($version == {}) || ([lindex $version 1] == 1.0) } {
        set alist [tkmootag.to_alist $str]
        set type [lindex [util.assoc $alist address-type] 1]
        set args [lindex [util.assoc $alist args] 1]
        mcp21.server_notify dns-com-awns-jtext-pick [list [list type $type] [list args $args]]
	return
    }   

    if { [info exists mcp_authentication_key] &&
	 $mcp_authentication_key != "" } {
        io.outgoing "#$#jtext-pick $mcp_authentication_key $str"
    }
}

proc tkmootag.to_alist str {
    set alist {}
    foreach {keyword value} $str {
	regsub {:$} $keyword "" keyword
	lappend alist [list $keyword $value]
    }
    return $alist
}


proc tkmootag.writeText_hgroup {section t mark} {
  set start [$t index $mark]
  foreach hbox [lrange $section 1 end] {
    tkmootag.writeText [list $hbox] $t $mark
  }
  return $start
}

proc tkmootag.applyLineTagList t {
    global tkmootag_lineTagList
    foreach x $tkmootag_lineTagList {
        foreach tag [lindex $x 0] {
            $t tag add $tag [lindex $x 1] [lindex $x 2]
        }
    }
}

proc tkmootag.post_header {section t mark} {
    window.displayCR "" {} $t
}

proc tkmootag.writeTextLine {section t mark} {
  global tkmootag_lineTagList tkmootag_fixed
  set tkmootag_lineTagList {}
  tkmootag.writeText $section $t $mark
  tkmootag.applyLineTagList $t
  window.displayCR "" {} $t
  if { $tkmootag_fixed == 1 } {
      set tag [tkmootag.car [tkmootag.car $section]]
      catch { tkmootag.post_$tag $section $t $mark }
  }
}
#
#


client.register logging start 20
client.register logging stop 20
client.register logging client_connected 20
client.register logging client_disconnected 20
client.register logging incoming 20
client.register logging incoming_2
client.register logging outgoing 20



proc logging.client_connected {} {
    global logging_enabled logging_logfilename logging_logfilename_default

    set use [string tolower [worlds.get_generic on {} {} UseModuleLogging]]
    if { $use == "on" } {
        set logging_enabled 1
    } elseif { $use == "off" } {
        set logging_enabled 0
    }

    set logging_logfilename [worlds.get_generic $logging_logfilename_default {} {} LogFile]

    window.menu_preferences_state "Logging..." normal

    return [modules.module_deferred]
}

proc logging.client_disconnected {} {
    global logging_enabled logging_logfilename logging_logfilename_default
    set logging_enabled 0
    set logging_logfilename $logging_logfilename_default
    logging.stop
    window.menu_preferences_state "Logging..." disabled
    return [modules.module_deferred]
}

proc logging.start {} {
    global logging_enabled logging_logfilename logging_logfilename_default \
	logging_logfile logging_task

    set logging_enabled 0
    set logging_logfilename_default [file join [pwd] tkmoo.log]
    set logging_logfilename $logging_logfilename_default
    set logging_logfile ""
    set logging_task 0
}

window.menu_preferences_add "Logging..." logging.create_dialog
window.menu_preferences_state "Logging..." disabled

proc logging.stop {} {
    global logging_logfile logging_task
    after cancel $logging_task
    catch { 
	puts $logging_logfile "LOG FINISHED [clock format [clock seconds]]"
	close $logging_logfile 
	set logging_logfile ""
    }
}

proc logging.incoming event {
    db.set $event logging_original_line [db.get $event line]
    return [modules.module_deferred]
}

proc logging.incoming_2 event {
    global logging_enabled logging_logfilename logging_logfile

    if { $logging_enabled == 0 } {
	catch { close $logging_logfile }
	return [modules.module_deferred]
    }

    if { $logging_logfile == "" } {
        set logging_logfile [open $logging_logfilename "a+"]
	puts $logging_logfile "LOG STARTED [clock format [clock seconds]]"
    }

    set line [db.get $event logging_original_line]

    if { $logging_logfile != "" } {
        if { ! [db.exists $event logging_ignore_incoming] } {
	    puts $logging_logfile "LOG <: $line"
	    logging.flush
	}
    } {
	window.displayCR "Couldn't open logfile '$logging_logfilename'." window_highlight
    }
    db.set $event logging_ignore_incoming 0
    return [modules.module_deferred]
}

proc logging.outgoing line {
    global logging_enabled logging_logfilename logging_logfile
    if { $logging_enabled == 0 } {
	catch { close $logging_logfile }
	return [modules.module_deferred]
    }
    if { $logging_logfile == "" } {
        set logging_logfile [open $logging_logfilename "a+"]
	puts $logging_logfile "LOG STARTED [clock format [clock seconds]]"
    }
    if { $logging_logfile != "" } {
        puts $logging_logfile "LOG >: $line"
	logging.flush
    }
    return [modules.module_deferred]
}

proc logging.flush {} {
    global logging_logfile logging_task
    after cancel $logging_task
    set logging_task [after idle flush $logging_logfile]
}

proc logging.create_dialog {} {
    global logging_enabled logging_logfilename \
           logging_old_enabled logging_old_logfilename

    set logging_old_enabled $logging_enabled
    set logging_old_logfilename $logging_logfilename

    set l .logging
    catch { destroy $l }
    toplevel $l
    window.configure_for_macintosh $l

    global tcl_platform
    if { $tcl_platform(platform) != "macintosh" } {
        bind $l <Escape> "logging.close_dialog"
    }

    window.place_nice $l

    $l configure -bd 0 -highlightthickness 0

    wm iconname $l "Logging"
    wm title $l "Logging"

    frame $l.t -bd 0 -highlightthickness 0
        label $l.t.le -text "Log file name" -anchor w -width 20 -justify left
        entry $l.t.e -textvariable logging_logfilename -width 30 \
	    -font [fonts.fixedwidth]
	pack $l.t.le -side left
	pack $l.t.e -side left

    frame $l.m -bd 0 -highlightthickness 0
        label $l.m.l -text "Write to log file" -anchor w -width 20 -justify left
        checkbutton $l.m.b -variable logging_enabled -padx 0
	pack $l.m.l -side left
	pack $l.m.b -side left

    frame $l.b -bd 0 -highlightthickness 0
        button $l.b.o -text " Ok " -command "logging.close_dialog"
        button $l.b.c -text "Cancel" -command "logging.restore_dialog"
        pack $l.b.o $l.b.c -side left \
	    -padx 5 -pady 5

    pack $l.t -side top -fill x
    pack $l.m -side top -fill x
    pack $l.b -side top 

    window.focus $l.t.e
}

proc logging.restore_dialog {} {
    global logging_enabled logging_logfilename \
           logging_old_enabled logging_old_logfilename
    set logging_enabled $logging_old_enabled
    set logging_logfilename $logging_old_logfilename
    set l .logging
    destroy $l
}

proc logging.close_dialog {} {
    global logging_enabled logging_logfile
    set l .logging
    if { $logging_enabled == 0 } {
        catch { close $logging_logfile }
	set logging_logfile ""
    }
    destroy $l
    logging.set_logging_info_from_dialog
}

proc logging.set_logging_info_from_dialog {} {
    global logging_enabled logging_logfilename
    if { [set world [worlds.get_current]] != "" } {
        if { $logging_enabled } {
            set value On  
        } {
            set value Off
        }
        worlds.set_if_different $world UseModuleLogging $value
        worlds.set_if_different $world LogFile $logging_logfilename
    }
}
#
#

client.register hashhash_edit start
client.register hashhash_edit client_connected
client.register hashhash_edit incoming

proc hashhash_edit.start {} {
    global hashhash_edit_use hashhash_edit_receiving
    set hashhash_edit_receiving 0
    request.set current hashhash_edit_lines ""
    set hashhash_edit_use 0
    preferences.register hashhash_edit {Special Forces} {
        { {directive UseHashHashEditing}
            {type boolean}
            {default Off}
            {display "Allow ## editing"} }
    } 
}

proc hashhash_edit.client_connected {} {
    global hashhash_edit_use



    set default_usage 0
    set hashhash_edit_use $default_usage
    set use1 ""
    set use2 ""

    catch {
        set use1 [string tolower [worlds.get_generic Off {} {} UseHashHashEditing]]
    }
    if { $use1 == "on" } {
        set hashhash_edit_use 1
    } elseif { $use1 == "off" } {
        set hashhash_edit_use 0
    }
    ###
    return [modules.module_deferred]
}

proc hashhash_edit.incoming event {
    global hashhash_edit_use hashhash_edit_receiving

    if { $hashhash_edit_use == 0 } {
        return [modules.module_deferred]
    }

    set line [db.get $event line]

    if { [string match "## startrecord" $line] == 1 } {
        set hashhash_edit_receiving 1
        request.set current hashhash_edit_lines ""
        return [modules.module_ok]
    }

    if { $hashhash_edit_receiving == 1 } {

	if { [string match "## endrecord" $line] == 1 } {
	    set hashhash_edit_receiving 0
            hashhash_edit.editor
            hashhash_edit.unset_header
            return [modules.module_ok]
	}

        request.set current hashhash_edit_lines [concat [request.get current hashhash_edit_lines] [list $line]]

        return [modules.module_ok]
    }

    return [modules.module_deferred]
}

proc hashhash_edit.editor {} {
    set which [request.current]
    set lines [request.get $which hashhash_edit_lines]

    set title "Edit"
    set icon_title "Edit"

    edit.SCedit "" $lines "" $title $icon_title
}

proc hashhash_edit.unset_header {} {
    request.destroy current
}
#
#

proc mail.create {} {
    if { [winfo exists .mail] == 1 } {
	return;
    }

    toplevel .mail -bd 0 -highlightthickness 0

    window.place_nice .mail

    frame .mail.folders -bd 0 -highlightthickness 0
        listbox .mail.folders.l -height 3 \
	    -background #f0f0f0 \
	    -yscrollcommand ".mail.folders.s set" \
            -font [fonts.fixedwidth] \
            -highlightthickness 0
        scrollbar .mail.folders.s -command ".mail.folders.l yview" \
		-highlightthickness 0
        window.set_scrollbar_look .mail.folders.s
        pack configure .mail.folders.l -side left -fill x \
	            -expand 1
        pack configure .mail.folders.s -side right -fill y

    frame .mail.messages -bd 0 -highlightthickness 0
        listbox .mail.messages.l -height 5 \
	    -background #f0f0f0 \
	    -yscrollcommand ".mail.messages.s set" \
	    -font [fonts.fixedwidth] \
            -highlightthickness 0
        scrollbar .mail.messages.s -command ".mail.messages.l yview" \
		-highlightthickness 0
        window.set_scrollbar_look .mail.messages.s
        pack configure .mail.messages.l -side left -fill x \
	    -expand 1
        pack configure .mail.messages.s -side right -fill y

    frame .mail.message -bd 0 -highlightthickness 0
        text .mail.message.t -wrap word \
	    -yscrollcommand ".mail.message.s set" \
	    -font [fonts.fixedwidth] \
            -setgrid 1 \
            -cursor {} \
            -highlightthickness 0
        scrollbar .mail.message.s -command ".mail.message.t yview" \
		-highlightthickness 0
        window.set_scrollbar_look .mail.message.s
        pack configure .mail.message.s -side right -fill y
        pack configure .mail.message.t -side left -fill both -expand 1

    frame .mail.controls -bd 0 -highlightthickness 0
        button .mail.controls.n -text "Next" -state disabled
        button .mail.controls.p -text "Prev" -state disabled
        button .mail.controls.d -text "Delete" -state disabled
        button .mail.controls.r -text "Reply" -state disabled
        button .mail.controls.c -text "Close" -command "destroy .mail"
        pack configure .mail.controls.n -side left
        pack configure .mail.controls.p -side left
        pack configure .mail.controls.d -side left
        pack configure .mail.controls.r -side left
        pack configure .mail.controls.c -side right
    
    pack configure .mail.folders -side top -fill x
    pack configure .mail.messages -side top -fill x
    pack configure .mail.message -side top -fill both -expand 1
    pack configure .mail.controls -side top -fill x

    bind .mail.folders.l <ButtonRelease-1> {
        set box [%W index @%x,%y]
	set folder $mail_folders($box)
        io.outgoing "@xmail-messages on $folder"
    }

    bind .mail.messages.l <ButtonRelease-1> {
        set box [%W index @%x,%y]
	set folder_msgno $mail_messages($box)
        set folder [lindex $folder_msgno 0]
        set msgno  [lindex $folder_msgno 1]
	if { [mail.in_cache $folder $msgno] == 1 } {
	    mail.message $folder $msgno [mail.cache_get $folder $msgno]
	} {
	    io.outgoing "@xmail-message $msgno on $folder"
	}
    }

    .mail.message.t configure -state disabled
}

proc mail.folders { lines } {
    global mail_folders
    .mail.folders.l delete 0 end
    catch { unset mail_folders }
    foreach line $lines {
        catch { unset foo }
        util.populate_array foo $line
        set box [.mail.folders.l index end]
        set mail_folders($box) $foo(folder)
        .mail.folders.l insert end $foo(foldersum)
    }
}

proc mail.messages { folder last lines } {
    global mail_messages
    .mail.messages.l delete 0 end
    catch { unset mail_messages }
    foreach line $lines {
        catch { unset foo }
        util.populate_array foo $line
        set box [.mail.messages.l index end]
        set mail_messages($box) [list $folder $foo(msgno)]
        .mail.messages.l insert end $foo(msgsum)
    }
}

proc mail.message { folder msgno lines } {
    mail.cache_message $folder $msgno $lines

    .mail.message.t configure -state normal
    .mail.message.t delete 0.1 end

    if { $lines != {} } {
	.mail.message.t insert insert [lindex $lines 0]
	set lines [lrange $lines 1 end]
    }
    foreach line $lines {
	.mail.message.t insert insert "\n$line"
    }

    .mail.message.t configure -state disabled
}

proc mail.cache_get { folder msgno } {
    global mail_cache
    return $mail_cache($folder:$msgno)
}

proc mail.cache_message { folder msgno lines } {
    global mail_cache
    set mail_cache($folder:$msgno) $lines
}

proc mail.in_cache { folder msgno } {
    global mail_cache
    return [info exists mail_cache($folder:$msgno)]
}

#
#

proc xmcp11.do_xmail-folders* {} {
    if { [xmcp11.authenticated] == 1 } {
        request.set current xmcp11_multiline_procedure "xmail-folders*"
    }
}

proc xmcp11.do_callback_xmail-folders* {} {
    set which    [request.current]
    set lines    [request.get $which _lines]

    mail.create
    mail.folders $lines
}

proc xmcp11.do_xmail-messages* {} {
    if { [xmcp11.authenticated] == 1 } {
        request.set current xmcp11_multiline_procedure "xmail-messages*"
    }
}

proc xmcp11.do_callback_xmail-messages* {} {
    set which    [request.current]
    set folder   [request.get $which folder]
    set last     [request.get $which last]
    set lines    [request.get $which _lines]

    mail.create
    mail.messages $folder $last $lines
}

proc xmcp11.do_xmail-message* {} {
    if { [xmcp11.authenticated] == 1 } {
        request.set current xmcp11_multiline_procedure "xmail-message*"
    }
}

proc xmcp11.do_callback_xmail-message* {} {
    set which    [request.current]
    set folder   [request.get $which folder]
    set msgno    [request.get $which msgno]
    set lines    [request.get $which _lines]

    mail.create

    foreach line $lines {
        catch { unset foo }
        util.populate_array foo $line
	lappend real_lines $foo(text)
    }

    mail.message $folder $msgno $real_lines
}
#
#




client.register chess start
proc chess.start {} {
    global chess_bitmap

    array set chess_bitmap {
        K king.xbm
        k king.xbm
        Q queen.xbm
        q queen.xbm
        B bishop.xbm
        b bishop.xbm
        N knight.xbm
        n knight.xbm
        R rook.xbm
        r rook.xbm
        P pawn.xbm
        p pawn.xbm
    }
}

proc chess.SCboard { object board turn colour sequence } {
    global chess_board chess_sequence chess_turn
    if { [winfo exists .chessboard] != 1 } {
	chess.create
    }
    set chess_sequence $sequence
    set chess_turn $turn
    chess.display $board $colour
    set chess_board(.chessboard) $object
}

proc chess.display_piece { column row piece } {
    global chess_bitmap tkmooLibrary chess_pieces \
	image_data
    set b .chessboard
    set x [expr $column*32+16]
    set y [expr $row*32+16]

    if { [chess.piece_colour $piece] == "white" } {
	set colour "#ffa0a0"
    } {
	set colour "#a0a0ff"
    }



    set id [$b.c create image $x $y \
	-tags CHESS_PIECE \
	-image chess_$chess_bitmap($piece).[chess.piece_colour $piece]]


    set chess_pieces(id:$id) $piece
    set chess_pieces(xy:$id) [list [expr $column + 1] [expr $row + 1]]
}

proc chess.build_images {} {
    global chess_bitmap image_data
    foreach key [array names chess_bitmap] {
	set foo($chess_bitmap($key)) 1
    }
    foreach piece [array names foo] {
        image create bitmap "chess_$piece.white" \
            -foreground "#ffa0a0" \
            -data $image_data($piece)
        image create bitmap "chess_$piece.black" \
            -foreground "#a0a0ff" \
            -data $image_data($piece)
        image create bitmap "chess_$piece.ghost" \
            -foreground "#a0e0a0" \
            -data $image_data($piece)
        image create bitmap "chess_$piece.stationary_ghost" \
            -foreground "#c0c0c0" \
            -data $image_data($piece)
    }
}

proc chess.display { board colour } {
    global chess_piece chess_pieces chess_bitmap chess_my_colour \
	chess_turn

    set b .chessboard

    $b.c delete CHESS_PIECE
    catch { unset chess_pieces }
    set chess_piece ""

    set chess_my_colour $colour

    set places [split $board {}]

    if { $chess_my_colour == "black" } {
        for {set column 0} {$column < 8} {incr column} {
            for {set row 0} {$row < 8} {incr row} {
	        set piece [lindex $places 0]
	        set places [lrange $places 1 end]
	        if { $piece == "." } { continue }
	        chess.display_piece $column $row $piece
            }
        }
    } {
        for {set column 7} {$column >= 0} {set column [expr $column - 1]} {
            for {set row 7} {$row >= 0} {set row [expr $row - 1]} {
	        set piece [lindex $places 0]
	        set places [lrange $places 1 end]
	        if { $piece == "." } { continue }
	        chess.display_piece $column $row $piece
            }
        }
    }

    if { $chess_turn == 1 } {
	$b.l configure -text "It's your turn to move..."
    } {
	$b.l configure -text "It's your opponent's turn to move..."
    }
}


proc chess.create {} {
    global tkmooLibrary
    set b .chessboard

    toplevel $b

    window.place_nice $b

    $b configure -bd 0 -highlightthickness 0

    wm title $b "Chess"
    wm iconname $b "Chess"

    canvas $b.c -height 256 -width 256 \
	    -background #000000 -bd 0 -highlightthickness 0 


    set wdht 32

    for { set y 0 } { $y < 256 } { incr y 64 } {
        for { set x 0 } { $x < 256 } { incr x 64 } {
            $b.c create rectangle $x $y \
		[expr $x+$wdht] [expr $y+$wdht] -fill #f0f0f0 -outline ""
	}

        set y2 [expr $y + 32]
        for { set x 32 } { $x < 256 } { incr x 64 } {
            $b.c create rectangle $x $y2 \
                [expr $x+$wdht]  [expr $y2+$wdht] -fill #f0f0f0 -outline ""
	}
    }


    label $b.l -anchor c -text "NO MOO ONLY CHESS!" \
	-bd 2 -highlightthickness 0 -relief groove

    pack configure $b.c -side top
    pack configure $b.l -side bottom -fill x

    bind $b.c <1>                "chess.pick $b %x %y"
    bind $b.c <B1-Motion>        "chess.drag $b %x %y"
    bind $b.c <B1-ButtonRelease> "chess.drop $b %x %y"

    chess.build_images
}

proc chess.piece_colour { piece } {
    if { $piece == "" } { return "" }
    if { [string toupper $piece] == $piece } {
	return "white"
    } {
	return "black"
    }
}

proc chess.piece_at_xy { x y } {
    global chess_pieces
    foreach key [array names chess_pieces] {
	if { [string match "xy:*" $key] == 1 } {
	    if { ($x == [lindex $chess_pieces($key) 0]) &&
		 ($y == [lindex $chess_pieces($key) 1]) } {
		 set id [lindex [split $key ":"] 1]
		 return $chess_pieces(id:$id)
            }
	}
    }
    return ""
}

proc chess.pick { board x y } {
    global chess_piece chess_pieces chess_x chess_y chess_bitmap \
	chess_my_colour tkmooLibrary image_data
    set id [$board.c find withtag current]
    set chess_piece ""
    catch { set chess_piece $chess_pieces(id:$id) }

    if { $chess_piece == "" } { return }
    if { [chess.piece_colour $chess_piece] != $chess_my_colour } { return }

    set chess_x [lindex $chess_pieces(xy:$id) 0]
    set chess_y [lindex $chess_pieces(xy:$id) 1]

    set ghost_x [expr $chess_x * 32 - 16]
    set ghost_y [expr $chess_y * 32 - 16]

    .chessboard.c create image $ghost_x $ghost_y -image chess_$chess_bitmap($chess_piece).stationary_ghost \
	-tags CHESS_STATIONARY_GHOST

    .chessboard.c delete CHESS_GHOST
    .chessboard.c create image $x $y -image chess_$chess_bitmap($chess_piece).$chess_my_colour \
	-tags CHESS_GHOST
}

proc chess.drag { board x y } {
    global chess_piece chess_bitmap chess_my_colour \
        tkmooLibrary 

    if { $chess_piece == "" } { return }
    if { [chess.piece_colour $chess_piece] != $chess_my_colour } { return }

    .chessboard.c delete CHESS_GHOST
    .chessboard.c create image $x $y -image chess_$chess_bitmap($chess_piece).$chess_my_colour \
	-tags CHESS_GHOST
}


proc chess.physical_xy_to_chess_xy { px py colour } {
    if { $colour == "black" } {
	set x $px
	set y $py
    } {
	set x [expr 8 - $px + 1]
	set y [expr 8 - $py + 1]
    }
    return [list $x $y]
}

proc chess.drop { board x y } {
    global chess_piece chess_board chess_x chess_y chess_my_colour \
	chess_sequence

    .chessboard.c delete CHESS_GHOST CHESS_STATIONARY_GHOST

    if { $chess_piece == "" } { return }
    if { [chess.piece_colour $chess_piece] != $chess_my_colour } { return }

    set board_x [expr int($x / 32) + 1]
    set board_y [expr int($y / 32) + 1]

    if { ($chess_x != $board_x) || ($chess_y != $board_y) } {

	set source [chess.physical_xy_to_chess_xy $chess_x $chess_y $chess_my_colour]
	set target [chess.physical_xy_to_chess_xy $board_x $board_y $chess_my_colour]
	set x1 [lindex $source 0]
	set y1 [lindex $source 1]
	set x2 [lindex $target 0]
	set y2 [lindex $target 1]

        set victim [chess.piece_at_xy $board_x $board_y]
        if { [chess.piece_colour $victim] == $chess_my_colour } { 
	    return 
        }

	io.outgoing "move $x1 $y1 $x2 $y2 $chess_sequence on $chess_board(.chessboard)"
    }
}
#
#

proc xmcp11.do_chess-board {} {
    if { [xmcp11.authenticated] != 1 } {
	return;
    }
    set which		[request.current]
    set object		[request.get $which object]
    set board		[request.get $which board]
    set turn		[request.get $which turn]
    set colour		[request.get $which colour]
    set sequence	[request.get $which sequence]
    chess.SCboard $object $board $turn $colour $sequence
}

#
#

client.register macmoose start
client.register macmoose client_connected
client.register macmoose incoming

proc macmoose.start {} {
    global macmoose_use macmoose_log
    .output tag configure macmoose_feedback -foreground [colourdb.get darkgreen]
    .output tag configure macmoose_error -foreground [colourdb.get red]
    set macmoose_use 1
    set macmoose_log 0
    window.menu_tools_add "MacMOOSE" macmoose.create_browser "[window.accel Ctrl]+M"
    bind . <Command-m> macmoose.create_browser

    preferences.register macmoose {Out of Band} {
        { {directive MacMOOSELogging}
            {type boolean}
            {default On}
            {display "Log MacMOOSE\nmessages"} }
    } 
}

proc macmoose.client_connected {} {
    global macmoose_use macmoose_log
    set default_usage 1
    set macmoose_use $default_usage
    set use ""
    catch {
      set use [string tolower [worlds.get [worlds.get_current] UseModuleMacMOOSE]]
    }
    if { $use == "on" } {
        set macmoose_use 1
    } elseif { $use == "off" } {
        set macmoose_use 0
    }
    ###

    set macmoose_log 0
    set log [string tolower [worlds.get_generic On {} {} MacMOOSELogging]]
    if { $log == "on" } {
        set macmoose_log 1
    } elseif { $log == "off" } {
        set macmoose_log 0
    } 
    return [modules.module_deferred]
}

proc macmoose.stop {} {}

#

proc macmoose.incoming event {
    global macmoose_fake_args macmoose_use macmoose_log

    if { $macmoose_use == 0 } {
        return [modules.module_deferred]
    }

    set line [db.get $event line]


    if { [regexp {^_&_MacMOOSE_(.*)} $line] == 0 } {
	return [modules.module_deferred]
    }


    if { $macmoose_log == 0 } {
        db.set $event logging_ignore_incoming 1
    }



    set space [string first " " $line]
    if { $space == -1 } {
        set lhs $line
        set rhs ""
    } else {
        set lhs [string range $line 0 [expr $space-1]]
        set rhs [string range $line [expr $space+1] end]
    }

    if { [regexp {^_&_MacMOOSE_([^\(]+)\((.*)\)$} $lhs _ type the_args] } {
    } {
        set type ""
        set the_args ""
    }

    catch { unset macmoose_fake_args }
    macmoose.cgi_populate_array macmoose_fake_args $the_args
    macmoose.do_$type $rhs
    return [modules.module_ok]
}


proc macmoose.cgi_populate_array { array text } {
    upvar $array a
    foreach element [split $text "&"] {
	set keyval [split $element "="]
	set a([lindex $keyval 0]) [lindex $keyval 1]
    }
}


proc macmoose.do_set_code data {
    macmoose.populate_array keyvals $data
    set feedback_tag "macmoose_feedback"
    catch {
	if { $keyvals(TEXT_COLOR_) == "RED" } {
            set feedback_tag "macmoose_error"
	}
    }
    catch {
	window.displayCR $keyvals(FEEDBACK_) $feedback_tag
    }
}

proc macmoose.do_list_code data {
    global macmoose_keyvals macmoose_lines
    if { $data == "CODE_END" } {


	macmoose.invoke_verb_editor 
	catch { unset macmoose_keyvals }
	catch { unset macmoose_lines }
	return
    }
    if { [regexp {^CODE_LINE_: (.*)} $data null text] } {
	lappend macmoose_lines $text
	return
    }
    set macmoose_lines ""
    macmoose.populate_array macmoose_keyvals $data
}

proc macmoose.invoke_verb_editor {} {
    global macmoose_editordb macmoose_keyvals macmoose_lines macmoose_fake_args
    set e [edit.create "Verb Editor" "Verb Editor"]
    edit.set_type $e moo-code
    edit.SCedit "" $macmoose_lines "" "Verb Editor" "Verb Editor" $e
    edit.configure_send  $e Send  "macmoose.editor_verb_send $e" 1
    edit.configure_send_and_close  $e "Send and Close"  "macmoose.editor_verb_send_and_close $e" 10
    edit.configure_close $e Close "macmoose.editor_close $e" 0

    foreach key [array names macmoose_keyvals] {
	set macmoose_editordb($e:$key) $macmoose_keyvals($key)
    }
    foreach key [array names macmoose_fake_args] {
	set macmoose_editordb($e:$key) $macmoose_fake_args($key)
    }

    edit.add_toolbar $e info

    frame $e.info -bd 0 -highlightthickness 0

    window.toolbar_look $e.info

	set msg ""
	set msg "$msg$macmoose_editordb($e:OBJ_)"
	set msg "$msg:"
	set msg "$msg$macmoose_editordb($e:CODE_NAME_)"

        label $e.info.l1 -text "$msg"

	label $e.info.la -text " args:"
	entry $e.info.args -width 15 \
	    -background [colourdb.get pink] \
	    -font [fonts.fixedwidth]
	    $e.info.args insert 0 "$macmoose_editordb($e:VERB_DOBJ_) $macmoose_editordb($e:VERB_PREP_) $macmoose_editordb($e:VERB_IOBJ_)"
	label $e.info.lp -text " perms:"
	entry $e.info.perms -width 4 \
	    -background [colourdb.get pink] \
	    -font [fonts.fixedwidth]
	    $e.info.perms insert 0 $macmoose_editordb($e:VERB_PERMS_)

	label $e.info.lo -text " owner: $macmoose_editordb($e:VERB_OWNER_)"

	pack $e.info.l1 -side left 
	pack $e.info.la -side left
	pack $e.info.args -side left
	pack $e.info.lp -side left
	pack $e.info.perms -side left
	pack $e.info.lo -side left

    edit.repack $e
}

proc macmoose.do_prop_info data {
    macmoose.populate_array info $data

    set error ""
    catch { set error $info(ERROR_) }
    if { $error != "" } {
        window.displayCR "$info(OBJ_NAME_) ($info(OBJ_)).$info(PROP_NAME_) $error" macmoose_error
	return [modules.module_ok]
    }

    global macmoose_editordb 

    set e [edit.SCedit "" "" "" "Property Editor" "Property Editor"]

    $e.t insert insert "$info(PROP_VALUE_)"
    edit.configure_send  $e Send  "macmoose.editor_property_send $e" 1
    edit.configure_send_and_close  $e "Send and Close"  "macmoose.editor_property_send_and_close $e" 10
    edit.configure_close $e Close "macmoose.editor_close $e" 0
    foreach key [array names info] {
	set macmoose_editordb($e:$key) $info($key)
    }

    edit.add_toolbar $e info

    frame $e.info -bd 0 -highlightthickness 0

    window.toolbar_look $e.info

	set msg ""
	set msg "$msg$macmoose_editordb($e:OBJ_)"
	set msg "$msg."
	set msg "$msg$macmoose_editordb($e:PROP_NAME_)"
        label $e.info.l -text "$msg"

        label $e.info.lp -text " perms:"
        entry $e.info.perms -width 4 \
	    -background [colourdb.get pink] \
	    -font [fonts.fixedwidth]
	$e.info.perms insert 0 "$macmoose_editordb($e:PROP_PERMS_)"

        label $e.info.lo -text " owner: $macmoose_editordb($e:PROP_OWNER_)"

	pack $e.info.l -side left
	pack $e.info.lp -side left
	pack $e.info.perms -side left
	pack $e.info.lo -side left

    edit.repack $e

    return [modules.module_ok]
}

proc macmoose.editor_property_send_and_close editor {
    macmoose.editor_property_send $editor
    edit.destroy $editor
}

proc macmoose.editor_property_send editor {
    global macmoose_editordb
    set line "#$#MacMOOSE"
    set line "$line set_prop"
    set line "$line PREFIX_: _&_MacMOOSE_set_prop()"
    set line "$line OBJ_: $macmoose_editordb($editor:OBJ_)"
    set line "$line PROP_NAME_: $macmoose_editordb($editor:PROP_NAME_)"
    set perms [$editor.info.perms get]
    if { ($perms != "") && 
	 ($perms != $macmoose_editordb($editor:PROP_PERMS_)) } {
        set line "$line PERMS_: $perms"
    }
    set value [$editor.t get 1.0 end]
    set line "$line VALUE_: $value"
    io.outgoing $line
}

proc macmoose.do_set_prop data {
    macmoose.populate_array keyvals $data
    catch {
	window.displayCR $keyvals(ERROR_) macmoose_error
    }
    set feedback_tag macmoose_feedback
    catch {
	if { $keyvals(TEXT_COLOR_) == "RED" } {
            set feedback_tag macmoose_error
	}
    }
    catch {
	window.displayCR $keyvals(FEEDBACK_) $feedback_tag
    }
}

proc macmoose.editor_verb_send_and_close editor {
    macmoose.editor_verb_send $editor
    edit.destroy $editor
}

proc macmoose.editor_verb_send editor {
    global macmoose_editordb

    set line "#$#MacMOOSE"
    set line "$line set_code"
    set line "$line PREFIX_: _&_MacMOOSE_set_code()"
    set line "$line CODE_NAME_: $macmoose_editordb($editor:CODE_NAME_)"
    set line "$line OBJ_: $macmoose_editordb($editor:OBJ_)"

    set args [$editor.info.args get]
    set old_args "$macmoose_editordb($editor:VERB_DOBJ_) $macmoose_editordb($editor:VERB_PREP_) $macmoose_editordb($editor:VERB_IOBJ_)"

    if { ($args != "") && 
	 ($args != $old_args) && 
	 ([llength $args] == 3)} {
        set line "$line VERB_DOBJ_: [lindex $args 0]"
        set line "$line VERB_PREP_: [lindex $args 1]"
        set line "$line VERB_IOBJ_: [lindex $args 2]"
    }

    set perms [$editor.info.perms get]
    if { ($perms != "") && 
	 ($perms != $macmoose_editordb($editor:VERB_PERMS_)) } {
        set line "$line PERMS_: $perms"
    }


    set value ""
    foreach thing [edit.get_text $editor] {
	regsub -all "/" $thing "\\/" thing
	if { $value == "" } {
	    set value $thing
	} {
	    set value "$value/$thing"
	}
    }

    set line "$line VALUE_: $value"

    io.outgoing $line
}

proc macmoose.editor_close editor {
    global macmoose_editordb
    foreach {key val} [array get macmoose_editordb "$editor:*"] {
	unset macmoose_editordb($key)
    }
    edit.destroy $editor
}


###

proc macmoose.do_object_parents data {
    global macmoose_keyvals macmoose_current_object \
	macmoose_fake_args
    catch { unset macmoose_keyvals }
    macmoose.populate_array macmoose_keyvals $data

    set browser ""
    catch { set browser $macmoose_fake_args(_BROWSER_) }
    if { $browser == "" } {
        set browser [macmoose.create_browser]
    }

    set error ""
    catch { set error $macmoose_keyvals(ERROR_) }
    if { $error != "" } {
        window.displayCR "$error" macmoose_error
        return [modules.module_ok]
    } 

    set object_menu {}
    set names [split $macmoose_keyvals(PARENT_NAMES_) "/"]
    foreach item [split $macmoose_keyvals(PARENT_OBJS_) "/"] {
	if { $item != "" } { 
	    set obj $item
	    set name [lindex $names 0]
	    regsub { *\(#.*\)$} $name {} name
	    lappend object_menu [list "$obj" "$name"]
	}
	set names [lrange $names 1 end]
    }
    db.set $browser object_menu $object_menu

    macmoose.post_object_menu $browser


    macmoose.object_info $browser $obj
}

proc macmoose.do_object_info data {
    global macmoose_keyvals
    catch { unset macmoose_keyvals }
    macmoose.populate_array macmoose_keyvals $data
    macmoose.invoke_browser
}

proc macmoose.invoke_browser {} {
    global macmoose_keyvals macmoose_current_object \
	macmoose_fake_args

    set browser ""
    catch { set browser $macmoose_fake_args(_BROWSER_) }

    if { $browser == "" } {
        set browser [macmoose.create_browser]
    }

    $browser.lists.v.verbs.l delete 0 end
    foreach verb [lsort [split $macmoose_keyvals(VERBS_) "/"]] {
    if { $verb == "" } { continue }
    $browser.lists.v.verbs.l insert end $verb
    }

    $browser.lists.p.props.l delete 0 end
    foreach prop [lsort [split $macmoose_keyvals(PROPS_) "/"]] {
    if { $prop == "" } { continue }
    $browser.lists.p.props.l insert end $prop
    }

    wm title $browser "Browser on $macmoose_keyvals(OBJ_NAME_)"

    set macmoose_current_object $macmoose_keyvals(OBJ_)
    db.set $browser current_object $macmoose_keyvals(OBJ_)

    set found 0
    set object_menu [db.get $browser object_menu]
    foreach object_name $object_menu {
	set object [lindex $object_name 0]
	set name [lindex $object_name 1]
	if { ($object == $macmoose_keyvals(OBJ_)) &&
	     ($name   == $macmoose_keyvals(OBJ_NAME_)) } {
	     set found 1
	     break;
	}
    }
    if { $found != 1 } {
	lappend object_menu [list "$macmoose_keyvals(OBJ_)" "$macmoose_keyvals(OBJ_NAME_)"]
	db.set $browser object_menu $object_menu
        macmoose.post_object_menu $browser
    }
}

proc macmoose.object_info { browser object } {
    set line "#$#MacMOOSE object_info"
    set line "$line OBJ_: $object"
    set special "_BROWSER_=$browser"
    set line "$line PREFIX_: _&_MacMOOSE_object_info($special)"
    io.outgoing $line
}

proc macmoose.object_parents { browser object } {
    set line "#$#MacMOOSE object_parents"
    set line "$line OBJ_: $object"
    set special "_BROWSER_=$browser"
    set line "$line PREFIX_: _&_MacMOOSE_object_parents($special)"
    io.outgoing $line
}

proc macmoose.list_code { browser code_name } {
    set current_object [db.get $browser current_object]
    if { $current_object == "" } { return }
    set line "#$#MacMOOSE list_code"
    set line "$line OBJ_: $current_object"
    regsub -all {\*} $code_name {} code_name
    set code_name [lindex $code_name 0]
    set line "$line CODE_NAME_: $code_name"
    set line "$line PREFIX_: _&_MacMOOSE_list_code(CODE_NAME_=$code_name&OBJ_=$current_object)"
    io.outgoing $line
}

proc macmoose.prop_info { browser prop_name } {
    set current_object [db.get $browser current_object]
    if { $current_object == "" } { return }
    set line "#$#MacMOOSE prop_info"
    set line "$line OBJ_: $current_object"
    set line "$line PROP_NAME_: $prop_name"
    set line "$line PREFIX_: _&_MacMOOSE_prop_info()"
    io.outgoing $line
}



proc macmoose.do_declare_code data {
    macmoose.populate_array info $data

    set error ""
    catch { set error $info(ERROR_) }
    if { $error != "" } {
        window.displayCR "Whoops!: $error" macmoose_error
        return [modules.module_ok]
    }       

    set ok 0
    catch { set ok $info(DECLARE_CODE_) }
    if { $ok == 1 } {
	window.displayCR "Code Added." macmoose_feedback
    } {
    }
    return [modules.module_ok]
}

proc macmoose.do_declare_prop data {
    macmoose.populate_array info $data

    set error ""
    catch { set error $info(ERROR_) }
    if { $error != "" } {
        window.displayCR "Whoops!: $error" macmoose_error
        return [modules.module_ok]
    }       

    set ok 0
    catch { set ok $info(DECLARE_PROP_) }
    if { $ok == 1 } {
	window.displayCR "Property Added." macmoose_feedback
    } {
    }
    return [modules.module_ok]
}


proc macmoose.add_dialog w {
    global macmoose_add macmoose_current_object
    switch $macmoose_add {
	script {
	    
	    set name [$w.s.name get]
	    set perms [$w.s.perms get]
	    set args [$w.s.args get]
		set dobj [lindex $args 0]
		set prep [lindex $args 1]
		set iobj [lindex $args 2]
	    
	    if { $name == "" } {
		return
	    }

            set obj $macmoose_current_object
            set obj [db.get $w browser current_object]

	    set line "#$#MacMOOSE declare_code"
	    set line "$line CODE_NAME_: $name"
	    set line "$line OBJ_: $obj"
	    set line "$line VERB_DOBJ_: $dobj"
	    set line "$line VERB_PREP_: $prep"
	    set line "$line VERB_IOBJ_: $iobj"
	    set line "$line PERMS_: $perms"
            set line "$line PREFIX_: _&_MacMOOSE_declare_code()"

	}
	property {
	    set name [$w.p.name get]
	    set perms [$w.p.perms get]

	    if { $name == "" } {
		return
	    }

            set obj $macmoose_current_object
            set obj [db.get $w browser current_object]

	    set line "#$#MacMOOSE declare_prop"
	    set line "$line PROP_NAME_: $name"
	    set line "$line OBJ_: $obj"
	    set line "$line PERMS_: $perms"
            set line "$line PREFIX_: _&_MacMOOSE_declare_prop()"

	}
    }
    io.outgoing $line
    macmoose.object_info [db.get $w browser] $obj
}


proc macmoose.add_script_or_property browser {
    global macmoose_add
    set macmoose_add script

    set w .[util.unique_id "macmoose_add"]

    catch { destroy $w; db.drop $w }
    toplevel $w
    window.configure_for_macintosh $w

    window.place_nice $w

    $w configure -bd 0

    wm iconname $w "Add script or property"
    wm title $w "Add script or property"

    db.set $w browser $browser

    label $w.l -text "add a script or property"

    frame $w.s -bd 0 -highlightthickness 0
	radiobutton $w.s.r -text "script" -anchor w -variable macmoose_add -value script -width 10
	label $w.s.lname -text "name:"
	entry $w.s.name -width 15 -background [colourdb.get pink] -font [fonts.fixedwidth]

	label $w.s.lperms -text "perms:"
	entry $w.s.perms -width 4 -background [colourdb.get pink] -font [fonts.fixedwidth]

    $w.s.perms insert 0 "rd"

	label $w.s.largs -text "args:"
	entry $w.s.args -width 15 -background [colourdb.get pink] -font [fonts.fixedwidth]

    $w.s.args insert 0 "none none none"

	pack $w.s.r -side left
	pack $w.s.lname -side left
	pack $w.s.name -side left
	pack $w.s.lperms -side left
	pack $w.s.perms -side left
	pack $w.s.largs -side left
	pack $w.s.args -side left

    frame $w.p -bd 0 -highlightthickness 0
	radiobutton $w.p.r -text "property" \
	    -anchor w \
	    -variable macmoose_add -value property \
	    -width 10
	label $w.p.lname -text "name:"
	entry $w.p.name \
            -width 15 \
            -background [colourdb.get pink] \
            -font [fonts.fixedwidth]

	label $w.p.lperms -text "perms:"
	entry $w.p.perms \
            -width 4 \
            -background [colourdb.get pink] \
            -font [fonts.fixedwidth]

	    $w.p.perms insert 0 "rc"

	pack $w.p.r -side left
	pack $w.p.lname -side left
	pack $w.p.name -side left
	pack $w.p.lperms -side left
	pack $w.p.perms -side left

    pack $w.l -side top
    pack $w.s -side top -expand 1 -fill x
    pack $w.p -side top -expand 1 -fill x

    frame $w.controls -bd 0 -highlightthickness 0

    button $w.controls.a -text "Add" -command "macmoose.add_dialog $w"
    button $w.controls.c -text "Close" -command "destroy $w; db.drop $w"

    global tcl_platform
    if { $tcl_platform(os) == "Darwin" } {
        bind $w <Command-w> "destroy $w; db.drop $w"
    }
    bind $w <Escape> "destroy $w; db.drop $w"
    
    pack $w.controls.a $w.controls.c -side left -padx 5 -pady 5
    pack $w.controls -side bottom 
    window.focus $w
}

proc macmoose.toplevel w {
    return [winfo toplevel $w]
}

proc macmoose.post_object_menu browser {
    $browser.cmenu.object delete 0 end
    set object_menu [db.get $browser object_menu]
    if { $object_menu != {} } {
        foreach object_name $object_menu {
            set object [lindex $object_name 0]  
            set name [lindex $object_name 1]
            $browser.cmenu.object add command \
                -label "$name ($object)" \
                -command "macmoose.object_info $browser $object"
	    window.hidemargin $browser.cmenu.object
        }
    } {
        $browser.cmenu.object add command -label "No object selected" -state disabled
    	window.hidemargin $browser.cmenu.object
    }
}

proc macmoose.destroy_browser browser {
    destroy $browser
    db.drop $browser
}

proc macmoose.create_browser { { src . } } {
    set browser .[util.unique_id "macmoose_browser_"]

    catch { destroy $browser; db.drop $browser }
    toplevel $browser

    #PLG:TODO window.configure_for_macintosh $browser

    # Instead of window.place_nice $browser .
    #
    # get the root window's x and y
    set x [winfo x $src]
    set y [winfo y $src]
    set w [winfo width $src]

    incr x $w

    wm geometry $browser "=400x700+$x+$y"
    #

    menu $browser.cmenu

    $browser configure -bd 0 -menu $browser.cmenu

    wm iconname $browser "Macmoose"
    wm title $browser "Macmoose"

    db.set $browser current_object ""
    db.set $browser object_menu {}

    ## add the File menu
    #
    $browser.cmenu add cascade -label "File" -menu $browser.cmenu.file -underline 0
    menu $browser.cmenu.file -tearoff 0

    $browser.cmenu.file add command -label "New Browser" -underline 0 \
        -command macmoose.create_browser \
        -accelerator "[window.accel Ctrl]+N"
    bind $browser <Command-n> "macmoose.create_browser $browser"
    window.hidemargin $browser.cmenu.file

    $browser.cmenu.file add command -label "MacMOOSE" -underline 0 \
        -command macmoose.create_browser \
        -accelerator "[window.accel Ctrl]+M"
    bind $browser <Command-m> "macmoose.create_browser $browser"
    window.hidemargin $browser.cmenu.file

    $browser.cmenu.file add separator
    $browser.cmenu.file add command -label "Close" -underline 0 \
        -command "macmoose.destroy_browser $browser" \
        -accelerator "[window.accel Ctrl]+W"
    bind $browser <Command-w> "macmoose.destroy_browser $browser"
    window.hidemargin $browser.cmenu.file

    ## add Object menu
    #
    $browser.cmenu add cascade -label "Object" -menu $browser.cmenu.object -underline 0
    menu $browser.cmenu.object -tearoff 0

    ## add Tools menu
    #
    $browser.cmenu add cascade -label "Tools" -menu $browser.cmenu.tools -underline 0
    menu $browser.cmenu.tools -tearoff 0

    $browser.cmenu.tools add command -label "Add Script/Property" -underline 0 \
        -command "macmoose.add_script_or_property $browser" \
        -accelerator "[window.accel Ctrl]+A"
    bind $browser <Command-a> "macmoose.add_script_or_property $browser"
    window.hidemargin $browser.cmenu.tools


    ## add the Window menu
    #
    $browser.cmenu add cascade -label "Window" -menu $browser.cmenu.windows -underline 0
    menu $browser.cmenu.windows -tearoff 0

    $browser.cmenu.windows add separator
    window.hidemargin $browser.cmenu.windows

    #$browser.cmenu.windows add command -label "Root" -underline 0 -command "window.focus .input" -accelerator "[window.accel Ctrl]+0"
    #PLG:TODO bind $w <Command-0> ""
    #window.hidemargin $browser.cmenu.windows

    ##

    frame $browser.toolbar
    window.toolbar_look $browser.toolbar

	label $browser.toolbar.l -text "Browse:" -width 7 -anchor e
	entry $browser.toolbar.e -font [fonts.fixedwidth] -background [colourdb.get pink]

    bind $browser <Activate> "focus $browser.toolbar.e"

    bind $browser.toolbar.e <Return> {
        set object [%W get]
        if { $object != "" } {
            macmoose.object_parents [macmoose.toplevel %W] $object
        }
        %W delete 0 end
    }

    pack $browser.toolbar.l -side left
    pack $browser.toolbar.e -side left

    pack $browser.toolbar -side top -fill x

    frame $browser.lists -bd 0 -highlightthickness 0

    frame $browser.lists.v -bd 0 -highlightthickness 0
	label $browser.lists.v.l -text "Scripts / Verbs"

    frame $browser.lists.v.verbs -bd 0 -highlightthickness 0
    listbox $browser.lists.v.verbs.l -highlightthickness 0 -background #ffffff -yscrollcommand "$browser.lists.v.verbs.s set"

	bind $browser.lists.v.verbs.l <Double-ButtonRelease-1> {
	    macmoose.list_code [macmoose.toplevel %W] [%W get @%x,%y]
	}

	bind $browser.lists.v.verbs.l <Triple-ButtonRelease-1> {
	}

    scrollbar $browser.lists.v.verbs.s -highlightthickness 0 -command "$browser.lists.v.verbs.l yview"

    global tcl_platform
    if { $tcl_platform(platform) != "macintosh" } {
        window.set_scrollbar_look $browser.lists.v.verbs.s
    }

    pack $browser.lists.v.verbs.l -side left -fill both -expand 1
    pack $browser.lists.v.verbs.s -side right -fill y

	pack $browser.lists.v.l -side top
	pack $browser.lists.v.verbs -side bottom -fill both -expand 1


    frame $browser.lists.p -bd 0 -highlightthickness 0
	label $browser.lists.p.l -text "Properties"

    frame $browser.lists.p.props -bd 0 -highlightthickness 0
    listbox $browser.lists.p.props.l -highlightthickness 0 -background #ffffff -yscrollcommand "$browser.lists.p.props.s set"
	
    bind $browser.lists.p.props.l <Double-ButtonRelease-1> {
	    macmoose.prop_info [macmoose.toplevel %W] [%W get @%x,%y]
	}

	bind $browser.lists.p.props.l <Triple-ButtonRelease-1> {
	}
    scrollbar $browser.lists.p.props.s -highlightthickness 0 -command "$browser.lists.p.props.l yview"

    global tcl_platform
    if { $tcl_platform(platform) != "macintosh" } {
        window.set_scrollbar_look $browser.lists.p.props.s
    }

    pack $browser.lists.p.props.l -side left -fill both -expand 1
    pack $browser.lists.p.props.s -side right -fill y

	pack $browser.lists.p.l -side top
	pack $browser.lists.p.props -side bottom -fill both -expand 1

    pack $browser.lists.v -side left -fill both -expand 1
    pack $browser.lists.p -side right -fill both -expand 1

    pack $browser.lists -side bottom -fill both -expand 1

    macmoose.post_object_menu $browser

    window.focus $browser.toolbar.e
    return $browser
}

proc macmoose.populate_array {array string} {
    upvar $array a

    set key ""
    set value ""

    regsub -all {\\} $string {\\\\} string

    while { $string != "" } {
        set space [string first " " $string]
        if { $space != -1 } {
            set left [string range $string 0 [expr $space - 1]]
            set string [string range $string [expr $space + 1] end]
            if { [regexp {^[A-Z_]+_:$} $left] } {

                if { $key != "" } {
                    if { ($value == "") || ([string first " " $value] != -1) } {
                        append correct " $key \"$value\""
                    } else {
                        append correct " $key $value"
                    }
                }

                set key $left
                set value ""
            } else {
	        regsub -all {\"} $left {\\"} left 
                if { $value == "" } {
                    set value $left
                } else {
                    append value " $left"
                }
            }
        } else {
	    regsub -all {\"} $string {\\"} string 
            if { $value == "" } {
                set value $string
            } else {
                append value " $string"
            }
            break
        }
    }


    if { $key != "" } {
        if { ($value == "") || ([string first " " $value] != -1) } {
            append correct " $key \"$value\""
        } else {
            append correct " $key $value"
        }
    }

    set correct [string trimleft $correct]

    util.populate_array a $correct
}
#
#

client.register edittriggers start
client.register edittriggers client_connected
client.register edittriggers incoming
client.register edittriggers outgoing

window.menu_tools_add "Edit Triggers" edittriggers.edit ""


set edittriggers_default_triggers {## An example triggers.tkm file.  Comment lines begin with the '#'
## character.  This file can contain valid TCL commands and procedure
## definitions.  Three special procedures are predefined:
## 
##	trigger
##		when a line arrives from the server and matches
##		this regular expression execute this command
##
##	macro
##		when the user types a line matching this regular
##		expression execute this command
##
##	gag
##		when a line arrives from the server and matches
##		this regular expression supress the line, displaying
##		nothing on the main client window.
##
## You can find out more about Triggers, Gags and Macros at
## tkMOO-light's supporting website:
## 
##     http://www.awns.com/tkMOO-light/

## ---------------------------------------------------------------------
## MOOs send a '*** Connected ***' string when you connect.  Hide this
## message.

## Remove the single comment character '#' from the next line for
## this gag to take effect.

## ---------------------------------------------------------------------

## ---------------------------------------------------------------------
## Do you ever get annoyed because you have to type a '"' character
## before everything you want to say?  This complicated looking macro
## will test what you type to see if it starts with a special character
## or if the first word is a known command.  Anything that isn't
## recognised is assumed to be something you want to say.

## ---------------------------------------------------------------------

## ---------------------------------------------------------------------
## Pay special attention to your friends, Janet and John.  If they
## say anything then display their names in Blue letters.

## ---------------------------------------------------------------------

## ---------------------------------------------------------------------
## You can close the client window and use this trigger to alert you
## when someone starts talking.  This trigger rings the bell and
## makes the client window pop open.

## ---------------------------------------------------------------------

## ---------------------------------------------------------------------
## MOO Login Watchers display arrivals and departures with messages
## like the following:
## 	< Name has disconnected. ... >
## Display these notification messages in the client's status bar
## instead of displaying in the client's main window.

## ---------------------------------------------------------------------}

proc edittriggers.default_triggers {} {
    global edittriggers_default_triggers
    return [split $edittriggers_default_triggers "\n"]
}

proc edittriggers.create_default_file {} {
    set file [edittriggers.file]
    if { $file != "" } {
        return
    }

    set file [edittriggers.preferred_file]

    set fd ""
    catch { set fd [open $file "w+"] }
    if { $fd == "" } {
        window.displayCR "Can't write to file $file" window_highlight
        return
    }
    
    foreach line [edittriggers.default_triggers] {
        puts $fd $line
    }
    close $fd
}           

proc edittriggers.start {} {
    global edittriggers_slave edittriggers_use edittriggers_registered_aliases
    global edittriggers_contributed
    global edittriggers_initialised

    edittriggers.create_default_file

    set edittriggers_initialised 0

    array set edittriggers_contributed {
	trigger	{}
	macro	{}
	gag	{}
    }

    set edittriggers_use 1

    global edittriggers_hyperlink_command
    set edittriggers_hyperlink_command ""

    .output tag configure FontPlain  -font [fonts.plain]
    .output tag configure FontItalic -font [fonts.italic]

    set edittriggers_registered_aliases {}

}

proc edittriggers.client_connected {} {
    global edittriggers_use edittriggers_slave
    set default_usage 1
    set edittriggers_use $default_usage
    set use ""
    catch {
      set use [string tolower [worlds.get [worlds.get_current] UseModuleTriggers
]]  
    } 
    if { $use == "on" } {
        set edittriggers_use 1
    } elseif { $use == "off" } {
        set edittriggers_use 0
    }   
    ###

    edittriggers.init_slave

    return [modules.module_deferred]
}

#proc edittriggers.escape_tcl str {
#}

#}

proc edittriggers.make_hyperlink {tag command} {
    window.hyperlink.link .output T_$tag $command
}

#proc edittriggers.set_click_coords {x y} {
#}

#proc edittriggers.hyperlink_motion {tag x y} {
#}

#proc edittriggers.set_goto_command command {
#}   

#proc edittriggers.tag_hyperlink_Button1-ButtonRelease {} {
#}

proc edittriggers.incoming_line {} {
    global edittriggers_incoming_line
    return $edittriggers_incoming_line
}

proc edittriggers.set_incoming_line line {
    global edittriggers_incoming_line
    set edittriggers_incoming_line $line
}

proc edittriggers.incoming event {
    global edittriggers_slave edittriggers_incoming_line edittriggers_use

    if { $edittriggers_use == 0 } {
        return
    }

    global edittriggers_initialised
    if { $edittriggers_initialised == 0 } {
	set edittriggers_initialised 1
        edittriggers.init_slave 
    }

    set line [db.get $event line]

    set edittriggers_incoming_line $line

    if { [catch { interp eval $edittriggers_slave incoming NULL } rv] } {
	window.displayCR "Triggers Error (incoming): $rv" window_highlight
	window.displayCR "It looks like there's a problem with one of the triggers you" window_highlight
	window.displayCR "have defined." window_highlight
	return
    } {
	#
	#
        #

	db.set $event line $edittriggers_incoming_line

#window.displayCR "edittriggers.incoming rv=$rv"

        return $rv
    }
}

proc edittriggers.outgoing_line {} {
    global edittriggers_outgoing_line
    return $edittriggers_outgoing_line
}

proc edittriggers.outgoing line {
    global edittriggers_slave edittriggers_use edittriggers_outgoing_line
    if { $edittriggers_use == 0 } {
        return
    }
    global edittriggers_initialised
    if { $edittriggers_initialised == 0 } {
        set edittriggers_initialised 1
        edittriggers.init_slave 
    }
    set edittriggers_outgoing_line $line
    if { [catch { interp eval $edittriggers_slave outgoing NULL } rv] } {
        window.displayCR "Triggers Error (outgoing): $rv" window_highlight
	window.displayCR "It looks like there's a problem with one of the macros you" window_highlight
	window.displayCR "have defined." window_highlight
        return
    } {
        return $rv
    }   
}



proc edittriggers.preferred_file {} {
    global tcl_platform env tkmooLibrary
    set file triggers.tkm

    set dirs {}
    switch $tcl_platform(platform) {
        macintosh { 
	    if { [info exists env(TKMOO_LIB_DIR)] } {
	        lappend dirs [file join $env(TKMOO_LIB_DIR)]
	    }
	    if { [info exists env(PREF_FOLDER)] } {
                lappend dirs [file join $env(PREF_FOLDER)]
	    }
            lappend dirs [file join $tkmooLibrary]       
        }
        windows { 
	    if { [info exists env(TKMOO_LIB_DIR)] } {
	        lappend dirs [file join $env(TKMOO_LIB_DIR)]
	    }
	    if { [info exists env(HOME)] } {
	        lappend dirs [file join $env(HOME) tkmoo]
	    }
            lappend dirs [file join $tkmooLibrary]       
        }
        unix -
        default { 
	    if { [info exists env(TKMOO_LIB_DIR)] } {
	        lappend dirs [file join $env(TKMOO_LIB_DIR)]
	    }
	    if { [info exists env(HOME)] } {
	        lappend dirs [file join $env(HOME) .tkMOO-lite]
	    }
            lappend dirs [file join $tkmooLibrary]       
        }
    }

    foreach dir $dirs {
        if { [file exists $dir] && 
	     [file isdirectory $dir] &&
	     [file writable $dir] } {
            return [file join $dir $file]
        }
    }

    return [file join [pwd] $file]
}

proc edittriggers.file {} { 
    global tkmooLibrary tcl_platform env
                

    set f triggers.tkm
    set files {}

    switch $tcl_platform(platform) {
        macintosh {
            lappend files [file join [pwd] $f]
            lappend files [edittriggers.preferred_file]
        }
        windows {
            lappend files [file join [pwd] $f]
            lappend files [edittriggers.preferred_file]
        }
        unix -
        default {
            lappend files [file join [pwd] $f]
            lappend files [edittriggers.preferred_file]
        }
    }
       
    foreach file $files {
        if { [file exists $file] } {
            return $file
        }
    }
    
    return ""
}   

proc edittriggers.edit {} {
    set triggers_file [edittriggers.file]

    if { $triggers_file != "" } {
	set filehandle ""
        catch { set filehandle [open $triggers_file "r"] }
	if { $filehandle == "" } {
	    window.displayCR "Can't read from file $triggers_file" window_highlight
	    return
	}
        set lines ""
        while { [gets $filehandle line] != -1 } {
            lappend lines $line
        }
        close $filehandle
    } {
	set lines ""
    }

    set save_file $triggers_file
    if { $save_file == "" } {
	set save_file [edittriggers.preferred_file]
    }
    set e [edit.SCedit "" $lines "" "$save_file" "Triggers"]
    edit.configure_send $e "Set" "edittriggers.save $e \"$save_file\"" 1
    edit.configure_send_and_close $e "Set and Close" "edittriggers.save_and_close $e \"$save_file\"" 9
}

proc edittriggers.save_and_close { e file } {
    edittriggers.save $e $file
    edit.destroy $e
}

proc edittriggers.save { e file } {
    global edittriggers_slave
    set filehandle ""
    catch { set filehandle [open $file "w"] }
    if { $filehandle == "" } {
	window.displayCR "Can't write to file $file" window_highlight
	return
    }
    set CR ""
    foreach line [edit.get_text $e] {
	puts -nonewline $filehandle "$CR$line"
	set CR "\n"
    }
    close $filehandle

    edittriggers.init_slave 
}

proc edittriggers.remove_existing_tags {} {
    set tags [.output tag names]
    foreach tag $tags {
	if { [string match "T_*" $tag] == 1 } {
	    .output tag delete $tag
	}
    }
}

proc edittriggers.init_slave {} {
    global edittriggers_slave edittriggers_api
    global edittriggers_contributed
    catch { interp delete $edittriggers_slave }
    set edittriggers_slave [edittriggers.create_slave]
    edittriggers.initapi_slave $edittriggers_slave
    interp eval $edittriggers_slave $edittriggers_api
    set triggers_file [edittriggers.file]
    if { $triggers_file != "" } {
	interp eval $edittriggers_slave source \"$triggers_file\"
    }
    foreach type {trigger macro gag} {
        foreach record $edittriggers_contributed($type) {
	    interp eval $edittriggers_slave $type $record
        }
    }
    interp eval $edittriggers_slave sort_data
}

###
proc edittriggers.create_slave {} {
    return [interp create]
}

proc edittriggers.initapi_slave slave {
    global edittriggers_registered_aliases


    $slave alias incoming_line			edittriggers.incoming_line
    $slave alias set_incoming_line		edittriggers.set_incoming_line
    $slave alias outgoing_line			edittriggers.outgoing_line

    $slave alias worlds.get_current		worlds.get_current
    $slave alias worlds.get			worlds.get
    $slave alias worlds.get_generic		worlds.get_generic

    $slave alias window.append_tagging_info	window.append_tagging_info
    $slave alias window.assert_tagging_info	window.assert_tagging_info

    $slave alias window.display			window.display
    $slave alias window.displayCR		window.displayCR
    $slave alias window.display_tagged		window.display_tagged
    $slave alias client.outgoing		client.outgoing
    $slave alias io.outgoing			io.outgoing
    $slave alias modules.module_deferred	modules.module_deferred
    $slave alias modules.module_ok		modules.module_ok
    $slave alias unique_id			util.unique_id
    $slave alias tag				edittriggers.tag

    $slave alias colour.get			colourdb.get
    $slave alias fonts.get			fonts.get

    $slave alias bell				bell
    $slave alias window.iconify			window.iconify
    $slave alias window.deiconify		window.deiconify
    $slave alias window.set_status		window.set_status
    $slave alias wm				wm

    $slave alias make_hyperlink			edittriggers.make_hyperlink
    $slave alias window.hyperlink.link		window.hyperlink.link

    foreach ra $edittriggers_registered_aliases {
        $slave alias [lindex $ra 0] [lindex $ra 1]
    } 
}

proc edittriggers.register_alias {alias real} {
    global edittriggers_registered_aliases
    if { [info exists edittriggers_registered_aliases] == 0 } {
	window.displayCR "Triggers Error:	edittriggers.register_alias called before edittriggers.start" window_highlight
	window.displayCR "		you need to call edittriggers.register_alias from inside" window_highlight
	window.displayCR "		a registered .start procedure"  window_highlight
	return 0;
    }
    if { [lsearch -exact $edittriggers_registered_aliases "$alias $real"] == -1
} {
        lappend edittriggers_registered_aliases "$alias $real"
        return 1
    }
    return 0
} 

proc edittriggers.tag { option name args } {
    set x [concat [list .output tag $option T_$name] $args]
    eval $x
    .output tag lower T_$name sel
}

proc edittriggers.trigger args {
    global edittriggers_contributed
    lappend edittriggers_contributed(trigger) $args
}
proc edittriggers.macro args {
    global edittriggers_contributed
    lappend edittriggers_contributed(macro) $args
}
proc edittriggers.gag args {
    global edittriggers_contributed
    lappend edittriggers_contributed(gag) $args
}

set edittriggers_api {

    set gag_data [list]
    set trigger_data [list]
    set macro_data [list]

    set gag_data_x [list]
    set trigger_data_x [list]
    set macro_data_x [list]

    proc sort_data {} {
        global gag_data trigger_data macro_data \
	       gag_data_x trigger_data_x macro_data_x

        set type default
        catch {set type [worlds.get [worlds.get_current] Type]}
        set world default
        catch {set world [worlds.get [worlds.get_current] Name]}
        catch {set world [worlds.get [worlds.get_current] World]}

        set candidates {}
        foreach rc $trigger_data_x {
            set n [lindex $rc 0]
            set t [lindex $rc 1]
            set d [lindex $rc 7]

            if { ($n != "") && ([regexp $n $world] == 0) } { continue }
            if { ($t != "") && ([regexp $t $type] == 0) } { continue }
            if { ($d != "") && 
		 ([string tolower [worlds.get_generic On {} {} $d]] == "off") } {
                 continue
            }

            lappend candidates $rc
        }
	set candidates [lsort -decreasing -command cmp_priority $candidates]
        set trigger_data $candidates

        set candidates {}
        foreach rc $gag_data_x {
            set n [lindex $rc 0]
            set t [lindex $rc 1]
            set d [lindex $rc 4]

            if { ($n != "") && ([regexp $n $world] == 0) } { continue }
            if { ($t != "") && ([regexp $t $type] == 0) } { continue }
            if { ($d != "") && 
		 ([string tolower [worlds.get_generic On {} {} $d]] == "off") } {
                 continue
            }

            lappend candidates $rc
        }
        set gag_data $candidates

        set candidates {}
        foreach rc $macro_data_x {
            set n [lindex $rc 0]
            set t [lindex $rc 1]
            set d [lindex $rc 7]

            if { ($n != "") && ([regexp $n $world] == 0) } { continue }
            if { ($t != "") && ([regexp $t $type] == 0) } { continue }
            if { ($d != "") && 
		 ([string tolower [worlds.get_generic On {} {} $d]] == "off") } {
                 continue
            }

            lappend candidates $rc
        }
	set candidates [lsort -decreasing -command cmp_priority_macro $candidates]
        set macro_data $candidates
    }

    proc incoming line {
	set line [incoming_line]
        if { [match_gags $line] == 1 } {
            return [modules.module_ok]
        } {
            return [match_triggers $line]
        }
    }

    proc outgoing line {
        set line [outgoing_line]
        return [match_macros $line] 
    }


    proc match_gags line {
        global gag_data
        foreach data $gag_data {
	    set r [lindex $data 2]
	    set nocase [lindex $data 3]
	    if { $nocase } {
		if { [regexp -nocase -- $r $line] } {
		    return 1
		}
	    } {
		if { [regexp -- $r $line] } {
		    return 1
		}
	    }
        }
        return 0
    }



    proc highlight {tag range} {
	global highlights
	lappend highlights [list $tag $range]
    }



    proc highlight_all { regexp line tag } {
	foreach record [_match_all $regexp $line $tag] {
	    highlight [lindex $record 0] [lindex $record 1]
	}
    }

    proc _correct_offset { list plus } {
        set tmp {}
        foreach raft $list {
	    set tags [lindex $raft 0]
	    set fr [lindex [lindex $raft 1] 0]
	    set to [lindex [lindex $raft 1] 1]
	    incr fr $plus
	    incr to $plus
	    set newraft [list $tags [list $fr $to]]
	    lappend tmp $newraft
        }
        return $tmp
    }

    proc _match_all { regexp line tag } {
	if { [regexp -indices -- ($regexp) $line p0 p1] == 1 } {
	    set before  [string range $line 0 [expr [lindex $p1 0] - 1]]
	    set rbefore [_match_all $regexp $before $tag]

	    set after  [string range $line [expr [lindex $p1 1] + 1] end]
	    set rafter [_match_all $regexp $after $tag]


            set rafter [_correct_offset $rafter [expr [lindex $p1 1] + 1]]

	    return [concat $rbefore [list [list $tag $p1]] $rafter]
	} {
	    return {}
	}
    }

    proc highlight_all_apply { regexp line command } {
	foreach record [_match_all_apply $regexp $line $command] {
	    highlight [lindex $record 0] [lindex $record 1]
	}
    }

    proc _match_all_apply { regexp line command } {
	if { [regexp -indices -- ($regexp) $line p0 p1] == 1 } {

	    set before  [string range $line 0 [expr [lindex $p1 0] - 1]]
	    set rbefore [_match_all_apply $regexp $before $command]

	    set after  [string range $line [expr [lindex $p1 1] + 1] end]
	    set rafter [_match_all_apply $regexp $after $command]


	    set rafter [_correct_offset $rafter [expr [lindex $p1 1] + 1]]

	    set tag ""
	    set m1 [string range $line [lindex $p1 0] [lindex $p1 1]]
	    if { [catch { set tag [$command $m1] } rv] != 0 } {

		window.displayCR "Triggers Error: the following error ocurred" window_highlight
		window.displayCR "when attempting to execute the procedure '$command':" window_highlight
		window.displayCR "$rv" window_highlight

	    }
	    if { $tag != "" } {
	        return [concat $rbefore [list [list $tag $p1]] $rafter]
	    } {
		return [concat $rbefore [list] $rafter]
	    }
	} {
	    return {}
	}
    }


    proc match_triggers line {
        global trigger_data highlights

	set candidates {}
        foreach rc $trigger_data {
	    foreach { _ _ r _ _ _ nocase _ } $rc {}
	    if { $nocase } {
		if { [regexp -nocase -- $r $line] } {
		    lappend candidates $rc
		}
	    } { 
		if { [regexp -- $r $line] } {
		    lappend candidates $rc
		}
	    }
        }

	set highlights {}

	foreach rc $candidates {
	    foreach { _ _ r c _ cont nocase _ } $rc {}

	    if { $nocase } {
		if { [regexp -indices -nocase -- $r $line p0 p1 p2 p3 p4 p5 p6 p7 p8 p9] } {
                    foreach { m p } [list m0 $p0 m1 $p1 m2 $p2 m3 $p3 m4 $p4 m5 $p5 m6 $p6 m7 $p7 m8 $p8 m9 $p9] {
                        if { $p == {-1 -1} } {
                            break
                        }
                        set $m [string range $line [lindex $p 0] [lindex $p 1]]
                    }

                    eval $c
    
                    set_incoming_line $line

                    if { $cont == 0 } {
                        if { $highlights != {} } {
                            window.append_tagging_info [list $line [convert_tag_format $highlights]]
                            window.displayCR $line
                            window.assert_tagging_info $line
                        }

                        return [modules.module_ok]
                    }
		}
	    } {
                if { [regexp -indices -- $r $line p0 p1 p2 p3 p4 p5 p6 p7 p8 p9] } {
                    foreach { m p } [list m0 $p0 m1 $p1 m2 $p2 m3 $p3 m4 $p4 m5 $p5 m6 $p6 m7 $p7 m8 $p8 m9 $p9] {
                        if { $p == {-1 -1} } {
                            break
                        }
                        set $m [string range $line [lindex $p 0] [lindex $p 1]]
                    }

                    eval $c

                    set_incoming_line $line

                    if { $cont == 0 } {
                        if { $highlights != {} } {
                            window.append_tagging_info [list $line [convert_tag_format $highlights]]
                            window.displayCR $line
                            window.assert_tagging_info $line
                        }

                        return [modules.module_ok]
                    }
                }
	    }
	}

	if { $highlights != {} } {
            window.append_tagging_info [list $line [convert_tag_format $highlights]]
            window.displayCR $line
            window.assert_tagging_info $line

	    return [modules.module_ok]
	}

        return [modules.module_deferred]
    }

    proc convert_tag_format highlights {
        set new_info [list]
        foreach highlight $highlights {
            foreach {taglist range} $highlight { break }
            foreach {from to} $range { break }
	    incr to
            set record [list $from $to $taglist]
            lappend new_info $record
        }
        return $new_info
    }

    proc cmp_priority { a b } {
	return [expr int( [lindex $a 4] - [lindex $b 4] )]
    }
    proc cmp_priority_macro { a b } {
	return [expr int( [lindex $a 6] - [lindex $b 6] )]
    }

    proc match_macros line {
        global macro_data

	set candidates {}
        foreach data $macro_data {
	    foreach { _ _ r _ _ nocase _ _ } $data {}
	    if { $nocase } {
		if { [regexp -nocase -- $r $line] } {
		    lappend candidates $data
		}
	    } {
		if { [regexp -- $r $line] } {
		    lappend candidates $data
		}
	    }
        }

        foreach data $candidates {
	    foreach { _ _ r c cont nocase _ _ } $data {}

            if { $nocase } {
                if { [regexp -indices -nocase -- $r $line p0 p1 p2 p3 p4 p5 p6 p7 p8 p9] } {
                    foreach { m p } [list m0 $p0 m1 $p1 m2 $p2 m3 $p3 m4 $p4 m5 $p5 m6 $p6 m7 $p7 m8 $p8 m9 $p9] {
                        if { $p == {-1 -1} } {
                            break
                        }
                        set $m [string range $line [lindex $p 0] [lindex $p 1]]
                    }

                    eval $c

                    if { $cont == 0 } {
                        return [modules.module_ok]
                    }
                }
            } {
                if { [regexp -indices -- $r $line p0 p1 p2 p3 p4 p5 p6 p7 p8 p9] } {
                    foreach { m p } [list m0 $p0 m1 $p1 m2 $p2 m3 $p3 m4 $p4 m5 $p5 m6 $p6 m7 $p7 m8 $p8 m9 $p9] {
                        if { $p == {-1 -1} } {
                            break
                        }
                        set $m [string range $line [lindex $p 0] [lindex $p 1]]
                    }

                    eval $c

                    if { $cont == 0 } {
                        return [modules.module_ok]
                    }
                }
            }
        }
        return [modules.module_deferred]
    }

    proc car x {
	return [lindex $x 0]
    }
    proc cdr x {
	return [lrange $x 1 end]
    }


    proc trigger { args } {
	global trigger_data_x

        set default_regexp ".*"
        set default_command ""
        set default_type ""
        set default_priority 50
        set default_world ""
        set default_continue 0
        set default_nocase 0
        set default_directive ""

        set regexp $default_regexp
        set command $default_command
        set type $default_type
        set priority $default_priority
        set world $default_world
        set continue $default_continue
        set nocase $default_nocase
        set directive $default_directive

        while { $args != {} } {
            set token [car $args]
            set args [cdr $args]
            switch -- $token {
                -regexp {
                    set regexp [car $args]
                    set args [cdr $args]
                }
		-nocase {
                    set nocase 1
		}
                -command {
                    set command [car $args]
                    set args [cdr $args]
                }
		-type {
		    set type [car $args]
		    set args [cdr $args]
		}
		-name {
		    set world [car $args]
		    set args [cdr $args]
		}
		-world {
		    set world [car $args]
		    set args [cdr $args]
		}
		-priority {
		    set priority [car $args]
		    set args [cdr $args]
		}
		-continue {
		    set continue 1
		}
		-directive {
		    set directive [car $args]
		    set args [cdr $args]
		}
                default {
                    window.displayCR "Triggers Error (trigger definition): Unrecognised option '$token'" window_highlight
                    return
                } 
            }
        }        
        lappend trigger_data_x [list $world $type $regexp $command $priority $continue $nocase $directive]
    }

    proc gag { args } {
	global gag_data_x
        set default_regexp ""
        set default_type ""
        set default_world ""

        set default_nocase 0
        set default_directive ""

	set regexp $default_regexp
	set type $default_type
	set world $default_world
	set nocase $default_nocase
	set directive $default_directive

	while { $args != {} } {
	    set token [car $args]
	    set args [cdr $args]
	    switch -- $token {
		-regexp {
                    set regexp [car $args]
		    set args [cdr $args]
		}
		-nocase {
                    set nocase 1
		}
		-type {
		    set type [car $args]
		    set args [cdr $args]
		}
		-name {
		    set world [car $args]
		    set args [cdr $args]
		}
		-world {
		    set world [car $args]
		    set args [cdr $args]
		}
		-directive {
		    set directive [car $args]
		    set args [cdr $args]
		}
		default {
		    window.displayCR "Triggers Error (gag definition): Unrecognised option '$token'" window_highlight
		    return
		}
	    }
	}
	lappend gag_data_x [list $world $type $regexp $nocase $directive]
    }    

    proc macro { args } {
	global macro_data_x
        set default_regexp ""
        set default_command ""
        set default_type ""
        set default_world ""
        set default_continue 0
        set default_nocase 0
        set default_priority 50
        set default_directive ""

	set regexp $default_regexp
	set command $default_command
	set type $default_type
	set world $default_world
	set continue $default_continue
	set nocase $default_nocase
	set priority $default_priority
	set directive $default_directive

	while { $args != {} } {
	    set token [car $args]
	    set args [cdr $args]
	    switch -- $token {
		-regexp {
                    set regexp [car $args]
		    set args [cdr $args]
		}
		-nocase {
                    set nocase 1
		}
		-command {
                    set command [car $args]
		    set args [cdr $args]
		}
		-type {
		    set type [car $args]
		    set args [cdr $args]
		}
		-name {
		    set world [car $args]
		    set args [cdr $args]
		}
		-world {
		    set world [car $args]
		    set args [cdr $args]
		}
		-continue {
		    set continue 1
		}
		-priority {
		    set priority [car $args]
		    set args [cdr $args]
		}
		-directive {
		    set directive [car $args]
		    set args [cdr $args]
		}
		default {
		    window.displayCR "Triggers Error (macro definition): Unrecognised option '$token'" window_highlight
		    return
		}
	    }
	}
	lappend macro_data_x [list $world $type $regexp $command $continue $nocase $priority $directive]
    }
}

#
#
# window.menu_tools_add "@paste selection" {window.paste_selection} ""
#
#

proc xmcp11.do_xmcp-who* {} {
    if { [xmcp11.authenticated] == 1 } {
        request.set current xmcp11_multiline_procedure "xmcp-who*"
    }
}

proc xmcp11.do_callback_xmcp-who* {} {
    set which    [request.current]
    set lines    [request.get $which _lines]

    set w [who.create]
    who.refresh $w $lines
}

proc who.create {} {

    if { ![util.use_native_menus] } {
        return [who.old.create]
    }       

    global who_view who_lines
    set w .xmcp11_who
    if { [winfo exists $w] == 0 } {

        set who_view user
        set who_lines {}

        toplevel $w
        $w configure -bd 0 -menu $w.menu

	wm title $w "@xwho"

        menu $w.menu
        $w.menu add cascade -label "View" -menu $w.menu.view \
	    -underline 0
        menu $w.menu.view -tearoff 0
        $w.menu.view add command \
            -label "by User" -underline 3 \
            -command "who.view_by $w user"
        window.hidemargin $w.menu.view
        $w.menu.view add command \
            -label "by Location" -underline 3 \
            -command "who.view_by $w location"
        window.hidemargin $w.menu.view
	$w.menu.view add separator
        $w.menu.view add command \
            -label "Close" -underline 0 \
            -command "destroy $w"
        window.hidemargin $w.menu.view


	frame $w.c -bd 0
	window.toolbar_look $w.c
	   label $w.c.l -text ""
	   pack configure $w.c.l -side right


	text $w.t -highlightthickness 0 \
	    -setgrid 1 \
            -bd 0 \
	    -background "#dbdbdb" \
	    -cursor {} \
	    -relief flat \
	    -height 10 -width 20 \
	    -font [fonts.fixedwidth] \
	    -yscrollcommand "$w.s set"

	scrollbar $w.s -highlightthickness 0 \
	    -command "$w.t yview"
        window.set_scrollbar_look $w.s

	who.repack $w

	$w.t tag configure idle_30 -foreground [colourdb.get darkblue]
	$w.t tag configure idle_60 -foreground "#3333cc"
	$w.t tag configure idle_90 -foreground DodgerBlue3
	$w.t tag configure idle_120 -foreground SteelBlue3
	$w.t tag configure idle_300 -foreground SteelBlue2
	$w.t tag configure idle_600 -foreground SteelBlue1
	$w.t tag configure new_user -foreground red
    }
    return $w
}

proc who.old.create {} {
    global who_view who_lines
    set w .xmcp11_who
    if { [winfo exists $w] == 0 } {

        set who_view user
        set who_lines {}

        toplevel $w
        $w configure -bd 0

	wm title $w "@xwho"

	frame $w.c -bd 0
	   menubutton $w.c.v -text "View" -underline 0 -menu $w.c.v.m \
	       -underline 0
	   menu $w.c.v.m -tearoff 0
	   pack configure $w.c.v -side left
	   $w.c.v.m add command -label "by User" -underline 3 \
	       -command "who.view_by $w user"
	   window.hidemargin $w.c.v.m
	   $w.c.v.m add command -label "by Location" -underline 3 \
	       -command "who.view_by $w location"
	   window.hidemargin $w.c.v.m

	   label $w.c.l -text ""
	   pack configure $w.c.l -side right

	frame $w.canyon -bd 2 -relief sunken -height 2

	text $w.t -highlightthickness 0 \
	    -setgrid 1 \
            -bd 0 \
	    -background "#dbdbdb" \
	    -cursor {} \
	    -relief flat \
	    -height 10 -width 20 \
	    -font [fonts.fixedwidth] \
	    -yscrollcommand "$w.s set"

	scrollbar $w.s -highlightthickness 0 \
	    -command "$w.t yview"
        window.set_scrollbar_look $w.s

	who.repack $w

	$w.t tag configure idle_30 -foreground [colourdb.get darkblue]
	$w.t tag configure idle_60 -foreground "#3333cc"
	$w.t tag configure idle_90 -foreground DodgerBlue3
	$w.t tag configure idle_120 -foreground SteelBlue3
	$w.t tag configure idle_300 -foreground SteelBlue2
	$w.t tag configure idle_600 -foreground SteelBlue1
	$w.t tag configure new_user -foreground red
    }
    return $w
}


proc who.repack w {
    if { ![util.use_native_menus] } {
        return [who.old.repack]
    }       
    catch {
	pack forget [pack slaves $w]
    }
    pack configure $w.c -side top -fill x
    pack configure $w.s -side right -fill y
    pack configure $w.t -side left -expand 1 -fill both
}


proc who.old.repack w {
    catch {
	pack forget [pack slaves $w]
    }
    pack configure $w.c -side top -fill x
    pack configure $w.canyon -side top -fill x
    pack configure $w.s -side right -fill y
    pack configure $w.t -side left -expand 1 -fill both
}

proc who.view_by { w view } {
    global who_view who_lines
    set who_view $view
    who._refresh_by_$view $w $who_lines
}

proc who.new_users { old new } {
    if { $old == {} } {
	return {}
    }

    set oldp {}
    set newp {}

    foreach item $old {
	lappend oldp [lindex $item 1]
    }

    foreach item $new {
	set p [lindex $item 1]
	if { [lsearch $oldp $p] == -1 } {
	    lappend newp $p
	}
    }

    return $newp
}

proc who.refresh { w lines } {
    global who_lines who_view who_new_users
    set new_lines [who.lines_to_list $lines] 
    set who_new_users [who.new_users $who_lines $new_lines]
    set who_lines $new_lines
    who._refresh_by_$who_view $w $who_lines

    if { [winfo exists .map] == 1 } {
	map.show_people $new_lines
    }
}

proc who.lines_to_list lines {
    foreach line $lines {
        catch { unset foo }

	set foo(idle) 0
	set foo(name) ""
	set foo(location) ""
	set foo(poid) 0
	set foo(loid) 0

        util.populate_array foo $line
	lappend my_lines [list $foo(idle) $foo(name) $foo(location) $foo(poid) $foo(loid)]
    }
    return $my_lines
}

proc who._refresh_by_user { w lines } {
    global who_new_users
    $w.t configure -state normal
    $w.t delete 1.0 end

    set CR ""
    foreach item [lsort -command who.compare_user_idle $lines] {
	if { [lsearch $who_new_users [lindex $item 1]] != -1 } {
	    set colour new_user
	} {
	    set colour [who.colour [lindex $item 0]]
	}
        $w.t insert insert "$CR[lindex $item 1]" $colour
	set CR "\n"
    }

    $w.t configure -state disabled
    $w.t configure -width 20

    set length [llength $lines]
    if { $length == 1 } {
        $w.c.l configure -text "1 user"
    } {
        $w.c.l configure -text "$length users"
    }

    who.repack $w
}

proc who.colour idle {
    set colour idle_30
    if { $idle > 60 } {
        set colour idle_60
    }
    if { $idle > 90 } {
        set colour idle_90
    }
    if { $idle > 120 } {
        set colour idle_120
    }
    if { $idle > 300 } {
        set colour idle_300
    }
    if { $idle > 600 } {
        set colour idle_600
    }
    return $colour
}

proc who._refresh_by_location { w lines } {
    global room_idle who_new_users
    $w.t configure -state normal
    $w.t delete 1.0 end

    catch { unset room_idle }
    foreach item $lines {
	set room [lindex $item 2]
	set idle [lindex $item 0]
	if { [info exists room_idle($room)] == 0 } {
	    set room_idle($room) $idle
	} {
	    if { $idle < $room_idle($room) } {
	        set room_idle($room) $idle
	    }
	}
    }

    set CR ""
    set last_room ""
    foreach item [lsort -command who.compare_room_idle $lines] {
	set idle [lindex $item 0]
	set user [lindex $item 1]
	    set user "$user                              "
	    set user [string range $user 0 19]

	set room [lindex $item 2]
	    if { $room == $last_room } {
	        set room ""
	    } {
		set last_room $room
	    }
	    set room "$room                              "
	    set room [string range $room 0 19]

        $w.t insert insert "$CR$room " [who.colour $room_idle([lindex $item 2])]
	if { [lsearch $who_new_users [lindex $item 1]] != -1 } {
	    set colour new_user
	} {
	    set colour [who.colour [lindex $item 0]]
	}
        $w.t insert insert "$user" $colour
	set CR "\n"
    }

    set length [llength $lines]
    if { $length == 1 } {
        $w.c.l configure -text "1 user"
    } {
        $w.c.l configure -text "$length users"
    }

    $w.t configure -state disabled
    $w.t configure -width 41
    who.repack $w
}

proc who.compare_user_idle { this that } {
    if { [lindex $this 0] > [lindex $that 0] } {
	return 1;
    };
    return -1
}

proc who.compare_room_idle { this that } {
    global room_idle
    if { $room_idle([lindex $this 2]) > $room_idle([lindex $that 2]) } {
	return 1;
    };
    if { $room_idle([lindex $this 2]) == $room_idle([lindex $that 2]) } {

        if { [lindex $this 0] > [lindex $that 0] } {
	    return 1;
        };
        return -1

    };
    if { $room_idle([lindex $this 2]) < $room_idle([lindex $that 2]) } {
	return -1;
    };
}

#
#

proc window.open_list {} {
    set o .open_list

    if { [winfo exists $o] == 0 } {

    toplevel $o
    window.configure_for_macintosh $o

    window.bind_escape_to_destroy $o

    window.place_nice $o

    $o configure -bd 0

    wm iconname $o "Worlds"
    wm title $o "tkMOO-light: Worlds"

    listbox $o.lb \
	-height 15 -width 35 \
	-highlightthickness 0 \
	-setgrid 1 \
	-background #ffffff \
	-yscroll "$o.sb set"

	bind $o.lb        <Button1-ButtonRelease> "open.do_select"
	bind $o.lb <Double-Button1-ButtonRelease> "open.do_open"
	bind $o.lb <Triple-Button1-ButtonRelease> ""

    bind $o <MouseWheel> {
	.open_list.lb yview scroll [expr - (%D / 120) * 4] units
    }

    scrollbar $o.sb \
	-highlightthickness 0 \
	-command "$o.lb yview"

    window.set_scrollbar_look $o.sb

    frame $o.f1 -bd 0
    frame $o.f2 -bd 0

    set bw 4
    button $o.f1.up -width $bw -text "Up" -command open.do_up
    button $o.f1.open -width $bw -text "Open" -command "open.do_open"
    button $o.f1.edit -width $bw -text "Edit" -command "open.do_edit"
    button $o.f1.new -width $bw -text "New" -command "open.do_new"

    button $o.f2.down -width $bw -text "Down" -command open.do_down
    button $o.f2.copy -width $bw -text "Copy" -command "open.do_copy"
    button $o.f2.delete -width $bw -text "Delete" -command "open.do_delete"
    button $o.f2.close -width $bw -text "Close" -command "destroy $o"

    pack $o.f1.up $o.f1.open $o.f1.edit $o.f1.new \
	-side left \
	-padx 5 -pady 5
    pack $o.f2.down $o.f2.copy $o.f2.delete $o.f2.close \
	-side left \
	-padx 5 -pady 5

    pack $o.f2 -side bottom
    pack $o.f1 -side bottom

    pack $o.sb -fill y -side right -fill y
    pack $o.lb -side left -expand 1 -fill both

if { 0 } {
    pack $o.f1.up -side left
    pack $o.f1.spacer -side left -fill y
    pack $o.f1.open -side left
    pack $o.f1.new -side right
    pack $o.f1.edit

    pack $o.f2.down -side left
    pack $o.f2.spacer -side left -fill y
    pack $o.f2.copy -side left
    pack $o.f2.close -side right
    pack $o.f2.delete

    pack $o.f2 -fill x -side bottom
    pack $o.f1 -fill x -side bottom

    pack $o.sb -fill y -side right -fill y
    pack $o.lb -side left -expand 1 -fill both
}

    }

    worlds.load
    open.fill_listbox
    window.focus $o
}

proc open.fill_listbox {} {
    set o .open_list
    if { [winfo exists $o] == 0 } { return }

    set yview [$o.lb yview]

    $o.lb delete 0 end

    foreach world [worlds.worlds] {
        $o.lb insert end [worlds.get $world Name]
    }

    $o.lb yview moveto [lindex $yview 0]
}

proc open.do_up {} {
    global worlds_worlds
    set o .open_list
    set index [lindex [$o.lb curselection] 0]
    if { $index != {} } {

	set pair [lrange [worlds.worlds] [expr $index - 1] $index]

	if { [llength $pair] != 2 } { return }

	set worlds_worlds [lreplace [worlds.worlds] [expr $index - 1] $index [lindex $pair 1] [lindex $pair 0]]
        worlds.touch
        open.fill_listbox
	open.select_psn [expr $index - 1]
        window.post_connect

    }
}

proc open.do_down {} {
    global worlds_worlds
    set o .open_list
    set index [lindex [$o.lb curselection] 0]
    if { $index != {} } {

	set pair [lrange [worlds.worlds] $index [expr $index + 1]]

	if { [llength $pair] != 2 } { return }

	set worlds_worlds [lreplace [worlds.worlds] $index [expr $index + 1] [lindex $pair 1] [lindex $pair 0]]
        worlds.touch
        open.fill_listbox
	open.select_psn [expr $index + 1]
        window.post_connect

    }
}

proc open.do_open {} {
    set o .open_list
    set index [lindex [$o.lb curselection] 0]


    if { $index != {} } {
	set world [lindex [worlds.worlds] $index]
	client.connect_world $world
	after idle "destroy $o"
    }
}

proc open.do_edit {} {
    set o .open_list
    set index [lindex [$o.lb curselection] 0]
    if { $index != {} } {
	set world [lindex [worlds.worlds] $index]
        preferences.edit $world
    }
}

proc open.do_copy {} {
    set o .open_list
    set index [lindex [$o.lb curselection] 0]
    if { $index != {} } {
	set world [lindex [worlds.worlds] $index]
	set copy [worlds.copy $world [worlds.create_new_world]]

	if { $copy != -1 } {
	    worlds.set $copy Name "Copy of [worlds.get $copy Name]"
            open.fill_listbox
            window.post_connect
	    set copy [lindex [worlds.worlds] end]
            open.select_world $copy
            preferences.edit $copy
	}
    }
}

proc open.do_delete {} {
    set o .open_list
    set index [lindex [$o.lb curselection] 0]
    if { $index != {} } {
	set world [lindex [worlds.worlds] $index]
	set name [worlds.get $world Name]
        if { [tk_dialog .delete "Delete world" "Really delete '$name'?" {} 0 "Delete" "Cancel"] != 0 } { return }
	worlds.delete $world
        open.fill_listbox
        window.post_connect
    }
}


proc open.do_new {} {
    set new [worlds.create_new_world]
    worlds.set $new Name "New World"
    open.fill_listbox
    window.post_connect
    set new [lindex [worlds.worlds] end]
    open.select_world $new
    preferences.edit $new
}

proc open.select_psn psn {
    set o .open_list
    $o.lb see $psn
    $o.lb selection clear 0 end
    $o.lb selection set $psn
}

proc open.select_world world {
    set o .open_list
    set psn [lsearch -exact [worlds.worlds] $world]
    $o.lb yview $psn
    $o.lb selection clear 0 end
    $o.lb selection set $psn
}


proc open.do_select {} {
    set o .open_list
    set index [lindex [$o.lb curselection] 0]
    if { $index != {} } {
	set world [lindex [worlds.worlds] $index]
        if { [winfo exists .preferences] == 1 } { 
            preferences.edit $world
	}
    }
}
#
#




proc preferences.font_form {} {
    global tk_version
    if { $tk_version >= 8.0 } {
        return "font"
    } {
        return "string"
    }
}
proc preferences.file_form {} { 
    global tk_version   
    if { $tk_version >= 8.0 } {
        return "file"       
    } {             
        return "string"
    }           
}               

window.menu_preferences_add "Edit Preferences..." preferences.edit
window.menu_preferences_state "Edit Preferences..." disabled


proc preferences.set_world world {
    global preferences_current preferences_category

    preferences.copy_middle_to_world
    preferences.remove_middle
    preferences.fill_middle $world $preferences_category

    set preferences_current $world
}

proc preferences.set_category category {
    global preferences_current preferences_category 
    preferences.copy_middle_to_world
    .preferences.nottop.m configure -text "$category"
    preferences.remove_middle
    preferences.fill_middle $preferences_current $category
    set preferences_category $category
}

proc preferences.save {} {
    preferences.copy_middle_to_world

    catch { wm title . "[worlds.get [worlds.get_current] Name] - tkMOO-light" }
    catch { wm iconname . [worlds.get [worlds.get_current] Name] }

    preferences.clean_up
    destroy .preferences
    open.fill_listbox
    window.post_connect
}

proc preferences.copy_middle_to_world {} {
    global preferences_current preferences_v preferences_data

    foreach name [array names preferences_data] {
	foreach info $preferences_data($name) {
	    set dtype([lindex [util.assoc $info directive] 1]) [lindex [util.assoc $info type] 1]
	}
    }

    set keys [array names preferences_v]

    foreach key $keys {

        foreach {world directive} [split $key ","] {break}

	set type ""
	catch { set type $dtype($directive) }

	if { $type == "" } {
	    puts "preferences: c2m can't find a type for $directive!"
	}

	set v $preferences_v($key)

	if { $type == "boolean" } {
	    if { $v == 1 } { 
		set v On
            } {
	        set v Off
	    }
	}

	worlds.set $world $directive $v
    }
}

proc preferences.remove_middle {} {
    global preferences_middle_windows
    eval destroy [pack slaves .preferences.middle]
    catch {eval destroy $preferences_middle_windows}
    .preferences.middle configure -state normal
    .preferences.middle delete 1.0 end
    .preferences.middle configure -state disabled
}

proc preferences.destroy {} {
    global preferences_v
    catch { destroy .preferences }
    catch { unset preferences_v }
}

proc preferences.clean_up {} {
    global preferences_v preferences_current
    catch { unset preferences_v }
    catch { unset preferences_current }
}

proc preferences.set_title title {
    set pw .preferences
    wm title $pw $title
}


proc preferences.create_edit_window {} {
    set pw .preferences
    catch {destroy $pw}

    toplevel $pw
    window.configure_for_macintosh $pw

    global tcl_platform
    if { $tcl_platform(platform) != "macintosh" } {
        bind $pw <Escape> "preferences.clean_up; destroy $pw"
    }

    window.place_nice $pw

    $pw configure -bd 0

    preferences.set_title "tkMOO-light: Preferences"


    set nottop $pw.nottop
    frame $nottop -bd 0 -highlightthickness 0
    menubutton $nottop.m -menu $nottop.m.m -indicatoron 1
    menu $nottop.m.m -tearoff 0
    pack $nottop.m -side left

    pack $nottop -side top -fill x
    frame $pw.top_gutter -height 4 -relief sunken -bd 1 

    set bottom $pw.bottom
    frame $bottom -bd 0 -highlightthickness 0
    button $bottom.save -text "Save" -command preferences.save
    button $bottom.reset -text "Reset" \
	-command {preferences.remove_middle; preferences.fill_middle $preferences_current $preferences_category}
    button $bottom.cancel -text "Cancel" \
	-command {preferences.clean_up; destroy .preferences}


    pack $bottom.save $bottom.reset $bottom.cancel -side left \
	-padx 5 -pady 5
    pack $bottom -side bottom


    set middle $pw.middle
    set relief sunken
    text $middle -bd 1 -relief $relief -highlightthickness 0 -width 60 \
	-state disabled -cursor {} -yscrollcommand "$pw.middle_scrollbar set" \
	-height 26
    scrollbar $pw.middle_scrollbar -command "$pw.middle yview" \
	-highlightthickness 0
    window.set_scrollbar_look $pw.middle_scrollbar
    pack $pw.middle_scrollbar -side right -fill y
    foreach binding {
	1 B1-Motion Double-1 Triple-1 Shift-1 Double-Shift-1 Triple-Shift-1
    } {
	bind $pw.middle <$binding> {break}
    }
    pack $middle -fill both -expand on
    $middle configure -background [$pw cget -background]

    window.focus $pw
}

proc preferences.edit { {world ""} } {
    global preferences_data preferences_current preferences_category

    set pw .preferences


    if { [winfo exists $pw] == 0 } {
	preferences.create_edit_window
    }

    preferences.clean_up


    worlds.load

    if { $world == "" } {
        set current [worlds.get_current]
        if { $current != "" } {
            set preferences_current $current
        } {

            set new [worlds.create_new_world]

            set session [db.get .output session]
            set host [db.get $session host]
            set port [db.get $session port]

            worlds.set $new Name "$host:$port"
            worlds.set $new Host $host
            worlds.set $new Port $port
            worlds.set $new ShortList On

            open.fill_listbox
            window.post_connect
            set new [lindex [worlds.worlds] end]

            set preferences_current $new

            worlds.set_current $new

            set session [db.get .output session]
            db.set $session world $new
        }
    } {
        set preferences_current $world
    }




    set which $preferences_current

    set nottop $pw.nottop
    set cat [lindex [preferences.cp] 0]
    $nottop.m.m delete 0 end
    foreach c [preferences.reverse $cat] {
	$nottop.m.m add command \
	    -command "preferences.set_category \"$c\"" \
	    -label "$c"
	window.hidemargin $nottop.m.m
    }
    set preferences_category {General Settings}
    $nottop.m configure -text $preferences_category

    preferences.remove_middle
    preferences.fill_middle $preferences_current $preferences_category

    preferences.set_title "Preferences: [worlds.get $which Name]"

    wm deiconify $pw 
    after idle raise $pw
}

proc preferences.reverse list {
    if { $list == {} } {
	return {}
    } {
	return [concat [preferences.reverse [lrange $list 1 end]] [list [lindex $list 0]] ]
    }
}

proc preferences.change_action {world change_action parameter} {
    if { $change_action == {} } { return }
    if { $world == [worlds.get_current] } {
	eval [lindex $change_action 1] $parameter
    }
}

proc preferences.verify_updown_integer {str default low hi} {
    set value $default

    set str [string trim $str]

    if { ($str != "") && ([llength $str] == 1) } {


        regsub -all {^0} $str {} str

	if { $str == "" } {
	    set str 0
	}

        if { [regexp {^[-]*[0-9]+$} $str num] == 1 } {
            set value $num
	}
    }
    if { $value < $low } {
        set value $low
    }
    if { $value > $hi } {
        set value $hi
    }
    return $value
}

proc preferences.fill_middle {world category} {
    global preferences_data preferences_v \
	preferences_middle_windows

    global image_data
    image create bitmap up -data $image_data(right.xbm)
    image create bitmap down -data $image_data(left.xbm)

    set cp [preferences.cp]
    set categories [lindex $cp 0]
    set providors [lindex $cp 1]

    set middle .preferences.middle
    set preferences_middle_windows {}

    set CR ""

    foreach providor $providors {

        if { [info exists preferences_data($providor,$category)] == 0 } {
	    continue
        }

        set info $preferences_data($providor,$category)

	foreach preference $info {

	    set f $middle.[util.unique_id pf]
	    frame $f -bd 0
	    lappend preferences_middle_windows $f

            $middle configure -state normal
	    $middle insert end $CR
            $middle window create end -window $f
	    set CR "\n"
            $middle configure -state disabled

            foreach {_ directive} [util.assoc $preference directive] {_ type} [util.assoc $preference type] {break}

            if { $type == "font" } {
                set type [preferences.font_form]
            }
            if { $type == "file" } {
                set type [preferences.file_form]
            }

            foreach default [worlds.get_default $directive] {break}
            foreach {_ display} [util.assoc $preference display] {break}


	    label $f.l -text $display -anchor w -width 20 -justify left
	    pack $f.l -fill both -side left

	    switch -- $type {
	        boolean {
		    checkbutton $f.b \
			-padx 0 \
		        -variable preferences_v($world,$directive)
		    set v $default
		    catch { set v [worlds.get $world $directive] }
		    if { [string tolower $v] == "on" } { 
		        set v 1 
		    } {
		        set v 0
		    }
		    set preferences_v($world,$directive) $v
	            pack $f.b -side left
	        }

		choice-radio {
		    set choices [lindex [util.assoc $preference choices] 1]
		    if { [util.assoc $preference e-choices] != {} } {
			set callback [lindex [util.assoc $preference e-choices] 1]
			set choices [$callback]
		    }
		    foreach choice [preferences.reverse $choices] {
		        set b [util.unique_id choice]
		        radiobutton $f.$b \
                            -text $choice \
			    -value $choice \
			    -variable preferences_v($world,$directive)
		        pack $f.$b -side left
		    }
		    set v $default
		    catch { set v [worlds.get $world $directive] }
		    set preferences_v($world,$directive) $v
		}

		updown-integer {

		    set low [lindex [util.assoc $preference low] 1]
		    set high [lindex [util.assoc $preference high] 1]

                    set delta 1
		    if { [set ldelta [util.assoc $preference delta]] != {} } {
		        set delta [lindex $ldelta 1]
		    }


		    entry $f.e -font [fonts.get fixedwidth] -width 5
		    pack $f.e -side left
		    bind $f.e <Return> "
                        set x \[$f.e get\]
                        set a \[preferences.verify_updown_integer \$x $default $low $high\]
                        $f.e delete 0 end
                        $f.e insert insert \$a
			set preferences_v($world,$directive) \$a
		    "
		    bind $f.e <Leave> [bind $f.e <Return>]
		    bind $f.e <Tab> [bind $f.e <Return>]

		    frame $f.gap -width 2 -relief flat -bd 0 \
			-highlightthickness 0

                    button $f.bdown -text "-" -image down -bd 1 \
			-highlightthickness 0 \
			-width 10 \
                        -command "
                            set a \[preferences.verify_updown_integer \[$f.e get\] $default $low $high\]
                            incr a -$delta
                            set a \[preferences.verify_updown_integer \$a $default $low $high\]
                            $f.e delete 0 end
                            $f.e insert insert \$a
			    set preferences_v($world,$directive) \$a
                        "
                    button $f.bup -text "+" -image up -bd 1 \
			-highlightthickness 0 \
			-width 10 \
                        -command "
                            set a \[preferences.verify_updown_integer \[$f.e get\] $default $low $high\]
                            incr a $delta
                            set a \[preferences.verify_updown_integer \$a $default $low $high\]
                            $f.e delete 0 end
                            $f.e insert insert \$a
			    set preferences_v($world,$directive) \$a
                        "

                    pack $f.gap -side left -fill y
		    pack $f.bdown -side left -fill y
		    pack $f.bup -side left -fill y

                    set v $default
		    catch { set v [worlds.get $world $directive] }
		    set preferences_v($world,$directive) $v
		    $f.e delete 0 end
		    $f.e insert insert $v

		}

		choice-menu {
		    menubutton $f.mb -indicatoron 1 -menu $f.mb.m
		    pack $f.mb -side left
		    menu $f.mb.m -tearoff 0
		    set choices [lindex [util.assoc $preference choices] 1]
		    if { [util.assoc $preference e-choices] != {} } {
			set callback [lindex [util.assoc $preference e-choices] 1]
			set choices [$callback]
		    }
		    foreach choice $choices {
		        $f.mb.m add command -label $choice \
			    -command "set preferences_v($world,$directive) $choice; $f.mb configure -text $choice"
			window.hidemargin $f.mb.m
		    }
		    set v $default
		    catch { set v [worlds.get $world $directive] }
		    set preferences_v($world,$directive) $v
		    $f.mb configure -text $v
		}

		string {
		    entry $f.e -font [fonts.get fixedwidth] -width 30
		    bind $f.e <KeyRelease> "set preferences_v($world,$directive) \[$f.e get\]"
		    bind $f.e <Leave> "set preferences_v($world,$directive) \[$f.e get\]"
		    set v $default
		    catch { set v [worlds.get $world $directive] }
		    set preferences_v($world,$directive) $v
		    $f.e insert insert $v
		    pack $f.e -side left

		    if { $world == [worlds.default_world] && ($directive == "Name") } {
			$f.e delete 0 end 
			$f.e insert insert "DEFAULT WORLD"
			$f.e configure -state disabled -cursor {}
		    }
		}

		font {

		    entry $f.e -font [fonts.get fixedwidth] 
		    frame $f.gap -width 2 -relief flat -bd 0 \
			-highlightthickness 0
		    set v $default
		    catch { set v [worlds.get $world $directive] }
		    set preferences_v($world,$directive) $v
                    button $f.b -text "Choose" -pady 0 \
                        -highlightthickness 0 \
			-command "fontchooser.create \
                                      \"preferences.set_font $f.e $world $directive\" \
                                      \"\[$f.e get\]\""
		    bind $f.e <KeyRelease> "set preferences_v($world,$directive) \[$f.e get\]"
		    bind $f.e <Leave> "set preferences_v($world,$directive) \[$f.e get\]"
		    $f.e insert insert $v
		    pack $f.e -side left -fill x -expand 1
		    pack $f.gap -side left -fill y
		    pack $f.b -side right -fill y 
		}

                file {

                    entry $f.e -font [fonts.get fixedwidth]
                    frame $f.gap -width 2 -relief flat -bd 0 \
                        -highlightthickness 0
                    set v $default
                    catch { set v [worlds.get $world $directive] }
                    set preferences_v($world,$directive) $v
                    set filetypes [lindex [util.assoc $preference filetypes] 1]
                    set filetypes [list $filetypes]
		    set file_access [util.assoc $preference file-access]
		    set get_proc tk_getSaveFile
		    if { ($file_access != {}) &&
			 ([string tolower [lindex $file_access 1]] == "readonly") } {
			set get_proc tk_getOpenFile
		    }
                    global tcl_platform
                    button $f.b -text "Choose" -pady 0 \
                        -highlightthickness 0 \
                        -command "
                            set file \[$f.e get\]
                            if { \$tcl_platform(platform) == \"macintosh\" && 
                                 ! \[file exists \$file\] } {
                                set filename \[$get_proc -filetypes $filetypes \
                                    -parent .preferences \
                                    -title \"$display\" \
                                    \]
                            } {
                                set filename \[$get_proc -filetypes $filetypes \
                                    -initialdir \[file dirname \$file\] \
                                    -initialfile \[file tail \$file\] \
                                    -parent .preferences \
                                    -title \"$display\" \
                                    \]
                            }
                            if { \$filename != \"\" } {
                                set preferences_v($world,$directive) \$filename
                                $f.e delete 0 end
                                $f.e insert insert \$filename
                            }
                        "
                    bind $f.e <KeyRelease> "set preferences_v($world,$directive) \[$f.e get\]"
                    bind $f.e <Leave> "set preferences_v($world,$directive) \[$f.e get\]"   
                    $f.e insert insert $v
                    pack $f.e -side left -fill x -expand 1
                    pack $f.gap -side left -fill y 
                    pack $f.b -side right -fill y
                }

		colour {
		    entry $f.c -font [fonts.get fixedwidth] \
			-relief raised \
			-cursor {} \
			-state disabled
                    frame $f.gap -width 2 -relief flat -bd 0 \
                        -highlightthickness 0 
                    button $f.b -text "Choose" -pady 0 \
                        -highlightthickness 0 \
                        -command "colourchooser.create \
                                      \"preferences.set_colour $f $world $directive\" \
                                      \$preferences_v($world,$directive)"

		    set v $default
		    catch { set v [worlds.get $world $directive] }
                    catch { set v $preferences_v($world,$directive) }
                    set preferences_v($world,$directive) $v
		    $f.c configure -background $v
		    bind $f.c <1> "colourchooser.create \"preferences.set_colour $f $world $directive\" \$preferences_v($world,$directive)"
		    pack $f.c -side left
		    pack $f.gap -side left -fill y
		    pack $f.b -side right -fill y 
		}

                password {
		    entry $f.e \
		        -show "*" \
		        -font [fonts.get fixedwidth] -width 30
		    bind $f.e <KeyRelease> "set preferences_v($world,$directive) \[$f.e get\]"
		    bind $f.e <Leave> "set preferences_v($world,$directive) \[$f.e get\]"
		    set v $default
		    catch { set v [worlds.get $world $directive] }
		    set preferences_v($world,$directive) $v
		    $f.e insert insert $v
		    pack $f.e -side left
		}

		text {
		    $f.l configure -anchor nw
		    text $f.t -font [fonts.get fixedwidth] \
                        -borderwidth 1 \
                        -relief sunken \
		        -width 30 -height 2
		    global tcl_platform
		    if { $tcl_platform(platform) == "macintosh" } {
			$f.t configure -highlightbackground #cccccc
		    }
		    bind $f.t <KeyRelease> "set preferences_v($world,$directive) \[preferences.text_list_to_str \[preferences.get_text $f.t\]\]"
		    bind $f.t <Leave> "set preferences_v($world,$directive) \[preferences.text_list_to_str \[preferences.get_text $f.t\]\]"
		    set v $default
		    catch { set v [worlds.get $world $directive] }
		    set preferences_v($world,$directive) $v
		    $f.t insert insert $v
		    pack $f.t -side left
		}

		default {
		    puts "preferences, unable to handle type $type"
		}
	    }
	}
    }
}

proc preferences.get_text win {
    set lines {}
    set last [$win index end]
    for {set n 1} {$n < $last} {incr n} {
        set line [$win get "$n.0" "$n.0 lineend"]
        lappend lines $line
    }
    return $lines
}

proc preferences.text_list_to_str list {
    return [join $list "\n"]
}

proc preferences.set_font {args} {
    global preferences_v
    catch {
    set e [lindex $args 0]
    set world [lindex $args 1]
    set directive [lindex $args 2]
    $e delete 0 end
    $e insert insert [lrange $args 3 end]
    set preferences_v($world,$directive) [$e get]
    }
}


proc preferences.set_colour { f world directive r g b } {
    global preferences_v
    catch {
        set hex #[to_hex $r][to_hex $g][to_hex $b]
        $f.c configure -background $hex
        set preferences_v($world,$directive) $hex
    }
}

proc preferences.register { providor category info } {
    global preferences_data
    if { [info exists preferences_data($providor,$category)] == 1 } {
	set preferences_data($providor,$category) [concat $preferences_data($providor,$category) $info]
    } {
        set preferences_data($providor,$category) $info
    }
}

proc preferences.get_directive directive {
    global preferences_data
    set ld [string tolower $directive]
    foreach pc [array names preferences_data] {
	foreach record $preferences_data($pc) {
	    if { [string tolower [lindex [util.assoc $record directive] 1]] == $ld } {
		return $record
	    }
	}
    }
    return {}
}

proc preferences.cp {} {
    global preferences_data
    set keys [array names preferences_data]
    set categories {}
    set providors {}
    foreach key $keys {
        set pc [split $key ","]
        set p [lindex $pc 0]
        set c [lindex $pc 1]
	if { [lsearch -exact $providors $p] == -1 } {
            lappend providors $p
	}
	if { [lsearch -exact $categories $c] == -1 } {
            lappend categories "$c"
	}
    }
    return [list $categories $providors]
}


#puts "preferences.tcl contains font browser hooks..."
preferences.register window {General Settings} {
    { {directive Name}
          {type string}
	  {default ""}
	  {display World} }
    { {directive Host}
	  {type string}
	  {default ""}
	  {display Host} }
    { {directive Port}
	  {type string}
	  {default ""}
	  {display Port} }
    { {directive Login}
	  {type string}
	  {default ""}
	  {display "User name"} }
    { {directive Password}
	  {type password}
	  {default ""}
	  {display "Password"} }
    { {directive ShortList}
	  {type boolean}
	  {default off}
	  {display "On short list"} }
    { {directive LocalEcho}
	  {type boolean}
	  {default on}
	  {change_action client.set_echo}
	  {display "Local echo"} }
    { {directive InputSize}
	  {type choice-menu}
	  {default 1}
	  {display "Input window size"}
	  {change_action window.input_resize}
	  {choices {1 2 3 4 5}} }
    { {directive WindowResize}
	  {type boolean}
	  {default off}
	  {display "Always resize window"} }
    { {directive ClientMode}
	  {type choice-menu}
	  {default line}
	  {display "Client mode"}
	  {change_action client.set_mode}
	  {choices {character line}} }
    { {directive UseModuleLogging}
	  {type boolean}
	  {default off}
	  {display "Write to log file"} }
    { {directive LogFile}
          {type file}  
          {filetypes {
	      {{Log Files} {.log} TEXT} 
	      {{Text Files} {.txt} TEXT}
	      {{All Files} {*} TEXT}
	      } }
          {default ""}
          {display "Log file name"} }
    { {directive ConnectScript}
	  {type text}
	  {default "connect %u %p"}
	  {display "Connection script"} }
    { {directive DisconnectScript}
	  {type text}
	  {default {}}
	  {display "Disconnection script"} }
}

if { $tcl_platform(platform) == "unix" } {
	if { $tcl_platform(os) == "Darwin" } {
    	set default_binding "mac"
	} {
		set default_binding "emacs"
	}
} {
    set default_binding "windows"
}

preferences.register window {General Settings} [list	\
    [list {directive KeyBindings}	\
	  {type choice-menu}		\
	  "default $default_binding"	\
	  {display "Key bindings"}	\
	  {change_action bindings.set}	\
	  {choices {emacs tf windows macintosh default}} ] \
]

preferences.register window {Colours and Fonts} [list \
    { {directive ColourForeground} \
	  {type colour} \
	  {default "#000000"} \
	  {default_if_empty} \
	  {display "Normal text colour"} } \
    { {directive ColourBackground} \
	  {type colour} \
	  {default "#fefefe"} \
	  {default_if_empty} \
	  {display "Background colour"} } \
    { {directive ColourLocalEcho} \
	  {type colour} \
	  {default "#bbbbbb"} \
	  {default_if_empty} \
	  {display "Local echo colour"} } \
    { {directive ColourForegroundInput} \
	  {type colour} \
	  {default "#000000"} \
	  {default_if_empty} \
	  {display "Input text"} } \
    [list {directive ColourBackgroundInput} \
	  {type colour} \
	  [list default [colourdb.get pink]] \
	  {default_if_empty} \
	  {display "Input background"} ] \
    { {directive DefaultFont} \
	  {type choice-menu} \
	  {default fixedwidth} \
	  {display "Default font type"} \
	  {change_action preferences.x_reconfigure_fonts} \
	  {choices {fixedwidth proportional}} } \
    { {directive FontFixedwidth} \
	  {type font} \
	  {default ""} \
	  {default_if_empty} \
	  {display "Fixedwidth font"} } \
    { {directive FontPlain} \
	  {type font} \
	  {default ""} \
	  {default_if_empty} \
	  {display "Proportional font"} } \
    { {directive FontBold} \
	  {type font} \
	  {default ""} \
	  {default_if_empty} \
	  {display "Bold font"} } \
    { {directive FontItalic} \
	  {type font} \
	  {default ""} \
	  {default_if_empty} \
	  {display "Italic font"} } \
    { {directive FontHeader} \
	  {type font} \
	  {default ""} \
	  {default_if_empty} \
	  {display "Header font"} } \
] 

preferences.register client {Out of Band} {

    { {directive UseModuleXMCP11}
	  {type boolean}
	  {default on}
	  {display "XMCP/1.1 enabled"} }
    { {directive XMCP11_AfterAuth}
	  {type text}
	  {default {}}
	  {display "XMCP/1.1 connection\nscript"} }
}

preferences.register client {Special Forces} {
    { {directive UseLoginDialog}
        {type boolean}
        {default On}
        {display "Display login dialog"} }
    { {directive ModulesDebug}
        {type boolean}
        {default Off}
        {display "Display plugin errors"} }
}

proc preferences.x_reconfigure_fonts font {
    global window_fonts
    set window_fonts $font
    client.reconfigure_fonts
}
#
#

proc colourchooser.create { {callback ""} hexcolour } {
    global c
    global colour_r colour_g colour_b
    global colour_rh colour_gh colour_bh

    set c .colour

    if { [winfo exists $c] == 0 } {

    toplevel $c
    window.configure_for_macintosh $c

    window.bind_escape_to_destroy $c

    window.place_nice $c

    wm title $c "Colour Chooser"
    wm iconname $c "Colour Chooser"

    $c configure -bd 0 -highlightthickness 0

    frame $c.colour \
        -relief raised \
        -bd 1 -highlightthickness 0 \
        -height 40 
    pack $c.colour -side top -fill x -expand 1

    frame $c.r \
        -bd 0 -highlightthickness 0
    scale $c.r.s -from 0 -to 255 -sliderlength 20 -bd 1 -orient horizontal \
        -showvalue 0 \
        -highlightthickness 0 \
        -width 10 -length 255 \
        -variable colour_r -command colourchooser.update_colour

    label $c.r.ll -text "R: " -width 3 -justify left -anchor w \
        -bd 0 -highlightthickness 0
    label $c.r.lc -text "$colour_r" -width 3 -justify right -anchor e \
        -textvariable colour_r \
        -bd 0 -highlightthickness 0

    set colour_rh [to_hex $colour_r]
    label $c.r.lch -text "$colour_rh" -width 3 -justify right -anchor e \
        -textvariable colour_rh \
        -bd 0 -highlightthickness 0

    pack $c.r.s -side left
    pack $c.r.lch -side right
    pack $c.r.lc -side right
    pack $c.r.ll -side right

    frame $c.g \
        -bd 0 -highlightthickness 0
    scale $c.g.s -from 0 -to 255 -sliderlength 20 -bd 1 -orient horizontal \
        -showvalue 0 \
        -highlightthickness 0 \
        -width 10 -length 255 \
        -variable colour_g -command colourchooser.update_colour

    label $c.g.ll -text "G: " -width 3 -justify left -anchor w \
        -bd 0 -highlightthickness 0
    label $c.g.lc -text "$colour_g" -width 3 -justify right -anchor e \
        -textvariable colour_g \
        -bd 0 -highlightthickness 0
    set colour_gh [to_hex $colour_g]
    label $c.g.lch -text "$colour_gh" -width 3 -justify right -anchor e \
        -textvariable colour_gh \
        -bd 0 -highlightthickness 0

    pack $c.g.s -side left
    pack $c.g.lch -side right
    pack $c.g.lc -side right
    pack $c.g.ll -side right

    frame $c.b \
        -bd 0 -highlightthickness 0
    scale $c.b.s -from 0 -to 255 -sliderlength 20 -bd 1 -orient horizontal \
        -showvalue 0 \
        -highlightthickness 0 \
        -width 10 -length 255 \
        -variable colour_b -command colourchooser.update_colour

    label $c.b.ll -text "B: " -width 3 -justify left -anchor w \
        -bd 0 -highlightthickness 0
    label $c.b.lc -text "$colour_b" -width 3 -justify right -anchor e \
        -textvariable colour_b \
        -bd 0 -highlightthickness 0
    set colour_bh [to_hex $colour_b]
    label $c.b.lch -text "$colour_bh" -width 3 -justify right -anchor e \
        -textvariable colour_bh \
        -bd 0 -highlightthickness 0

    pack $c.b.s -side left
    pack $c.b.lch -side right
    pack $c.b.lc -side right
    pack $c.b.ll -side right

    frame $c.buttons \
        -bd 0 -highlightthickness 0
    button $c.buttons.close -text "Close" -command "destroy $c" \
        -bd 1 -highlightthickness 0
    button $c.buttons.accept -text " Ok  " -command "eval $callback \$colour_r \$colour_g \$colour_b; destroy $c" \
        -bd 1 -highlightthickness 0

    pack $c.buttons.accept $c.buttons.close -side left \
	-padx 5 -pady 5
    
    pack $c.r -side top
    pack $c.g -side top
    pack $c.b -side top
    pack $c.buttons -side top 

    }


    $c.colour configure -background $hexcolour

    set colour_r [from_hex [string range $hexcolour 1 2]]
    set colour_rh [string range $hexcolour 1 2]

    set colour_g [from_hex [string range $hexcolour 3 4]]
    set colour_gh [string range $hexcolour 3 4]

    set colour_b [from_hex [string range $hexcolour 5 6]]
    set colour_bh [string range $hexcolour 5 6]

    $c.buttons.accept configure -command "eval $callback \$colour_r \$colour_g \$colour_b; destroy $c"

    window.focus $c
    return $c
}

proc colourchooser.update_colour value {
    global c colour_r colour_g colour_b
    global colour_rh colour_gh colour_bh
    $c.colour configure \
        -background "#[to_hex $colour_r][to_hex $colour_g][to_hex $colour_b]"
    set colour_rh [to_hex $colour_r]
    set colour_gh [to_hex $colour_g]
    set colour_bh [to_hex $colour_b]
}

proc to_hex n {
    set hex {0 1 2 3 4 5 6 7 8 9 a b c d e f}
    set hi [lindex $hex [expr $n / 16]]
    set lo [lindex $hex [expr $n % 16]]
    return $hi$lo
}

proc from_hex h {
    set hex {0 1 2 3 4 5 6 7 8 9 a b c d e f}
    set letters [split [string tolower $h] {}]
    set value 0
    foreach letter $letters {
        set value [expr $value * 16]
        set value [expr $value + [lsearch -exact $hex $letter]]
    }
    return $value
}
#
#

proc fontchooser.do_select {} {
    set fc .fontchooser
    set family [$fc.f.l get [$fc.f.l curselection]]
    fontchooser.change_font_db -family $family
    fontchooser.update_tag
}

proc fontchooser.string_to_actual string {
    if { [catch { set actual [font actual "$string"] }] == 1 } {
        set actual [font actual does_not_exist]
    }
    return $actual
}

proc fontchooser.destroy w {
    global fontchooser_db
    unset fontchooser_db
    destroy $w
}

proc fontchooser.create { {callback ""} font } {
    fontchooser.font_to_db $font

    set nice_font "-Adobe-Helvetica-Medium-R-Normal-*-*-120-*-*-*-*-*-*"

    set fc .fontchooser

    if { [winfo exists $fc] == 0 } {
    toplevel $fc -bd 0 -highlightthickness 0
    window.configure_for_macintosh $fc

    global tcl_platform
    if { $tcl_platform(platform) != "macintosh" } {
        bind $fc <Escape> "fontchooser.destroy $fc"
    }

    window.place_nice $fc

    wm title $fc "Font Chooser"
    wm iconname $fc "Font Chooser"

    text $fc.t \
	-height 2 -width 20 \
	-bd 1 -highlightthickness 0 \
        -background [colourdb.get pink]

    $fc.t insert insert "The quick brown fox 01234 !&*#$%"
    $fc.t configure -state disabled
    $fc.t tag add font_style 1.0 end

    frame $fc.con -bd 0 -highlightthickness 0
    button $fc.con.accept -text " Ok  " \
	-command "eval $callback [fontchooser.db_to_font]; fontchooser.destroy $fc"
    button $fc.con.close -text "Close" \
	-command "fontchooser.destroy $fc"
    pack $fc.con.accept $fc.con.close -side left \
	-padx 5 -pady 5

    pack $fc.con -side bottom 
    pack $fc.t -side bottom -fill x

    frame $fc.f -bd 0 -highlightthickness 0
    pack $fc.f -side left -fill both -expand 1

    listbox $fc.f.l -height 10 \
        -font $nice_font \
        -bd 1 -highlightthickness 0 \
        -yscroll "$fc.f.s set" \
	-background #ffffff \
        -setgrid 1

    bind $fc <MouseWheel> {
	.fontchooser.f.l yview scroll [expr - (%D / 120) * 4] units
    }

    bind $fc.f.l <Button1-ButtonRelease> "fontchooser.do_select"

    pack $fc.f.l -side left -fill both -expand 1

    set families [lsort [font families]]

    foreach family $families {
        $fc.f.l insert end $family
    }

    scrollbar $fc.f.s -highlightthickness 0 \
        -bd 1 -highlightthickness 0 \
        -command "$fc.f.l yview"
    window.set_scrollbar_look $fc.f.s
    pack $fc.f.s -side right -fill y 

    frame $fc.r -bd 0 -highlightthickness 0
    pack $fc.r -side right -fill y 

    frame $fc.r.weight
    pack $fc.r.weight -side top

    label $fc.r.weight.l -text "weight:" -width 6 -justify right -anchor e \
        -font $nice_font
    pack $fc.r.weight.l -side left -fill x

    set weights {normal bold}
    menubutton $fc.r.weight.b -width 5 \
        -bd 1 \
        -text "[lindex $weights 0]" \
        -menu $fc.r.weight.b.m -indicatoron 1 \
        -font $nice_font
    pack $fc.r.weight.b -side left 

    menu $fc.r.weight.b.m -tearoff 0
    foreach weight {normal bold} {
        $fc.r.weight.b.m add command \
            -label $weight \
            -command "fontchooser.change_font_db -weight $weight;fontchooser.update_tag; $fc.r.weight.b configure -text $weight" 
    }

    frame $fc.r.slant
    pack $fc.r.slant -side top
 
    label $fc.r.slant.l -text "slant:" -width 6 -justify right -anchor e \
        -font $nice_font
    pack $fc.r.slant.l -side left -fill x

    set slants {roman italic}
    menubutton $fc.r.slant.b -width 5 \
        -bd 1 \
        -text "[lindex $slants 0]" \
        -menu $fc.r.slant.b.m -indicatoron 1 \
        -font $nice_font
    pack $fc.r.slant.b -side left 

    menu $fc.r.slant.b.m -tearoff 0
    foreach slant {roman italic} {
        $fc.r.slant.b.m add command \
            -label $slant \
            -command "fontchooser.change_font_db -slant $slant;fontchooser.update_tag; $fc.r.slant.b configure -text $slant"
    }


    frame $fc.r.size 
    pack $fc.r.size -fill x -side top
 
    label $fc.r.size.l -text "size:" -width 6 -justify right -anchor e \
        -font $nice_font
    pack $fc.r.size.l -side left -fill x

    entry $fc.r.size.e -width 3 -bd 1 -highlightthickness 0 -bg [colourdb.get pink]
    pack $fc.r.size.e -side left
    bind $fc.r.size.e <Leave> "fontchooser.set_size"
    bind $fc.r.size.e <Return> "fontchooser.set_size"
 
    }

    $fc.r.weight.b configure -text [fontchooser.db_value -weight]

    $fc.r.slant.b  configure -text [fontchooser.db_value -slant]

    set index [lsearch -exact [$fc.f.l get 0 end] [fontchooser.db_value -family]]
    $fc.f.l selection clear 0 end
    $fc.f.l selection set $index
    $fc.f.l see $index

    $fc.r.size.e delete 0 end
    $fc.r.size.e insert insert [fontchooser.db_value -size]

    $fc.con.accept configure \
	-command "fontchooser.work_it_out [list $callback]; fontchooser.destroy $fc"

    fontchooser.update_tag

    window.focus $fc
}

proc fontchooser.set_size {} {
    set fc .fontchooser
    set v [$fc.r.size.e get]
    set default_size 8
    set size $default_size
    catch { set size [expr 0 + [lindex $v 0]] }
    if { $size <= 0 } { set size $default_size };

    fontchooser.change_font_db -size $size
    fontchooser.update_tag

    $fc.r.size.e delete 0 end
    $fc.r.size.e insert insert $size
}

proc fontchooser.work_it_out { callback } {
    eval $callback [fontchooser.db_to_font]
}

proc fontchooser.font_to_db font {
    global fontchooser_db
    foreach {k v} [fontchooser.string_to_actual $font] {
        set fontchooser_db($k) $v
    }
}

proc fontchooser.db_to_font {} {
    global fontchooser_db
    return "{$fontchooser_db(-family)} $fontchooser_db(-size) $fontchooser_db(-weight) $fontchooser_db(-slant)"
}

proc fontchooser.change_font_db args {
    global fontchooser_db
    foreach {k v} $args {
        set fontchooser_db($k) $v
    }
    fontchooser.font_to_db [fontchooser.db_to_font]
}

proc fontchooser.db_value key {
    global fontchooser_db
    return $fontchooser_db($key)
}

proc fontchooser.update_tag {} {
    set fc .fontchooser
    $fc.t tag configure font_style -font "[fontchooser.db_to_font]"
}
#
#


proc plugin.plugins_directories {} {
    global tkmooLibrary tcl_platform env
    set dirs {}
    switch $tcl_platform(platform) {
        macintosh {
            lappend dirs [file join [pwd] plugins]
            if { [info exists env(TKMOO_LIB_DIR)] } {
                lappend dirs [file join $env(TKMOO_LIB_DIR) plugins]
            }
            if { [info exists env(PREF_FOLDER)] } {
                lappend dirs [file join $env(PREF_FOLDER) plugins]
            }
            lappend dirs [file join $tkmooLibrary plugins]
        }
        windows {
            lappend dirs [file join [pwd] plugins]
            if { [info exists env(TKMOO_LIB_DIR)] } {
                lappend dirs [file join $env(TKMOO_LIB_DIR) plugins]
            }
            if { [info exists env(HOME)] } {
                lappend dirs [file join $env(HOME) tkmoo plugins]
            }
            lappend dirs [file join $tkmooLibrary plugins]
        }
        unix -
        default {
            lappend dirs [file join [pwd] plugins]
            if { [info exists env(TKMOO_LIB_DIR)] } {
                lappend dirs [file join $env(TKMOO_LIB_DIR) plugins]
            }
            if { [info exists env(HOME)] } {
                lappend dirs [file join $env(HOME) .tkMOO-lite plugins]
            }
            lappend dirs [file join $tkmooLibrary plugins]
        }
    }
}

proc plugin.plugins_dir {} {
    foreach dir [plugin.plugins_directories] {
        if { [file exists $dir] &&
             [file isdirectory $dir] &&
             [file readable $dir] } {
            return $dir
        }
    }

    return ""
}

proc plugin.set_plugin_location location {
    global plugin_location
    set plugin_location $location
}
proc plugin.clear_plugin_location {} {
    global plugin_location
    unset plugin_location
}
proc plugin.plugin_location {} {
    global plugin_location
    if { [info exists plugin_location] } {
        return $plugin_location
    } {
        return INTERNAL
    }
}

proc plugin.source {} {
    set dir [plugin.plugins_dir]
    if { $dir == "" } { 
        window.displayCR "Can't find plugins directory, searched for:" window_highlight
        foreach dir [plugin.plugins_directories] {
            window.displayCR "  $dir" window_highlight
        }
        return 
    }

    set files [glob -nocomplain -- [file join $dir *.tcl]]
    foreach file $files {
        plugin.set_plugin_location $file
        source $file
    }
    set subdirs [glob -nocomplain -- [file join $dir *]]
    foreach subdir $subdirs {
        if { [file isdirectory $subdir] == 0 } { continue }
        set files [glob -nocomplain -- [file join $subdir *.tcl]]
        foreach file $files {
            plugin.set_plugin_location $file
	    source $file
        }
    }
    plugin.clear_plugin_location
}
client.register registry start

proc registry.start {} {
    global tcl_platform

    if { $tcl_platform(platform) != "windows" } {
	return;
    }

    if { [catch { package require registry 1.0 }] } {
	return;
    }


    registry set {HKEY_CLASSES_ROOT\.tkm} {} TkmWorld sz
    registry set {HKEY_CLASSES_ROOT\.tkm} {Content Type} "application/x-tkm" sz
    registry set {HKEY_CLASSES_ROOT\TkmWorld}
    registry set {HKEY_CLASSES_ROOT\TkmWorld} {} TkmWorld sz
    registry set {HKEY_CLASSES_ROOT\TkmWorld\DefaultIcon}


    set executable [info nameofexecutable]

    registry set {HKEY_CLASSES_ROOT\TkmWorld\DefaultIcon} {} \
       "$executable" sz

    registry set {HKEY_CLASSES_ROOT\TkmWorld\shell}
    registry set {HKEY_CLASSES_ROOT\TkmWorld\shell\open}
    registry set {HKEY_CLASSES_ROOT\TkmWorld\shell\open\command}
    registry set {HKEY_CLASSES_ROOT\TkmWorld\shell\edit}
    registry set {HKEY_CLASSES_ROOT\TkmWorld\shell\edit\command}


    set directory [file dirname $executable]

    registry set {HKEY_CLASSES_ROOT\TkmWorld\shell\open\command} {} \
	"\"$executable\" -dir \"$directory\" -f \"%1\"" sz
    registry set {HKEY_CLASSES_ROOT\TkmWorld\shell\edit\command} {} \
	{notepad.exe "%1"} sz

}
#
#

set main_host		""
set main_port		""
set main_login		""
set main_password	""
set main_script		""

set main_usage "Usage: tkmoo \[-dir <dir>\] \[host \[port 23\]\]
       tkmoo \[-dir <dir>\] -world <world>
       tkmoo \[-dir <dir>\] -f <file>"

set main_unprocessed {}

while { $argv != {} } {
    set main_this [lindex $argv 0]
    set argv [lrange $argv 1 end]
    switch -- $main_this {
        -f {
            set main_arg(-f) [lindex $argv 0]
            set argv [lrange $argv 1 end]
        }
        -world {
            set main_arg(-world) [lindex $argv 0]
            set argv [lrange $argv 1 end]
        }
        -dir {
            set main_arg(-dir) [lindex $argv 0]
            set argv [lrange $argv 1 end]
        }
        default {
            lappend main_unprocessed $main_this
            if { [string match {-*} $main_this] } {
            }
        }
    }
}

set main_error_str ""
if { [info exists main_arg(-dir)] } {

    if { [file isdirectory $main_arg(-dir)] &&
         [file readable $main_arg(-dir)] } {
        set env(TKMOO_LIB_DIR) $main_arg(-dir)
    } {
        append main_error_str "Error: can't read directory '$main_arg(-dir)'\n"
        append main_error_str "$main_usage"
    }
}

plugin.source
client.start 

if { ($main_error_str == "") && [info exists main_arg(-f)] } {


    if { ($main_arg(-f) == [worlds.file]) ||
	 ($main_arg(-f) == [edittriggers.file]) } {
        append main_error_str "Error: can't read file '$main_arg(-f)'\n"
        append main_error_str "$main_usage"
    } elseif { [file isfile $main_arg(-f)] &&
               [file readable $main_arg(-f)] } {

        set file $main_arg(-f)
        set lines [worlds.read_worlds $file]
        set worlds [worlds.apply_lines $lines]
        global worlds_worlds
        set worlds_worlds [concat $worlds_worlds $worlds]

	foreach world $worlds {
	    worlds.set $world "MustNotSave" 1
	}

        if { $worlds != {} } {
            client.connect_world [lindex $worlds 0]
        }
    } {
        append main_error_str "Error: can't read file '$main_arg(-f)'\n"
        append main_error_str "$main_usage"
    }

} elseif { ($main_error_str == "") && [info exists main_arg(-world)] } {


    set name $main_arg(-world)
    set matches [worlds.match_world "*$name*"]
    if { [llength $matches] == 1 } {
        client.connect_world [lindex $matches 0] 
    }
    if { [llength $matches] > 1 } {
        append main_error_str "'$name' could match any of the following Worlds:\n"
        foreach w $matches {
            append main_error_str "  [worlds.get $w Name]\n"
        }
    }   
    if { [llength $matches] == 0 } {
        append main_error_str "No World with Name matching '$name'\n"
    }   

} elseif { ($main_error_str == "") && ([llength $main_unprocessed] == 1) } {

    set host [lindex $main_unprocessed 0]
    set port 23

    set main_host $host
    set main_port $port
    if { ($main_host != "") && ($main_port != "") } {
        io.connect $main_host $main_port
    }

    if { $main_login != "" } {
        io.outgoing "connect $main_login $main_password"
    }

} elseif { ($main_error_str == "") && ([llength $main_unprocessed] == 2) } {

    set host [lindex $main_unprocessed 0]
    set port [lindex $main_unprocessed 1]
    set port [string trimleft $port "0"]
    if { [regexp {^[0-9]*$} $port] } {

        set main_host $host
        set main_port $port
        if { ($main_host != "") && ($main_port != "") } {
            io.connect $main_host $main_port
        }

        if { $main_login != "" } {
            io.outgoing "connect $main_login $main_password"
        }

    } {
        append main_error_str "Error: non numeric port '$port'\n"
        append main_error_str "$main_usage"
    }

} elseif { ($main_error_str == "") && ($main_unprocessed != {}) } {

    append main_error_str "Error: unknown arguments '$main_unprocessed'\n"
    append main_error_str "$main_usage"

} elseif { ($main_error_str == "") } {


}

if { $main_error_str != "" } {
    window.displayCR $main_error_str window_highlight
}

