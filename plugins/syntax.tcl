############################################################
# syntax.tcl -- a syntax highlighting plugin for tkMOO-light.
# written by R Pickett (emerson (at) hayseed.net) with great help from reading
# and cut'n'pasting existing tkMOO-light plugin code.
# The homepage for this is <http://hayseed.net/~emerson/syntax.html>.
#
# tkMOO-light is an advanced chat/MOO client, written by Andrew Wilson.
# It can be found at <http://www.cs.cf.ac.uk/User/Andrew.Wilson/tkMOO-light/>.
#
# License:
#
# This silly little blob of TCL can be used freely for just about anything
# you like, with these two provisions:  (1) you may not remove or alter any of
# the text in this block of comments at the head of the file, and (2) if you
# make any changes to the code that you find useful or interesting or fun,
# you are strongly encouraged to send them back to me.
#
# History:
# 2002-03-05 -- 0.1.3 New:    - Concept of //-style comments for moocode.
#
# 1999-11-22 -- 0.1.2 Bugfix: - Fixed KeyRelease, Return, and Up/Down bindings
#                               to be {+ <script>} syntax and therefore not
#                               override the editor's default bindings.
#                             - Fix weird problem with Up/Down bindings doing
#                               highlighting on wrong line, causing very strange
#                               wraparound behavior when cursor on last line.
# 1999-10-14 -- 0.1.1 Change: - Updated core syntax plugin to work with new
#                               API for the editor's load event in 0.3.21-dev2
#
# 1999-08-27 -- 0.1   New:    - Added <Return>, arrows, and <Button> event
#                               catching so fast typists don't skip clean
#                               over the idle loop.
#                             - Used 0.3.21 load event callback scheme so that
#                               syntax definition plugins can decide at load time
#                               whether they want to handle an editor's text.
#                             - Related: changed the moo-code plugin to detect
#                               either MCP simpleedit 'moo-code' type OR 
#                               '@program' at the head of the line, LM-style.
#                             - Added in simple syntax_sendmail.tcl plugin
#                               to demonstrate how it's done - still broken
#                               wrt MCP simpleedit.
#                             - Ugly unmatched () code added.  Not at all
#                               correct yet, but proof-of-concept.
#                     Change: - Moved check_tags code into the core syntax
#                               plugin, to simplify (greatly) the creating
#                               of alternate syntax definitions.  Much more
#                               to be done here, but everything's in the Right
#                               Place(tm) now.
#                             - Removed trailing '_syntax' from all
#                               proc names.  Duh, they're about syntax...
#                             - Reworked regexen to use TCL 8.1 features if
#                               available.  This also fixed a regex bug wrt
#                               8.1.  8.1 is now preferred, tho not required.
#                     Bugfix: - fixed _language bug with highlighting inside
#                               a longer word, ie 'player' in 'the_player'
#                             - each iteration, tags were only being reparsed
#                               from the current cursor to lineend.  Fixed.
# 
# 1999-07-18 -- 0.0.4,  Bugfix: - 'strsub' typo
#                               - primitives highlighting even without
#                                 trailing (
#                               - nasty bug with string literals containing
#                                 escaped quotation marks.
#                       Change: - Reformatted these comments ;-)
#                       New:    - Added license info above.
#                               - Added syntax_moo_code_language bit for
#                                 detecting special variables; also, later,
#                                 for language primitives, maybe.
# 
# 1999-07-03 -- 0.0.3.2, Bugfix: - editors not created with the Tools->Editor
#                                  menu didn't start up the idle loop.
#
# 1999-06-29 -- 0.0.3.1, Bugfix: - primitives regex leading/trailing chars
#
# 1999-06-28 -- 0.0.3, New:    - use editor's 'load' event from 0.3.20 client.
#                              - removed duplicative "edit.SCcodeedit' procedure.
#                              - changed Andrew's syntax.toggle_syntax to
#                                syntax.select_syntax.
#                              - make individual syntax_<language> plugins add
#                                their name to a global syntax_types list
#                      Change: - much moving things around to separate 'syntax'
#                                core stuff from moo-code-specific stuff.  More
#                                can be done here.
#                              - make all line-based checks into regexen; iterate
#                                through them with the same blort of code instead
#                                of having several only-slightly-different
#                                procedures.
#
#                    
# 1999-06-08 -- 0.0.2, performance and namespace tweaks from Andrew.  Not
#                            released.
# 
# 1999-06-07 -- 0.0.1, first horrible annoying and useless public release.
#
############################################################


client.register syntax start

proc syntax.start {} {
    edit.add_edit_function "Syntax off" { syntax.select "" }
    edit.register load syntax.do_load 70
}

proc syntax.do_load {w args} {
    global syntax_db

    if { [info exists syntax_db($w)] } {
        if { $args != {} } {
            set from_to [lindex [util.assoc [lindex $args 0] range] 1]
        } else {
            set from_to {}
        }
        syntax.select $syntax_db($w) $w $from_to
    } 
}

