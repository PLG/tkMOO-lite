#
#       tkMOO
#       ~/.tkMOO-lite/plugins/search_macro.tcl
#

# tkMOO-light is Copyright (c) Andrew Wilson 1994,1995,1996,1997,1998,1999
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

# This plugin defines a new Macro.  Type '?' followed by a search-term
# and the client will open a webbrowser containing the results from
# a search on a popular search engine.  For example:
# 
#	?weather in boston
#
# Two new entries are added to the 'Special Forces' category of
# the Preferences Editor.  The 'Use search-engines' check-box turns
# on the '?' macro.  The 'Preferred search-engine' menu lets you
# choose which search engine to run the query against.
#
# This plugin requires the webbrowser.tcl plugin.

client.register search_macro start 90

proc search_macro.start {} {
    edittriggers.macro \
	-regexp {^\?(.*)} \
	-priority 55 \
	-directive UseSearchEngines \
        -command {
	    search_macro.do_search $m1
        }

    edittriggers.register_alias search_macro.de_chaff search_macro.de_chaff
    edittriggers.register_alias search_macro.do_search search_macro.do_search

    # google
    edittriggers.register_alias search_macro.do_google search_macro.do_google
    search_macro.register google search_macro.do_google

    # yahoo
    edittriggers.register_alias search_macro.do_yahoo search_macro.do_yahoo
    search_macro.register yahoo search_macro.do_yahoo

    # altavista
    edittriggers.register_alias search_macro.do_altavista search_macro.do_altavista
    search_macro.register altavista search_macro.do_altavista

    preferences.register search_macro {Special Forces} {
        { {directive UseSearchEngines}
            {type boolean}
            {default On}
            {display "Use search-engines"} }
        { {directive SearchEngine}
            {type choice-menu}
            {default google}
	    {e-choices search_macro.engines}
            {display "Preferred search-engine"} }
    }
}

proc search_macro.engines {} {
    global search_macro_db
    return [lsort [array names search_macro_db]]
}

proc search_macro.do_search str {
    global search_macro_db
    set engine [worlds.get_generic google {} {} SearchEngine]
    $search_macro_db($engine) $str
}

proc search_macro.de_chaff str {
  set chaff {
      tell me what in who where when how is about was the of to in
      for is on that by with this be it www are as at i from a com
      an de was will s 0 1 2 3 4 5 6 7 8 9 edu htm why
  }
  set str  " $str "
  foreach word $chaff {
    regsub -all " $word " $str " " str
  }
  regsub -all "\\?|\&|\!" $str "" str
  set str [string trim $str]
  regsub -all " " $str "+" str
  return $str;
}

proc search_macro.register { engine callback } {
    global search_macro_db
    set search_macro_db($engine) $callback
}

proc search_macro.do_google str {
    set str [search_macro.de_chaff $str]
    if { $str != "" } {
        webbrowser.open "http://www.google.com/search?q=$str"
    } {
        webbrowser.open "http://www.google.com/"
    }
}

proc search_macro.do_yahoo str {
    set str [search_macro.de_chaff $str]
    if { $str != "" } {
        webbrowser.open "http://search.yahoo.com/bin/search?p=$str"
    } {
        webbrowser.open "http://www.yahoo.com/"
    }
}

proc search_macro.do_altavista str {
    set str [search_macro.de_chaff $str]
    if { $str != "" } {
        webbrowser.open "http://www.altavista.com/cgi-bin/query?pg=q&kl=XX&stype=stext&q=$str"
    } {
        webbrowser.open "http://www.altavista.com/"
    }
}
