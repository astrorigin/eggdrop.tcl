# Reddit.tcl v0.1.1
# by Nikopol
# created 20200515
# ------------------------------
# Desc: Get latest posts from Reddit
#
# Required packages: python3-praw (sudo pip3 install --upgrade praw)
#
# Say you want to get the latest posts of r/Lamers. You must create a txt
# file for each subreddit. So, for example, you do:
#
# touch RedditLamers.txt # create a txt file
# chmod a+w RedditLamers.txt # make it writable by eggdrop
#
# Then edit the python file accordingly for each subreddit...
# And load the latest posts by executing the python script once:
#
# ./Reddit.py # like that
#
# Commands:
# .reddit stop
# .reddit start
# .reddit restart - force stop/start

namespace eval ::Reddit {

# CONFIGURATION:

# channels we want
variable chans {#astrobot}

# check every X minutes
variable minutes 4

# log stuff
variable log 1

# path to python script
variable py {/home/eggdrop/eggdrop/myscripts/Reddit/Reddit.py}

# end CONFIG -- Dont modify below --

variable nexttime {}

proc getData {} {
    variable py
    if {[catch {exec $py 2>@1} res] != 0} {
        return {}
    }
    return [split [string trim $res] \n]
}

proc stop {} {
    variable nexttime
    if {$nexttime != {}} {
        catch {unbind time -|- $nexttime ::Reddit::tick}
    }
    set nexttime {}
}

proc setTimer {type} {
    variable nexttime
    variable minutes
    Reddit::stop
    set sec [clock seconds]
    set nxt [expr {$sec + 60 * $minutes}]
    set nexttime [split [clock format $nxt -format {%M %H %d %m %Y}]]
    set mo [lindex $nexttime 3]
    scan $mo %d mo
    set mo [format {%02d} [expr {$mo - 1}]]
    set nexttime [join [lreplace $nexttime 3 3 $mo]]
    bind time -|- $nexttime ::Reddit::tick
}

# Time has come to check for new posts
proc tick {minutes hour day month year} {
    variable chans
    variable py
    variable log
    if {$log} {
        putlog "Reddit.tcl: tick"
    }
    set data [getData]
    if {$data == {}} {
        setTimer -
        return
    }
    set allchans [channels]
    foreach dt $data {
        #set dt [string trim $dt]
        #if {$dt == {}} {
        #    continue
        #}
        foreach ch $chans {
            if {[lsearch -exact $allchans $ch] != -1} {
                ::PrivMsg $ch $dt
            }
        }
    }
    setTimer -
}

proc dccCommand { hand idx txt } {
    set txt [split [string tolower [string trim $txt]]]
    switch [lindex $txt 0] {
        start {
            dccStart $hand $idx
        }
        stop {
            dccStop $hand $idx
        }
        restart {
            dccStop $hand $idx
            dccStart $hand $idx
        }
        default {
            putidx $idx {reddit.tcl: u wut m8?}
        }
    }
}

proc dccStart { hand idx } {
    variable nexttime
    if {$nexttime != {}} {
        putidx $idx "reddit.tcl: already started ($nexttime)"
        return
    }
    setTimer -
    putidx $idx "reddit.tcl: started ($nexttime)"
}

proc dccStop { hand idx } {
    variable nexttime
    if {$nexttime == {}} {
        putidx $idx "reddit.tcl: already stopped"
        return
    }
    Reddit::stop
    putidx $idx "reddit.tcl: stopped"
}

# initialize timer
bind evnt - init-server ::Reddit::setTimer

# commands
bind dcc m|- reddit ::Reddit::dccCommand

putlog {Loaded Reddit.tcl v0.1.1 by Nikopol}

} ;# end namespace

# vi: sw=4 ts=4 et
