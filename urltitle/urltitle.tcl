# urltitle.tcl v0.1.0
# by Nikopol
# inspired from teel
# created 20200526
#
# no more channel flags, all the config stands here in script
# use wget and python, less memory, more flexible, same job, just better.
#
# requires packages: wget python3-bs4 python3-lxml
#

namespace eval ::UrlTitle {

### CONFIGURATION

# list of channels to survey
variable chans {#lamers #xyz}

# user flags script will ignore input from
variable ignore {bdkqr|dkqr}

# minimum seconds to wait before another eggdrop use
variable delay 1

# url patterns to ignore
variable urlignore [list \
    #{://www\.youtube\.com} \
    #{://youtu\.be} \
]

# path to python script
variable py /local/opt/eggdrop/myscripts/urltitle.py

# log urls printed to channels (1=yes, 0=no)
variable log 1

### END CONFIG

variable last 0

proc getTitle { url } {
    variable py
    set title [exec $py $url 2>@1]
    return $title
}

proc handler {nick uhost hand chann txt} {
    variable chans
    variable delay
    variable last
    variable ignore
    variable log

    # check chan (a second time)
    if {[lsearch -exact $chans $chann] == -1} {
        return
    }
    # check user
    if {[matchattr $hand $ignore]} {
        return
    }
    # check time
    set now [clock seconds]
    if {[expr {$now - $last}] <= $delay} {
        return
    }
    # loop over words
    foreach word [split $txt] {
        # check length (http:// = 7)
        if {[string length $word] < 7} {
            continue
        }
        # check http(s)
        if {![regexp {^http(s|)://} $word]} {
            continue
        }
        # check url to ignore
        if {[urlIsIgnored $word]} {
            return
        }
        # url grab starts
        set last $now
        set title [getTitle $word]
        if {[string length $title]} {
            puthelp "PRIVMSG $chann :\037Title:\037 $title"
            if {$log} {
                putlog "urltitle.tcl: $nick $uhost $hand $chann $word"
            }
        }
        return
    }
}

proc urlIsIgnored { word } {
    variable urlignore
    foreach url $urlignore {
        if {[regexp $url $word]} {
            return 1
        }
    }
    return 0
}

# some initialization
set chans [string tolower $chans]
# unbind everything
foreach b [binds pubm] {
    if {[lindex $b 4] == {::UrlTitle::handler}} {
        unbind pubm -|- [lindex $b 2] ::UrlTitle::handler
    }
}
# bind each channel
foreach chann $chans {
    bind pubm -|- "$chann *://*" ::UrlTitle::handler
}

putlog {Loaded UrlTitle v0.1.0 by Nikopol.}

} ;# end namespace

# vi: sw=4 ts=4 et
