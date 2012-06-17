#
#	tkMOO
#	~/.tkMOO-lite/plugins/timezone.tcl
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

client.register timezone start 60

preferences.register timezone {Special Forces} {
    { {directive UseTimezone}
        {type boolean}
        {default On}
        {display "Send Timezone record"} }
} 

proc timezone.start {} {
    # we need to register *something*
    mcp21.register dns-com-awns-timezone 1.0 \
        dns-com-awns-timezone timezone.nop
    mcp21.register_internal timezone mcp_negotiate_end
}

proc timezone.nop {} {
    # do nothing
}

proc timezone.mcp_negotiate_end {} {
    set overlap [mcp21.report_overlap]
    set version [util.assoc $overlap dns-com-awns-timezone]
    if { ($version != {}) && ([lindex $version 1] == 1.0) } {
        set use [worlds.get_generic On {} {} UseTimezone]
        if { [string tolower $use] == "on" } {
            set timezone [clock format [clock seconds] -format "%Z"]
            mcp21.server_notify dns-com-awns-timezone \
                [list [list timezone $timezone]]
        }
    }
}
