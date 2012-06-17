#
#	tkMOO
#	~/.tkMOO-lite/plugins/message.tcl
#

# tkMOO-light is Copyright (c) Andrew Wilson 1994,1995,1996,1997,1998,1999.
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

# we need to wait for mcp21 to setup
client.register message start 60

proc message.start {} {
    mcp21.register dns-com-awns-status 1.0 \
	dns-com-awns-status message.dns_com_awns_status
    mcp21.register dns-com-ben-tfstatus 1.0 \
	dns-com-ben-tfstatus-update message.dns_com_ben_tfstatus_update
}

proc message.dns_com_awns_status {} {
    window.set_status [request.get current text]
}

proc message.dns_com_ben_tfstatus_update {} {
    window.set_status [request.get current content]
}

proc xmcp11.do_xmcp-status {} {
    if { [xmcp11.authenticated silent] == 1 } {
        window.set_status [request.get current text]
    };
}

proc mcp.do_status {} {
    if { [mcp.authenticated] == 1 } {
        window.set_status [request.get current msg]
    };
}
