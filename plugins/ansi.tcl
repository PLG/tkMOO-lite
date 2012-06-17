#
#       tkMOO
#       ~/.tkMOO-light/plugins/ansi.tcl
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

# This plugin tries to model ANSI.SYS and ISO 6429.  There are 16
# foreground colours, 8 bright and 8 dim, and 8 background colours,
# all dim.  Blinking is done by toggling a character's foreground
# colour between the normal foreground colour and the background
# colour.

# TODO
# blinking default foreground colour?

client.register ansi start
# before the triggers...
client.register ansi incoming 40
client.register ansi client_connected
client.register ansi client_disconnected

preferences.register ansi {Colours and Fonts} {
    { {directive UseModuleAnsi}
          {type boolean}
          {default Off}
          {display "Support ANSI Codes"} }
    { {directive ModuleAnsiBlink}
          {type boolean}
          {default On}
          {display "ANSI blink"} }
}

proc ansi.to_hex n {
    set hex {0 1 2 3 4 5 6 7 8 9 a b c d e f}
    set hi [lindex $hex [expr $n / 16]]
    set lo [lindex $hex [expr $n % 16]]
    return $hi$lo
}   

proc ansi.from_hex h {
    set hex {0 1 2 3 4 5 6 7 8 9 a b c d e f}
    set letters [split [string tolower $h] {}]
    set value 0
    foreach letter $letters {
        set value [expr $value * 16]
        set value [expr $value + [lsearch -exact $hex $letter]]
    }
    return $value
}   

# brighten that smile, +32 just looks right
proc ansi.brighten n {
    incr n 32
    if { $n > 255 } { set n 255 }
    return $n
}

proc ansi.client_connected {} {
    global ansi_use ansi_will_blink
    set ansi_use 0
    set ansi_will_blink 0

    set use [worlds.get_generic Off {} {} UseModuleAnsi]

    set def_fg [worlds.get_generic "#d0d0d0" foreground Foreground ColourForeground]    
    set def_bg [worlds.get_generic "#000000" background Background ColourBackground]    

    set will_blink [worlds.get_generic On {} {} ModuleAnsiBlink]    

    global ansi_default_foreground ansi_default_background
    set ansi_default_foreground $def_fg
    set ansi_default_background $def_bg

    # we need a bright version of the foreground colour...
    set hr [string range $def_fg 1 2]
    set hg [string range $def_fg 3 4]
    set hb [string range $def_fg 5 6]

    set r [ansi.brighten [ansi.from_hex $hr]]
    set g [ansi.brighten [ansi.from_hex $hg]]
    set b [ansi.brighten [ansi.from_hex $hb]]

    set def_fg_bright "#[ansi.to_hex $r][ansi.to_hex $g][ansi.to_hex $b]"

    .output tag configure ansi_fg.bright.default -foreground $def_fg_bright
    .output tag configure ansi_fg.dim.default    -foreground $def_fg
    .output tag configure ansi_bg.bright.default -background $def_bg
    .output tag configure ansi_bg.dim.default    -background $def_bg

    .output tag configure ansi_underline         -underline 1

    if { [string tolower $use] == "on" } {
	set ansi_use 1
    }

    if { [string tolower $will_blink] == "on" } {
	set ansi_will_blink 1
    }

    global ansi_blink
    set ansi_blink 0

    return [modules.module_deferred]
}

proc ansi.client_disconnected {} {
    # stop contributing tags to the output stream...
    window.remove_matching_tags ansi*
    return [modules.module_deferred]
}

