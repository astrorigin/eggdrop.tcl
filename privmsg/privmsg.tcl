# privmsg.tcl
# by Nikopol
# created 20200501

#namespace eval ::PrivMsg {

# PrivMsg arguments:
#
# receivers: string of names or channels separated with commas, eg: #lamers
#            cf. RFC 1459, §4.4.1
# txt: the (lengthy) text, non-empty string
# prefix: string to prepend to each line, can be empty ("")
# maxsz: maximum number of chars accepted by server, eg. 450
# callback: procedure taking one string argument (line to be sent).
#           default: puthelp
#
proc PrivMsg { receivers txt {prefix ""} {maxsz 450} {callback puthelp} } {

    set prefix "PRIVMSG $receivers :$prefix"

    # check arguments
    set prefixsz [string length [encoding convertto utf-8 $prefix]]
    set txtlen [string length $txt]
    set maxsz [expr int($maxsz)]

    if {[string length $receivers] == 0
        || $txtlen == 0
        || $maxsz <= [expr {$prefixsz + 3}]} {
        error "PrivMsg: invalid argument"
    }

    # the easy way
    set utxtsz [string length [encoding convertto utf-8 $txt]]

    if {[expr {$prefixsz + $utxtsz}] <= $maxsz} {
        if {![string is space $txt]} {
            foreach part [split $txt "\n"] {
                $callback "$prefix$part"
            }
        }
        return
    }

    # split
    set sentmaxsz [expr {$maxsz - $prefixsz}]
    set sentence ""
    set sentsz 0

    for {set x 0} {$x < $txtlen} {incr x} {
        set char [string index $txt $x]
        if {$char == "\n"} {
            # switch to next line
            if {$sentsz != 0} {
                if {![string is space $sentence]} {
                    $callback "$prefix$sentence"
                }
                set sentence ""
                set sentsz 0
            }
            continue
        }
        set ucharsz [string length [encoding convertto utf-8 $char]]
        if {[expr {$sentsz + $ucharsz}] <= $sentmaxsz} {
            # append to buffer
            set sentence [string cat $sentence $char]
            incr sentsz $ucharsz
        } else {
            # reached max size
            if {$char == " "} {
                # discard trailing space
                if {![string is space $sentence]} {
                    $callback "$prefix$sentence"
                }
                set sentence ""
                set sentsz 0
                continue
            }
            # find the last space
            set lastspace [string last " " $sentence]
            if {$lastspace < 1} {
                # sentence without space or with leading space
                if {![string is space $sentence]} {
                    $callback "$prefix$sentence"
                }
                set sentence $char
                set sentsz $ucharsz
            } else {
                # cut at last space
                set cut [string range $sentence 0 [expr {$lastspace - 1}]]
                if {![string is space $cut]} {
                    $callback "$prefix$cut"
                }
                set rest [string range $sentence [expr {$lastspace + 1}] end]
                set sentence [string cat $rest $char]
                set sentsz [string length [encoding convertto utf-8 $rest]]
                incr sentsz $ucharsz
            }
        }
    }
    if {$sentsz != 0} {
        if {![string is space $sentence]} {
            $callback "$prefix$sentence"
        }
    }
}

#} ;# end namespace PrivMsg

putlog "PrivMsg script by Nikopol loaded."

# vi: sw=4 ts=4 et
