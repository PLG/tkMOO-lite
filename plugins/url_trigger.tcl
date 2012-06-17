#
#       tkMOO
#       ~/.tkMOO-lite/plugins/url_trigger.tcl
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

client.register url_trigger start 90

proc url_trigger.start {} {

    edittriggers.trigger \
        -regexp {(ftp|http|https|telnet)://([^\"\'\`\\)\(<> ]+)} \
	-directive UseURLLinks \
        -continue \
        -command {
            highlight_all_apply {(ftp|http|https|telnet)://([^\"\'\`\\)\(<> ]+)} $line url_trigger.link
        }

    preferences.register url_trigger {Special Forces} {
        { {directive UseURLLinks}
            {type boolean}
            {default On}
            {display "Hyperlink URLs"} }
    }

    edittriggers.register_alias url_trigger.link url_trigger.link

}

proc url_trigger.link str {
    set cmd_tag [util.unique_id t]
    if { [webbrowser.is_available] } {
        edittriggers.make_hyperlink $cmd_tag "
            webbrowser.open $str
        "
        return T_$cmd_tag
    }
    return ""
}