proc ansi.start {} {
    global ansi_use \
	    ansi_intensity ansi_fg_tag ansi_bg_tag ansi_current_tags \
	    ansi_fg_colour ansi_bg_colour \
	    ansi_esc ansi_tags ansi_colour ansi_db ansi_default_intensity \
	    ansi_underline ansi_bell \
	    ansi_blink ansi_blink_task

    set ansi_blink 0
    set ansi_blink_task ""

    set ansi_esc "\x1b"
    # set ansi_esc "^"
    set ansi_bell "\x07"

    array set ansi_tags {
        0 ansi_reset
        1 ansi_bright
        2 ansi_dim
        4 ansi_underline
        5 ansi_blink
        7 ansi_reverse
        8 ansi_hidden
        30 ansi_foreground_black
        31 ansi_foreground_red
        32 ansi_foreground_green
        33 ansi_foreground_yellow
        34 ansi_foreground_blue
        35 ansi_foreground_magenta
        36 ansi_foreground_cyan
        37 ansi_foreground_white
        40 ansi_background_black
        41 ansi_background_red
        42 ansi_background_green
        43 ansi_background_yellow
        44 ansi_background_blue
        45 ansi_background_magenta
        46 ansi_background_cyan
        47 ansi_background_white
	default_foreground ansi_foreground_default
	default_background ansi_background_default
    }

    array set ansi_colour {
        30 black
        31 red
        32 green
        33 yellow
        34 blue
        35 magenta
        36 cyan
        37 white
        40 black
        41 red
        42 green
        43 yellow
        44 blue
        45 magenta
        46 cyan
        47 white
        default_foreground default
        default_background default
    }

    array set ansi_db "
       	bright.black	#555555
        dim.black	#000000
        bright.red	#FF5555
        dim.red		#AA0000
        bright.green	#88FF88
        dim.green	#00AA00
        bright.yellow	#FFFF55
        dim.yellow	#AA5500
        bright.blue	#5555FF
        dim.blue	#0000AA
        bright.magenta	#FF55FF
        dim.magenta	#AA00AA
        bright.cyan	#55FFFF
        dim.cyan	#00AAAA
        bright.white	#FFFFFF
        dim.white	#AAAAAA
    "

    set ansi_default_intensity dim
    set ansi_underline 0

    set ansi_use 0
    set xxx(fg) foreground
    set xxx(bg) background
    set ansi_fg_tag ""
    set ansi_bg_tag ""
    set ansi_intensity $ansi_default_intensity
    set ansi_current_tags ""
    # fg white, bg black
    set ansi_fg_colour default_foreground
    set ansi_bg_colour default_background

    window.menu_tools_add "ANSI Codes" ansi.callback

    global ansi_default_foreground ansi_default_background
    set ansi_default_foreground ""
    set ansi_default_background ""

    # set up the tags
    foreach fg {default black red green yellow blue magenta cyan white} {
    foreach in {bright dim} {
    foreach bg {default black red green yellow blue magenta cyan white} {
    foreach bl {1 0} {
        ansi.define_tag $bg $in $fg $bl
    } } } }
}

proc ansi.define_tag {background intensity foreground blink} {
    global ansi_db

    set tag "ansi.$background.$intensity.$foreground"

    if { $blink } {
	append tag ".blink"
    }

    if { [lsearch -exact [.output tag names] $tag] != -1 } {
	return
    }

    .output tag configure $tag

    if { $background != "default" } {
        .output tag configure $tag -background $ansi_db(dim.$background)
    }
    if { $foreground != "default" } {
        .output tag configure $tag -foreground $ansi_db($intensity.$foreground)
    }
}

proc ansi.start_blink {} {
    global ansi_blink_task
    if { [lsearch -exact [after info] $ansi_blink_task] < 0 } {
	set ansi_blink_task [after 1000 ansi.blink 1]
    }
}

proc ansi.blink on {
    global ansi_blink_task ansi_will_blink
    foreach tag [.output tag names] {
	if { [string match "ansi.*.blink" $tag] } {
            set tags($tag) 1
	}
    }

    foreach tag [array names tags "ansi.*.blink"] {
	ansi.toggle_tag $on $tag
    }

    if { $on } {
	set ansi_blink_task [after 1000 ansi.blink 0]
    } {
	set ansi_blink_task [after 500 ansi.blink 1]
    }
}

proc ansi.toggle_tag {on tag} {
    global ansi_db \
	ansi_default_foreground ansi_default_background

    foreach {_ background intensity foreground} [split $tag "."] {break}

    if { $on } {
	# ON
	if { $foreground == "default" } {
	    .output tag configure $tag \
		-foreground $ansi_default_foreground
	} {
	    .output tag configure $tag \
		-foreground $ansi_db($intensity.$foreground)
	}
    } {
	# OFF
	if { $background == "default" } {
	    .output tag configure $tag \
		-foreground $ansi_default_background
	} {
	    .output tag configure $tag \
		-foreground $ansi_db(dim.$background)
	}
    }
}

# we're trying to make the plugin process each line of text as
# quickly as possible.  the assumption is that most of the lines we
# receive won't have ANSI code in them, so we check to see if we're
# right and bale out as soon as possible.

