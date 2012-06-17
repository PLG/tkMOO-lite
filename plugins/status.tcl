#
#	tkMOO
#	~/.tkMOO-lite/plugins/status.tcl
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

client.register status start
client.register status client_connected
client.register status client_disconnected

preferences.register status {Statusbar Settings} {
    { {directive UseStatus}
        {type boolean}
        {default On}
        {display "Display elapsed time"} }
    { {directive StatusShowSeconds}
        {type boolean}
        {default Off}
        {display "Display seconds"} }
}

proc status.start {} {
    global status_frame status_task
    set status_frame 0
    set status_task 0
}

proc status.client_connected {} {
    global status_active status_time global status_seconds

    set use [worlds.get_generic On {} {} UseStatus]

    if { [string tolower $use] != "on" } { 
        status.destroy
        return
    };

    set seconds [worlds.get_generic Off {} {} StatusShowSeconds]
    if { [string tolower $seconds] == "on" } {
	set status_seconds 1
    } {
	set status_seconds 0
    }

    status.create
    set status_active 1
    set status_time [clock seconds]
    status.update
    return [modules.module_deferred]
}

proc status.client_disconnected {} {
    global status_active
    set status_active 0
    return [modules.module_deferred]
}

proc status.update {} {
    global status_active status_time status_frame status_seconds status_task
    if { [winfo exists $status_frame] == 0 } { return }
    if { $status_active == 0 } { return }
    set difference [expr [clock seconds] - $status_time]
    set hours [expr $difference / 3600]
    set minutes [expr ($difference - $hours * 3600) / 60]
    set minutes [string range "0$minutes" [expr [string length $minutes] -1] end]
    catch { after cancel $status_task }
    if { $status_seconds } {
        set seconds [expr $difference % 60]
        set seconds [string range "0$seconds" [expr [string length $seconds] -1] end]
        $status_frame.time configure -text "$hours:$minutes:$seconds"
	set status_task [after 1000 status.update]
    } {
        $status_frame.time configure -text "$hours:$minutes"
	set status_task [after 60000 status.update]
    }
}

proc status.create {} {
    global status_frame
    if { [winfo exists $status_frame] == 1 } { return };
    set status_frame [window.create_statusbar_item]
    frame $status_frame -bd 0
    label $status_frame.time -text "-" \
        -highlightthickness 0 -bg gold -bd 1 -relief raised
    pack configure $status_frame.time -side right
    pack $status_frame -side right
}

proc status.destroy {} {
    global status_frame
    if { [winfo exists $status_frame] == 1 } {
        window.delete_statusbar_item $status_frame
	# is this .repack now superfluous?
	window.repack
    }
}
