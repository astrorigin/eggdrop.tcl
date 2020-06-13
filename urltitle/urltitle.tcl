# urltitle.tcl v0.1.2
# by Nikopol
# inspired from teel
# created 20200526
#
# no channel flags, all the config stands here in script
# use wget and python, so less memory, more flexible, same job.
#
# requires packages: wget file python3-bs4 python3-lxml
#

namespace eval ::UrlTitle {

### CONFIGURATION

# list of channels to survey
variable chans {#astrology ##astrology #astrobot}

# user flags script will ignore input from
variable ignore {bdkqr|dkqr}

# minimum seconds to wait before another eggdrop use
variable delay 1

# url patterns to ignore (websites, file extensions..)
variable urlignore [list \
    #{://www\.youtube\.com} \
    #{://youtu\.be} \
    {\.7z$} \
    {\.bmp$} \
    {\.deb$} \
    {\.exe$} \
    {\.gif$} \
    {\.gz$} \
    {\.jpeg$} \
    {\.jpg$} \
    {\.pdf$} \
    {\.png$} \
    {\.rpm$} \
    {\.xz$} \
    {\.zip$} \
]

# path to python script
variable py /local/opt/eggdrop/myscripts/urltitle.py

# log stuff (1=yes, 0=no)
variable log 1

### END CONFIG

variable last 0

proc getTitle { url } {
    variable py
    variable log
    if {$log} {
        putlog "urltitle.tcl: trying $url"
    }
    if {[catch {exec $py $url 2>@1} output] != 0} {
        if {$log} {
            putlog "urltitle.tcl: $output"
        }
        return {}
    }
    return $output
}

proc handler { nick uhost hand chann txt } {
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
        # check length (http:// = 7, plus at least 4)
        if {[string length $word] < 11} {
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
        set title [string trim [getTitle $word]]
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
    variable log
    foreach url $urlignore {
        if {[regexp -nocase -lineanchor -- $url $word]} {
            if {$log} {
                putlog "urltitle.tcl: ignoring $word ($url)"
            }
            return 1
        }
    }
    return 0
}

# some initialization
set chans [string tolower [string trim $chans]]
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

putlog {Loaded UrlTitle v0.1.2 by Nikopol.}

} ;# end namespace

# vi: sw=4 ts=4 et
