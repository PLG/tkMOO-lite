#
#	tkMOO
#	~/.tkMOO-lite/plugins/webbrowser.tcl
#

# tkMOO-light is Copyright (c) Andrew Wilson 1994,1995,1996,1997,1998,
#                                            1999,2000,2001
#
#        All Rights Reserved
#
# Permission is hereby granted to use this software for private, academic
# and non-commercial use. No commercial or profitable use of this
# software may be made without the prior permission of the author.
#
# THIS SOFTWARE IS PROVIDED BY ANDREW WILSON ``AS IS'' AND ANY
# EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT ANDREW WILSON BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# A wrapper for the webbrowser on your platform.  On startup it'll
# look for an executable (on UNIX and Macintosh platforms), which
# you can override using the 'Webbrowser executable' directive in
# the Preferences Editor.  The plugin provies the Tcl procedure:
# 
#     webbrowser.open $url
# 
# to the Triggers environment and the rest of the client.  Check for
# browser availablility with
# 
#     webbrowser.is_available => 1 | 0

# You can call 'webbrowser.open $url' from the Triggers environment.
# For example the following trigger turns URLs into clickable
# hyperlinks.
#
#    proc url_link str {
#        set cmd_tag [unique_id t]
#        if { [webbrowser.is_available] } {
#            make_hyperlink $cmd_tag "webbrowser.open $str"
#            return T_$cmd_tag
#        }
#        return ""
#    }
#    trigger -regexp {(ftp|http|telnet)://([^\"\'\`\\)\(> ]+)} \
#        -continue \
#        -command {
#        highlight_all_apply {(ftp|http|telnet)://([^\"\'\`\\)\(> ]+)} $line url_link
#    }

client.register webbrowser start
client.register webbrowser stop
client.register webbrowser client_connected

proc webbrowser.start {} {
    global webbrowser_executable tcl_platform \
           webbrowser_redirector_conn webbrowser_redirector_port \
           webbrowser_ran

    if { $tcl_platform(platform) != "windows" } {
        preferences.register webbrowser {Special Forces} {
            { {directive WebbrowserExecutable}
                {type file}
                {file-access readonly}
                {default ""}
                {default_if_empty}
                {display "Webbrowser executable"} }
        }
        webbrowser.find_executable
    }

    if { $tcl_platform(platform) == "macintosh" } {
	package require Tclapplescript
    }

    edittriggers.register_alias webbrowser.open webbrowser.open
    edittriggers.register_alias webbrowser.is_available webbrowser.is_available

    set webbrowser_redirector_port ""

    if { $tcl_platform(platform) == "unix" &&
         [string tolower $tcl_platform(os)] != "darwin" } {
        # find the first available port
        for {set port 9999} {$port < 9999+5} {incr port} {
            set webbrowser_redirector_conn ""
            catch {
            set webbrowser_redirector_conn [socket -server webbrowser.do_redirect $port]
            }
	    if { $webbrowser_redirector_conn != "" } {
	        set webbrowser_redirector_port $port
	        break
	    }
        }
    }
    set webbrowser_ran [pid]
}

proc webbrowser.stop {} {
    global webbrowser_redirector_conn
    catch {
	close $webbrowser_redirector_conn
    }
}

proc webbrowser.client_connected {} {
    webbrowser.find_executable
    return [modules.module_deferred]
}

proc webbrowser.find_executable {} {
    global webbrowser_executable tcl_platform env

    # no file, no comment...
    set webbrowser_executable(unix) ""
    set webbrowser_executable(macintosh) ""

    # look for the executable, on unix and w95.  provide a list of
    # possible locations, pick the first one which really exists,
    # user-override gets preference.

    if { $tcl_platform(platform) == "unix" } {
        set executable [worlds.get_generic "" {} {} WebbrowserExecutable]
	lappend possibles $executable

        # path elements separated by colon
        set paths [split $env(PATH) ":"]

        set tail [file tail $executable]
        if { $tail != "" } {
	    foreach path $paths {
	        lappend possibles [file join $path $tail]
	    }
        }

	foreach path $paths {
	    lappend possibles [file join $path mozilla]
	}
	foreach path $paths {
	    lappend possibles [file join $path netscape]
	}

	foreach possible $possibles {
	    if { [file exists $possible] && [file executable $possible] } {
		set webbrowser_executable(unix) $possible
		break
	    }
	}
    }

    if { $tcl_platform(platform) == "macintosh" } {
	set possible [worlds.get_generic "" {} {} WebbrowserExecutable]
	if { [file exists $possible] && [file executable $possible] } {
	    set webbrowser_executable(macintosh) $possible
        }
    }
}

