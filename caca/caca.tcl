# caca.tcl
# by Nikopol
# created 20200523
#
# Requires packages: curl, caca-utils (img2txt)
#
# Usage: !caca <image URL>

namespace eval ::Caca {

## CONFIGURATION

bind pub - !caca ::Caca::command

# allowed channels
variable chans {##eggdrop}

# seconds between calls
variable thr 300

# image width (chars)
variable width 70

# path to image temporary file (in a writable directory)
variable tmpfile /tmp/cacaimg

# log successful commands (0=no, 1=yes)
variable log 1

## END CONFIG

variable last 0

proc command {nick uhost handle chann url} {
    variable chans
    variable thr
    variable last
    variable tmpfile
    variable width
    variable log
    global botnick
    # check allowed channels
    if {[lsearch -exact $chans $chann] == -1} { return }
    # check time
    set now [clock seconds]
    if {$now <= [expr {$last + $thr}]} { return } else { set last $now }
    # grab image
    set tmp "${tmpfile}_${botnick}_${now}"
    file delete -force $tmp
    if {[catch {exec curl -s -m 3 -o $tmp $url}] != 0} {
        file delete -force $tmp
        putlog "caca.tcl: curl error: $nick $uhost $chann $url"
        return
    }
    # check it is image
    if {[catch {exec file $tmp 2>@1} check] != 0} {
        file delete -force $tmp
        putlog "caca.tcl: file error: $tmp"
        return
    }
    set check [join [lrange [split $check :] 1 end]]
    if {[string first {image data} $check] == -1} {
        file delete -force $tmp
        putlog "caca.tcl: image error $nick $uhost $chann $url"
        return
    }
    #
    if {[catch {exec img2txt -f irc -W $width $tmp 2>@1} d] != 0} {
        file delete -force $tmp
        putlog "caca.tcl: caca error: $nick $uhost $chann $url"
        return
    }
    file delete -force $tmp
    # send crap
    set lines [split $d \n]
    foreach line $lines {
        puthelp "PRIVMSG $chann :$line"
    }
    if {$log} {
        putlog "caca.tcl: ok: $nick $uhost $chann $url"
    }
}

putlog {Loaded Caca script by Nikopol.}

} ;# end namespace

# vi: sw=4 ts=4 et
