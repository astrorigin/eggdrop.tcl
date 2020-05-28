# exec.tcl
# by Nikopol
# created 20200528
#
# This script lets bot owners execute any command to the hosting shell.
#
# Usage: !exec <command ...>

namespace eval ::Exec {

## CONFIGURATION

bind pub n !exec ::Exec::command

# seconds between calls
variable thr 1

# log stuff (0=no, 1=yes)
variable log 1

## END CONFIG

variable last 0

proc command { nick uhost handle chann cmd } {
    variable thr
    variable last
    variable log
    # check time
    set now [clock seconds]
    if {$now <= [expr {$last + $thr}]} { return } else { set last $now }
    # execute command
    if {[catch {exec {*}$cmd 2>@1} output] != 0} {
        puthelp "exec.tcl: $cmd failed"
        if {$log} {
            putlog "exec.tcl: error: ($cmd) ($output)"
        }
        return
    }
    ::PrivMsg $chann $output
    if {$log} {
        putlog "exec.tcl: ok: ($cmd) ($output)"
    }
}

putlog {Loaded Exec v0.1.0 script by Nikopol.}

} ;# end namespace

# vi: sw=4 ts=4 et