proc ansi.incoming event {
    global ansi_esc ansi_use ansi_current_tags ansi_bell

    if { $ansi_use != 1 } {
	return [modules.module_deferred]
    }

    set line [db.get $event line]

    # let regsub count the bells for us...
    set bells [regsub -all -- $ansi_bell $line $ansi_bell new]

        while { $bells > 0 } {
            bell
            incr bells -1
        }
	# remove the bells
        regsub -all -- $ansi_bell $line {} new

    set line $new

    # any real ansi codes in here?
    if { [string first "$ansi_esc" $line] == -1 } {
	# if there are no other ansi codes in this line then this
	# module returns .module_deferred to allow other plugins to
	# continue processing.  we update the event data, either
	# stripping out the bells or adding the '<bell>' token to
	# the stream.
	db.set $event line $line

	return [modules.module_deferred]
    }

    set out_line ""
    set out_tags [list]

    set tagstart ""
    set active_tags ""

    while { [set esc_start [string first "$ansi_esc" $line]] != -1 } {

        set before [string range $line 0 [expr $esc_start - 1]]

        append out_line $before
        set from [string length $out_line]

        if { $active_tags != "" } {
            set record [list $tagstart $from $active_tags]
            lappend out_tags $record
        }

        set tagstart $from

        # skip the '['
	set rest [string range $line [expr $esc_start + 1] end]
	set esc_end [string first "m" $rest]

	set attributes [string range $rest 1 [expr $esc_end - 1]]

	set after [string range $rest [expr $esc_end + 1] end]

	set ansi_current_tags [ansi.attributes_to_tags [split $attributes ";"]]

        set active_tags $ansi_current_tags

        set line $after
    }

    # assumes that [0m; has already been sent before the trailing
    # text is written.  Ansi tags end at end of line.

    append out_line $line

    if { $active_tags != "" } {
        set record [list $tagstart $from $active_tags]
        lappend out_tags $record
    }

    # when the time comes to apply tags, if the line looks like
    # $out_line then apply these tags, if not then don't apply the
    # tags.

    set tagging_info [list $out_line $out_tags] 

    window.append_tagging_info $tagging_info

    db.set $event line $out_line

    # We modified the line and collected the tags, now let the
    # client's default behaviour or any other module calling
    # window.assert_tagging_info do the display work.
    return [modules.module_deferred]
}

proc ansi.attributes_to_tags at_list {
    global ansi_tags ansi_intensity ansi_colour \
	ansi_fg_colour ansi_bg_colour \
	ansi_default_intensity ansi_underline \
	ansi_blink ansi_will_blink
    set tags ""
    foreach at $at_list {
	switch -exact -- $at {
	    0 {
		set ansi_intensity $ansi_default_intensity
		# fg white, bg black
		set ansi_fg_colour default_foreground
		set ansi_bg_colour default_background
		set ansi_underline 0
		set ansi_blink 0
	    }
	    1 {
		set ansi_intensity bright
	    }
	    2 {
		set ansi_intensity dim
	    }
	    4 {
		set ansi_underline 1
	    }
	    5 {
		set ansi_blink 1
	    }
	    30 - 31 - 32 - 33 - 34 - 35 - 36 - 37 {
		set ansi_fg_colour $at
	    }
	    40 - 41 - 42 - 43 - 44 - 45 - 46 - 47 {
		set ansi_bg_colour $at
	    }
	    default {
	        # not all tags are supported...
	        catch {
	            append tags " $ansi_tags($at)"
	        }
	    }
	}
    }

    set rv ansi.$ansi_colour($ansi_bg_colour).$ansi_intensity.$ansi_colour($ansi_fg_colour)

    if { $ansi_blink && $ansi_will_blink } {
	append rv ".blink"
	ansi.start_blink
    }

    if { $ansi_underline } {
	append rv " ansi_underline"
    }

    return $rv
}

# control panel

proc ansi.controls {} {
    return {"ANSI Codes" "ansi.callback"}
}

proc ansi.callback {} {
    set c .modules_ansi_controlpanel
    catch { destroy $c }

    toplevel $c
    window.configure_for_macintosh $c

    window.place_nice $c
    window.bind_escape_to_destroy $c

    wm title    $c "ANSI Codes Control Panel"
    wm iconname $c "ANSI Codes"

    frame $c.buttons

    checkbutton $c.buttons.use \
	-padx 0 \
        -text "use ANSI codes" \
        -variable ansi_use

    checkbutton $c.buttons.blink \
	-padx 0 \
        -text "allow ANSI blink" \
        -variable ansi_will_blink

    button $c.buttons.close \
        -text "Close" \
        -command "destroy $c";

    pack append $c.buttons \
        $c.buttons.use       {left padx 4} \
        $c.buttons.blink       {left padx 4} \
        $c.buttons.close        {left padx 4}

    pack append $c \
        $c.buttons {fillx pady 4}

}
