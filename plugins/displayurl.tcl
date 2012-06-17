#
#	tkMOO
#	~/.tkMOO-lite/plugins/displayurl.tcl
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

# Support for the MCP/2.1 package dns-com-awns-displayurl.  Attempt
# to open a webbrowser pointing to the URL.
# 
# S->C #$#dns-com-awns-displayurl <auth> url: <some URL>
#
# The 'Special Forces'->'Use Display URL' checkbox must be checked in
# the Preferences Editor to enable this plugin.  This plugin requires
# the plugin webbrowser.tcl.

client.register displayurl start 60

preferences.register displayurl {Special Forces} {
    { {directive UseDisplayURL}
        {type boolean}
        {default On}
        {display "Use Display URL"} }
}

proc displayurl.start {} {
    mcp21.register dns-com-awns-displayurl 1.0 \
        dns-com-awns-displayurl displayurl.do_dns_com_awns_displayurl
}

proc displayurl.do_dns_com_awns_displayurl {} {
    set use [worlds.get_generic On {} {} UseDisplayURL]
    if { [string tolower $use] == "on" } {
        set url [request.get current url]
        webbrowser.open $url
    }
}
