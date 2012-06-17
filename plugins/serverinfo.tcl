#
#	tkMOO
#	~/.tkMOO-lite/plugins/serverinfo.tcl
#

# tkMOO-light is Copyright (c) Andrew Wilson 1994,1995,1996,1997,1998,1999
#                                            2000,2001
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

# requires client version 0.3.28 or newer

client.register serverinfo start 60
client.register serverinfo client_connected

proc serverinfo.start {} {
    mcp21.register dns-com-awns-serverinfo 1.0 \
        dns-com-awns-serverinfo serverinfo.do_dns_com_awns_serverinfo
    mcp21.register_internal serverinfo mcp_negotiate_end
    # add menu items
    window.menu_help_add "SEPARATOR"
    window.menu_help_add "Server Home Page" serverinfo.display_home_url
    window.menu_help_add "Server Help Page" serverinfo.display_help_url
    serverinfo.init_db
    serverinfo.update_menu
}

proc serverinfo.client_connected {} {
    serverinfo.init_db
    serverinfo.update_menu
    return [modules.module_deferred]
}

proc serverinfo.init_db {} {
    global serverinfo_db
    set serverinfo_db(home_url) ""
    set serverinfo_db(help_url) ""
}

proc serverinfo.display_home_url {} {
    global serverinfo_db
    webbrowser.open $serverinfo_db(home_url)
}

proc serverinfo.display_help_url {} {
    global serverinfo_db
    webbrowser.open $serverinfo_db(help_url)
}

proc serverinfo.mcp_negotiate_end {} {
    # ask for serverinfo
    set overlap [mcp21.report_overlap]
    set version [util.assoc $overlap dns-com-awns-serverinfo]
    if { ($version != {}) && ([lindex $version 1] == 1.0) } {
        mcp21.server_notify dns-com-awns-serverinfo-get
    }
}

proc serverinfo.do_dns_com_awns_serverinfo {} {
    global serverinfo_db
    set home_url [request.get current home_url]
    set help_url [request.get current help_url]
    set serverinfo_db(home_url) $home_url
    set serverinfo_db(help_url) $help_url
    serverinfo.update_menu
}

proc serverinfo.update_menu {} {
    global serverinfo_db
    if { $serverinfo_db(home_url) == "" } {
        window.menu_help_state "Server Home Page" disabled
    } {
        window.menu_help_state "Server Home Page" normal
    }
    if { $serverinfo_db(help_url) == "" } {
        window.menu_help_state "Server Help Page" disabled
    } {
        window.menu_help_state "Server Help Page" normal
    }
}