proc webbrowser.open url {
    global webbrowser_executable tcl_platform \
	   webbrowser_redirector_port webbrowser_redirector_key

    if { $tcl_platform(platform) == "windows" } {
	if { [string tolower $tcl_platform(os)] == "windows nt" } {
	    # Windows NT
	    # protect '&' if it appears in the URL
	    regsub -all "&" $url "\"\&\"" url
	    if { [catch {exec -- cmd /c start "$url" &} error] } {
		window.displayCR "Error opening URL $url" window_highlight
		window.displayCR "$error" window_highlight
	    }
	} {
	    # Windows 9x
	    if { [catch {exec -- start "$url" &} error] } {
		window.displayCR "Error opening URL $url" window_highlight
		window.displayCR "$error" window_highlight
	    }
	}
	return
    }

    if { $tcl_platform(platform) == "unix" &&
         [string tolower $tcl_platform(os)] == "darwin" } {

        if { [catch {
                 set osascript [open "|/usr/bin/osascript" w]
                 puts $osascript "open location \"$url\""
                 flush $osascript
                 close $osascript
             } error] } {
            window.displayCR "Error opening URL $url" window_highlight
            window.displayCR "$error" window_highlight
        }
        return
    }

    if { $tcl_platform(platform) == "unix" } {
	if { $webbrowser_executable(unix) == "" } {
	    return
	}

        # some meta characters break the -openURL behaviour in NS
	if { [regexp {[\,\?]} $url] == 1 } {
            webbrowser.redirector $url
            set key [webbrowser.random 1000000]
            set webbrowser_redirector_key $key
            set url "http://127.0.0.1:$webbrowser_redirector_port/$key"
	}

	if { [catch {exec $webbrowser_executable(unix) -remote openURL($url)}] != 0 } {
	    if { [catch {exec $webbrowser_executable(unix) $url &} error] } {
	        window.displayCR "Error opening URL $url" window_highlight
	        window.displayCR "$error" window_highlight
	    }
	}
	return
    }

    if { $tcl_platform(platform) == "macintosh" } {
	if { $webbrowser_executable(macintosh) == "" } {
	    return
	}
	if { [catch {
                 AppleScript execute "
	             tell application \"$webbrowser_executable(macintosh)\"
			 activate
	                 geturl \"$url\"
	             end tell
	         "
	      } error] } {
	    window.displayCR "Error opening URL $url" window_highlight
	    window.displayCR "$error" window_highlight
	}
    }

}

proc webbrowser.redirector url {
    global webbrowser_redirector_conn webbrowser_redirector_url
    set webbrowser_redirector_url $url
}

proc webbrowser.do_redirect { conn address port } {
    global webbrowser_redirector_conn webbrowser_redirector_url \
           webbrowser_redirector_key

    if { $address != "127.0.0.1" } {
	return
    }
    # get the key
    set data [read $conn 256]
    set get [lindex [split $data "\n"] 0]
    if { [regexp {^GET /([^ ]*) } $get _ key] == 0 } {
	return
    }
    if { $key != $webbrowser_redirector_key } {
        return
    }

    catch {
        puts $conn "HTTP/1.0 302 Redirect"
        puts $conn "Location: $webbrowser_redirector_url"
        puts $conn ""
        flush $conn
	close $conn
    }
    set webbrowser_redirector_key ""
    set webbrowser_redirector_url ""
}

proc webbrowser.is_available {} {
    global webbrowser_executable tcl_platform
    if { $tcl_platform(platform) == "windows" } {
        return 1
    }
    if { $tcl_platform(platform) == "unix" &&
         [string tolower $tcl_platform(os)] == "darwin" &&
         [file executable "/usr/bin/osascript"] } {
        return 1;
    }
    if { $webbrowser_executable($tcl_platform(platform)) == "" } {
        return 0
    }
    return 1
}

proc webbrowser.random {range} {
  global webbrowser_ran
  set webbrowser_ran [expr ($webbrowser_ran * 9301 + 49297) % 233280]
  set rv [expr int($range * ($webbrowser_ran / double(233280)))]
  return $rv    
}

# use native random if available
global tcl_version
if { $tcl_version >= 8.0 } {
proc webbrowser.random range {
    return [expr int(rand() * $range)]
}
}