proc syntax.select {type w args} {
    global syntax_db
    
    set from_to [lindex $args 0]
    if { $type == "" } {
	catch [unset syntax_db($w)]
        set tags [$w.t tag names]
        foreach tag $tags {
            if { [string match syntax_* $tag] } {
                $w.t tag delete $tag
            }
        }
        catch { after cancel $syntax_task }
    } else {
        set syntax_db($w) $type
        syntax.activate $w $from_to
    }
}

proc syntax.activate {w from_to} {	
    global syntax_db

    set type $syntax_db($w)


    syntax_${type}.initialize $w
    if { $from_to == "" } {
      set n 1
      set last [$w.t index end]
    } else {
      regsub {\..*$} [lindex $from_to 0] "" n
      regsub {\..*$} [lindex $from_to 1] "" last
    }
    for {set n} {$n < $last} {incr n} {
        syntax.check_tags $w.t $n.0
    }
    # Start up the idle loop
    bind $w.t <KeyRelease> {+
        regsub {\.t$} %W "" win
        if { [info exists syntax_db($win)] } {
          catch { after cancel $syntax_task }
          set syntax_task [ after 250 syntax.check_tags %W [%W index insert] ]
        }
    }
    # catch people who hit some return or arrow or the like to leave the line
    # before the idle loop can kick in.
    bind $w.t <Return> {+ syntax.check_tags  %W [ %W index insert ]}
    bind $w.t <Up> {+ syntax.check_tags  %W [ %W index insert ]}
    bind $w.t <Down> {+ syntax.check_tags  %W [ %W index insert ]}

    # Uncomment following line to experiment with colors on black background.
    #$w.t configure -bg black -fg white
}

proc syntax.check_tags { w line_number } {
    global syntax_db

    regsub {\.t$} $w "" win

    if { ! [info exists syntax_db($win)] } { return }

    set type $syntax_db($win)
    # Line-based stuff.
    set linestart [ $w index "$line_number linestart" ]
    set lineend [ $w index "$line_number lineend" ]
    
    # Clear tags on our current line; reparse every time.
    # This is a little kludgy, since there's no easy way to get the tags
    # just from our current line, we get a list of all tags in the editor
    # and remove the syntax_ ones from the current line.
    set tags [ $w tag names ]
    foreach tag $tags {
	if { [string match syntax_* $tag] } {
            $w tag remove $tag $linestart $lineend
	}
    }
    # Do all of the matching stuff exported in syntax_${type}_typelist
    set typelist syntax_${type}_typelist
    global $typelist
    foreach chunk [ lrange [set $typelist] 0 end ] {
        set name syntax_${type}_$chunk
        global $name
        set currpos $linestart
        while { [ set currpos [ $w search -regexp -count length [set $name] $currpos $lineend ] ] != "" } {
	    #next three lines ridiculous hack to simulate proper backreferences.
	    regexp [set $name] [$w get $currpos "$currpos + $length chars" ] match catch
	    set length [string length $catch]
	    set currpos [$w index "$currpos + [string first $catch $match] chars"]
            set newpos [$w index "$currpos + $length chars"]
            $w tag add $name $currpos $newpos
            set currpos $newpos
        }
    }

    # OK, here's an ugly stab at unmatched () code
    # Currently the algorithm is that we'll highlight the first ( or the last )
    # in a line if they're unbalanced in number.  This is not optimal.  We'd
    # like to have some good idea of where we have unbalance, and how many we
    # have. The latter of those two seems easier to implement.  Please to send
    # thoughts on this, as I plan to expand it greatly.
    set openfirst 0
    set closefirst 0
    set opencount 0
    set closecount 0
    set currpos $lineend
    while {[set currpos [$w search -backward "(" $currpos $linestart]] != ""} {
      set openfirst $currpos
      incr opencount
    }
    set currpos $linestart
    while { [ set currpos [ $w search ")" $currpos $lineend ] ] != "" } {
      set closefirst $currpos
      incr closecount
      set currpos [$w index "$currpos + 1 chars"]
    }
#    window.displayCR "openfirst: $openfirst	opencount:$opencount	closefirst:$closefirst	closecount:$closecount"
    if {($opencount > $closecount)} {
      $w tag add syntax_${type}_unmatched $openfirst 
    } elseif { ($closecount > $opencount ) } {
      $w tag add syntax_${type}_unmatched $closefirst 
    }
}


############################################################
# syntax_moo_code.tcl
############################################################

client.register syntax_moo_code start

