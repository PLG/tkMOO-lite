#
#	tkMOO
#	~/.tkMOO-lite/plugins/codename-heroes.tcl
#

client.register codename-heroes start

proc codename-heroes.start {} {
    # we need to register *something*
    mcp21.register codename-heroes 1.0 \
        codename-heroes codename-heroes.rpc
    mcp21.register_internal rcp mcp_negotiate_end
}

