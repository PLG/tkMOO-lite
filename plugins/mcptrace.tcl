#
#  mcptrace.tcl
#  Copyright (c) 1999 Michael Mantel <mantel@hypersurf.com>
#
#  Copy, modify, redistribute at will, as long as this
#  copyright notice is retained.

# This plugin creates a separate window to display all MCP communication
# between the client and the server.  The window can be opened when
# the client connects, by checking 'Show MCP Trace' in the 'Out of
# Band' category of the preferences editor, or can be opened at any
# time by using the Tools->'MCP Trace' menu item.
#
# This plugin redefines the procedure mcp21.server_notify.

client.register mcptrace start
client.register mcptrace incoming 39
# mcptrace.incoming should be called before mcp21.incoming
client.register mcptrace client_disconnected
client.register mcptrace client_connected

proc mcptrace.start {} {
  preferences.register mcptrace {Out of Band} {
    { {directive ShowMCPTrace}
      {type boolean}
      {default Off}
      {display "Show MCP Trace"} }
  }

  window.menu_tools_add "MCP Trace" {mcptrace.create}

# redefine mcp21.server_notify to go through mcptrace.send

  rename mcp21.server_notify mcptrace.server_notify

  proc mcp21.server_notify {message {keyvals {}}} {
    global mcp21_authentication_key

    if { $mcp21_authentication_key == "" } {
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

    mcptrace.display "C->S #$#$message $mcp21_authentication_key$kvstr" CtoS

    foreach k [array names multiple] {
        foreach v $multiple($k) {
            mcptrace.display "C->S #$#* $tag $k: $v" CtoS
        }
    }

    if { $multiline == 1 } {
        mcptrace.display "C->S #$#: $tag" CtoS
    }

    mcptrace.server_notify $message $keyvals
  }

}

proc mcptrace.client_disconnected {} {
  if { [winfo exists .mcptrace] } {
    destroy .mcptrace
  }

  return [modules.module_deferred]
}

proc mcptrace.client_connected {} {
  if { [worlds.get [worlds.get_current] ShowMCPTrace] == "On" } {
    mcptrace.create
  }

  return [modules.module_deferred]
}

proc mcptrace.incoming event {
  set line [db.get $event line]

  if { [string first "#$#" $line] == 0 } {
    mcptrace.display "S->C $line" StoC
  }

  return [modules.module_deferred]
}

proc mcptrace.create {} {
  if { [winfo exists .mcptrace] } {
    return
  }

  toplevel .mcptrace
  window.place_nice .mcptrace
  focus .

  wm iconname .mcptrace "MCP Trace"
  wm title .mcptrace "MCP Trace"

  text .mcptrace.output \
    -cursor {} \
    -font [fonts.fixedwidth] \
    -width 40 \
    -height 12 \
    -setgrid true \
    -relief flat \
    -bd 0 \
    -yscrollcommand ".mcptrace.scrollbar set" \
    -highlightthickness 0 \
    -wrap word

  scrollbar .mcptrace.scrollbar \
    -command ".mcptrace.output yview" \
    -highlightthickness 0

  pack .mcptrace.scrollbar -side right -fill y -in .mcptrace
  pack .mcptrace.output -side bottom -fill both -expand on -in .mcptrace

  window.set_scrollbar_look .mcptrace.scrollbar

  .mcptrace.output tag configure CtoS -foreground [colourdb.get red]
  .mcptrace.output tag configure StoC -foreground [colourdb.get blue]
}

proc mcptrace.display { text tag } {
  if { ![winfo exists .mcptrace] } {
    return
  }

  set last_char [.mcptrace.output index {end - 1 char}]
  set visible [.mcptrace.output bbox $last_char]

  .mcptrace.output configure -state normal
  .mcptrace.output insert end "\n"
  .mcptrace.output insert end $text $tag
  .mcptrace.output configure -state disabled

  if { $visible != {} } {
    .mcptrace.output yview -pickplace end
  }
}