proc syntax_moo_code.start {} {
    edit.add_edit_function "MOO Syntax" {syntax.select "moo_code"}
    edit.register load syntax_moo_code.check
}

 
proc syntax_moo_code.initialize w {
    global syntax_moo_code_primitives syntax_moo_code_specials
    global syntax_moo_code_stringliterals syntax_moo_code_numbers
    global syntax_moo_code_core syntax_moo_code_language
    global syntax_moo_code_typelist syntax_moo_code_c_comments

    set syntax_moo_code_typelist { primitives specials stringliterals numbers core language c_comments}

    set syntax_moo_code_primitiveslist [ join {
	abs acos add_property add_verb asin atan binary_hash
	boot_player buffered_output_length call_function caller_perms
	callers ceil children chparent clear_property connected_players
	connected_seconds connection_name connection_option
	connection_options cos cosh create crypt ctime db_disk_size
	decode_binary delete_property delete_verb disassemble
	dump_database encode_binary equal eval exp floatstr floor
	flush_input force_input function_info idle_seconds index
	is_clear_property is_member is_player kill_task length
	listappend listdelete listen listeners listinsert listset
	log log10 match max max_object memory_usage min move notify
	object_bytes open_network_connection output_delimiters
	parent pass players properties property_info queue_info
	queued_tasks raise random read recycle renumber reset_max_object
	resume rindex rmatch seconds_left server_log server_version
	set_connection_option set_player_flag set_property_info
	set_task_perms set_verb_args set_verb_code set_verb_info
	setadd setremove shutdown sin sinh sqrt strcmp string_hash
	strsub substitute suspend tan tanh task_id task_stack
	ticks_left time tofloat toint toliteral tonum toobj tostr
	trunc typeof unlisten valid value_bytes value_hash verb_args
	verb_code verb_info verbs
        }  {|} ]
    set syntax_moo_code_languagelist [ join {
        INT FLOAT OBJ STR LIST ERR player this caller verb args argstr
        dobj dobjstr prepstr iobj iobjstr NUM
        } {|} ]
    set syntax_moo_code_primitives "\[^a-zA-Z:_@\]($syntax_moo_code_primitiveslist)\ *\[(\]"
    set syntax_moo_code_language "\[^a-zA-Z_\]($syntax_moo_code_languagelist)\[^a-zA-Z_\]"
    set syntax_moo_code_specials {(;|:|\.|\(|\)|{|}|@|=|!=|<|>|\?|\||&&|\|\||\^|\+|-|\*|/)}
    set syntax_moo_code_stringliterals {("(\\"|[^"])*("|$))}
    set syntax_moo_code_c_comments {(//.*$)}
    set syntax_moo_code_numbers {(#*[0-9]+)}
    set syntax_moo_code_core {(\$[a-zA-Z0-9_]+)}

    if {[info tclversion] > 8.0} {
      set syntax_moo_code_primitives "(?:\[^\\w:@\]|^)($syntax_moo_code_primitiveslist)\ *\[(\]"
      set syntax_moo_code_language "(?:\\W|^)($syntax_moo_code_languagelist)(?:\\W|$)"
    }

    #Need to work on nice visible tags.
    $w.t tag configure syntax_moo_code_primitives -underline yes
    $w.t tag configure syntax_moo_code_numbers -foreground darkgreen
    $w.t tag configure syntax_moo_code_core -foreground darkred -underline yes 
    $w.t tag configure syntax_moo_code_specials -foreground blue -underline no
    $w.t tag configure syntax_moo_code_language -foreground darkred -underline no
    $w.t tag configure syntax_moo_code_stringliterals -foreground red -underline no
    $w.t tag configure syntax_moo_code_c_comments -foreground darkblue -background grey -underline no

    # For unmatched () or if/endif, etc.
    $w.t tag configure syntax_moo_code_unmatched -foreground red -background black
}

proc syntax_moo_code.check {w args} {
    global syntax_db

    if { ([ edit.get_type $w ] == "moo-code" ) || ([ $w.t search "@program" 1.0 ] != "") } {
      set syntax_db($w) moo_code
    }
}

############################################################
# syntax_sendmail.tcl
# 
# This is a proof-of-concept syntax definition plugin, showing off the three
# procedures that need to exist:  a <name>.start procedure to register the 
# edit.load callback for <name>.check and add a menu item to the editor;  a
# <name>.initialize procedure to create the regexen and associated tags,
# and a <name>.check procedure to do the parsing of the editor at
# load-time to see if you want to handle it.
############################################################

client.register syntax_sendmail start

proc syntax_sendmail.start {} {
    edit.add_edit_function "Sendmail Syntax" { syntax.select "sendmail" }
    edit.register load syntax_sendmail.check
}

proc syntax_sendmail.initialize w {

    global syntax_sendmail_headers syntax_sendmail_objects syntax_sendmail_parens
    global syntax_sendmail_typelist

    set syntax_sendmail_typelist { headers objects parens }

    set syntax_sendmail_headers {^(From:|Subject:|To:|Reply-to:)}
    set syntax_sendmail_objects {(#[0-9]+)}
    set syntax_sendmail_parens {(\(|\))}

    $w.t tag configure syntax_sendmail_headers -foreground darkred
    $w.t tag configure syntax_sendmail_objects -foreground darkgreen
    $w.t tag configure syntax_sendmail_parens -foreground blue
} 

proc syntax_sendmail.check {w args} {
    global syntax_db

    if { [ $w.t search "@@sendmail" 1.0 ] != "" } {
      set syntax_db($w) sendmail
    }
}
