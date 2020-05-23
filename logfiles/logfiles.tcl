# logfiles.tcl
# by Nikopol
# created 20200518
# updated 20200523
# ------------------------------
# Desc: Check logfiles every N seconds, print new lines in channels
#
# Commands:
# .logfiles stop
# .logfiles start
# .logfiles restart - force stop/start

namespace eval ::LogFiles {

# CONFIGURATION:

# channels we want
variable chans "#xyz"

# check every X seconds
variable seconds 3

# path to logfiles
variable thefiles [list \
    "/path/to/logfile.txt" \
    ]

# save file path
# must be writable by eggdrop
# if not exists directory must also be writable
variable savefile "/path/to/save.cfg"

# commands (bot masters)
bind dcc m|- logfiles ::LogFiles::dccCommand

# initialize timer on startup/restart
bind evnt - init-server ::LogFiles::start
# start on rehash
bind evnt - rehash ::LogFiles::start
# save on rehash
bind evnt - prerehash ::LogFiles::onStop
# save on restart
bind evnt - prerestart ::LogFiles::onStop

# end CONFIG -- Dont modify below --

# timerid
variable nexttime {}
# modification times
variable mtime
array set mtime [list]
# file sizes
variable fsize
array set fsize [list]
# last position read in file
variable ftell
array set ftell [list]
# stop flag
variable dostop 0
# debug flag
variable debug 1

proc getData { fpath } {
    variable mtime
    variable fsize
    variable ftell
    variable debug
    if {![file exists $fpath]} {
        # cant find file
        putlog "logfiles.tcl: cant find file ($fpath)"
        return {}
    }
    if {![file readable $fpath]} {
        # cant read file
        putlog "logfiles.tcl: cant read file ($fpath)"
        return {}
    }
    set tm [file mtime $fpath]
    if {[catch {set mt $mtime($fpath)}] == 0 && $tm == $mt} {
        # file was not rewritten
        if {$debug} {
            putlog "logfiles.tcl: no writes in ($fpath)"
        }
        return {}
    }
    array set mtime [list $fpath $tm]
    set sz [file size $fpath]
    if {$sz == 0} {
        # empty file
        if {$debug} {
            putlog "logfiles.tcl: empty file ($fpath)"
        }
        array set fsize [list $fpath 0]
        array set ftell [list $fpath 0]
        return {}
    }
    if {[catch {set fsz $fsize($fpath)}] == 0} {
        if {$debug} {
            putlog "logfiles.tcl: checking sizes ($fpath)"
        }
        if {$sz < $fsz} {
            # assume file was rotated
            putlog "logfiles.tcl: rotation ($fpath)"
            array set ftell [list $fpath 0]
        } elseif {$sz == $fsz} {
            # file most likely has not changed...
            putlog "logfiles.tcl: same size, wont read ($fpath)"
            return {}
        } elseif {$debug} {
            putlog "logfiles.tcl: file grew ($fpath)"
        }
    }
    array set fsize [list $fpath $sz]
    # now go get new stuff
    if {[catch {set f [open $fpath]}] != 0} {
        # cant open file!?
        putlog "logfiles.tcl: cant open file ($fpath)"
        return {}
    }
    if {[catch {set ft $ftell($fpath)}] == 0} {
        if {[catch {seek $f $ft}] != 0} {
            # should not happen
            putlog "logfiles.tcl: something happened ($fpath)"
            array set ftell [list $fpath 0]
            seek $f 0
        }
    } else {
        array set ftell [list $fpath 0]
    }
    set data [split [read -nonewline $f] \n]
    set ft [tell $f]
    if {$ft > 0} {
        incr ft -1
    }
    array set ftell [list $fpath $ft]
    close $f
    return $data
}

proc stop {} {
    variable nexttime
    variable dostop
    if {$nexttime != {}} {
        catch {killutimer $nexttime}
        set nexttime {}
        set dostop 1
        LogFiles::toFile
    }
}

proc start { type } {
    LogFiles::fromFile
    LogFiles::setTimer
}

proc onStop { type } {
    LogFiles::stop
}

proc setTimer {} {
    variable nexttime
    variable seconds
    variable dostop
    catch {killutimer $nexttime}
    set nexttime [utimer $seconds ::LogFiles::tick]
    set dostop 0
}

# time has come to check for new stuff
proc tick {} {
    variable chans
    variable thefiles
    variable dostop
    putlog "logfiles.tcl: tick"
    foreach f $thefiles {
        set data [getData $f]
        if {$data == {}} {
            continue
        }
        foreach ch $chans {
            if {[catch {botonchan $ch} res] == 0 && $res == 1} {
                foreach line $data {
                    set line [string trim $line]
                    if {$line != {}} {
                        puthelp "PRIVMSG $ch :$line"
                    }
                }
            }
        }
    }
    if {!$dostop} {
        LogFiles::setTimer
    }
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
            putidx $idx {u wut m8?}
        }
    }
}

proc dccStart { hand idx } {
    variable nexttime
    if {$nexttime != {}} {
        putidx $idx {logfiles.tcl: already started}
        return
    }
    LogFiles::start -
    putidx $idx {logfiles.tcl: started}
}

proc dccStop { hand idx } {
    variable nexttime
    if {$nexttime == {}} {
        putidx $idx {logfiles.tcl: already stopped}
        return
    }
    LogFiles::stop
    putidx $idx {logfiles.tcl: stopped}
}

proc fromFile {} {
    variable mtime
    variable fsize
    variable ftell
    variable savefile
    variable debug
    if {$savefile == {}} {
        if {$debug} {
            putlog {logfiles.tcl: wont reload variables}
        }
        return
    }
    if {[catch {set f [open $savefile]} res] != 0} {
        putlog "logfiles.tcl: cant open ($savefile) ($res)"
        return
    }
    set data [read -nonewline $f]
    close $f
    array unset mtime
    array unset fsize
    array unset ftell
    foreach line [split $data \n] {
        set dt [split $line \0]
        set nam [lindex $dt 0]
        array set mtime [list $nam [lindex $dt 1]]
        array set fsize [list $nam [lindex $dt 2]]
        array set ftell [list $nam [lindex $dt 3]]
    }
    if {$debug} {
        putlog "logfiles.tcl: reloaded from ($savefile)"
    }
}

proc toFile {} {
    variable thefiles
    variable mtime
    variable fsize
    variable ftell
    variable savefile
    variable debug
    if {$savefile == {}} {
        if {$debug} {
            putlog {logfiles.tcl: wont save variables}
        }
        return
    }
    if {[catch {set f [open $savefile w]} res] != 0} {
        putlog "logfiles.tcl: cant write in ($savefile) ($res)"
        return
    }
    foreach nam $thefiles {
        set mt $mtime($nam)
        set fsz $fsize($nam)
        set ft $ftell($nam)
        puts $f "$nam\0$mt\0$fsz\0$ft"
    }
    close $f
    if {$debug} {
        putlog "logfiles.tcl: saved variables to file ($savefile)"
    }
}

putlog "Loaded LogFiles.tcl by Nikopol"

} ;# end namespace

# vi: sw=4 ts=4 et
