#
#       tkMOO
#       ~/.tkMOO-light/plugins/simpleedit.tcl
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
client.register simpleedit start 60

proc simpleedit.start {} {
    mcp21.register dns-org-mud-moo-simpleedit 1.0 \
        dns-org-mud-moo-simpleedit-content \
        simpleedit.do_dns_org_mud_moo_simpleedit_content   
}

proc simpleedit.do_dns_org_mud_moo_simpleedit_content {} {
    global simpleedit_db
    set which current
    catch {set which [request.get current _data-tag]}
    set content [request.get $which content]
    set reference [request.get $which reference]
    set type [request.get $which type]
    set name [request.get $which name]

    # All messsages in dns-org-mud-moo-simpleedit are multiline messages
    set lines $content

    set e [edit.create $name $name]
    set simpleedit_db($e:reference) $reference
    set simpleedit_db($e:type) $type
    edit.set_type $e $type
    edit.SCedit "" $lines "" $name $name $e
    edit.configure_send $e "Send" "simpleedit.send $e" 1
    edit.configure_send_and_close $e "Send and Close" "simpleedit.send_and_close $e" 10 
    edit.configure_close $e "Close" "simpleedit.close $e" 0
}   
 
# redefine normal editor behaviour
proc simpleedit.send e {
    global simpleedit_db
    set reference $simpleedit_db($e:reference)
    set type $simpleedit_db($e:type)
    set content [edit.get_text $e]
    mcp21.server_notify dns-org-mud-moo-simpleedit-set [list [list reference $reference] [list type $type] [list content $content 1] ]
}   

proc simpleedit.send_and_close e {
    global simpleedit_db
    set reference $simpleedit_db($e:reference)
    set type $simpleedit_db($e:type)
    set content [edit.get_text $e]
    mcp21.server_notify dns-org-mud-moo-simpleedit-set [list [list reference $reference] [list type $type] [list content $content 1] ]
    # clean up
    unset simpleedit_db($e:reference)
    unset simpleedit_db($e:type)
    edit.destroy $e
}   

proc simpleedit.close e {
    global simpleedit_db
    # clean up
    unset simpleedit_db($e:reference)
    unset simpleedit_db($e:type)
    edit.destroy $e
}   
