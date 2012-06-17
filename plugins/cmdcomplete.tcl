#
#       tkMOO
#       ~/.tkMOO-light/plugins/cmdcomplete.tcl
#

# tkMOO-light is Copyright (c) Andrew Wilson 1994,1995,1996,1997,1998,
#                                            1999,2000
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

# hitting <ESC> or <TAB> to complete the first word on the line
# will try to expand for known commands.  if no commands are matching
# then it reverts to normal word completion from matches in the output
# window.  redefines window.dabbrev

rename window.dabbrev_search cmdcomplete.window.dabbrev_search

proc window.dabbrev_search {win partial} {
    set completions [cmdcomplete.window.dabbrev_search $win $partial]

    set input [.input get 1.0 {end -1 char}]
    set partial_psn [string wordstart $input [string length $input]]

    if { $partial == "" } {
        return $completions
    }

    if { $partial_psn != 0 } {
        return $completions
    }

    set commands [rehash.commands_unexpanded]

    # normalise  l*ook -> look
    # this may generate duplicates, but we dedupe later...
    set words {}
    foreach word $commands {
	 regsub -all {\*} $word {} word
	 lappend words $word
    }
    set commands $words

    set words {}
    foreach word $commands {
        if { [string match -nocase "$partial*" $word] } {
            lappend words [string tolower $word]
        }
    }

    # this far is actually a good fit, but we can improve the match
    # a little

    # find the set of shortest completions, which are longer than the
    # current partial.  so their length must be partial+1 chars long
    set length 999
    foreach word $words {
	set len [string length $word]
	if { ($len >= [expr [string length $partial] + 1]) && 
	     ($len < $length) } {
	    set length $len
	}
    }

    set blah $words
    set words {}
    foreach word $blah {
	if { [string length $word] == $length } {
	    lappend words $word
	}
    }

    # merge the commands and completions, and return the uniq list
    foreach word [concat $words $completions] {
	set uniq($word) 1
    }

    # caller may choose to sort the list
    return [array names uniq]
}
