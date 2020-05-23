# cowsay.tcl
# by Nikopol
# created 20200314
#
# Requires package: cowsay
#
# Usage:
#
# !moo
# !cowsay <text>

namespace eval ::Cowsay {

# CONFIGURATION

bind pub - !cowsay ::Cowsay::cowsay
bind pub - !moo ::Cowsay::cowsayMoo

# allowed channels
variable chans {##eggdrop #xyz}

# seconds between calls
variable thr 3600

# END CONFIG

variable last 0

proc cowsay {nick uhost handle chann txt} {
    variable chans
    variable thr
    variable last
    # check allowed channels
    if {[lsearch -exact $chans $chann] == -1} { return }
    # check time
    set now [clock seconds]
    set lmt [expr {$last + $thr}]
    if {$now <= $lmt} { return } else { set last $now }

    set res [split [string trim [exec /usr/games/cowsay $txt 2>@1]] \n]

    foreach line $res {
        puthelp "PRIVMSG $chann :$line"
    }
}

proc cowsayMoo {nick uhost handle chann txt} {
    variable chans
    variable thr
    variable last
    # check allowed channels
    if {[lsearch -exact $chans $chann] == -1} { return }
    # check time
    set now [clock seconds]
    set lmt [expr {$last + $thr}]
    if {$now <= $lmt} { return } else { set last $now }

    set res [split [string trim [exec /usr/games/cowsay moo 2>@1]] \n]

    foreach line $res {
        puthelp "PRIVMSG $chann :$line"
    }
}

putlog "Loaded Cowsay script by Nikopol."

} ;# end namespace Cowsay

# vi: sw=4 ts=4 et
