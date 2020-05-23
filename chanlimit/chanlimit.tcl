# chanlimit.tcl v2.0.2
# by Nikopol
# created 20200503
# updated 20200523
#
# This script maintains a user limit in channels your bot is in. It is used
# primarily to help discourage large flood attacks.
#
# Some features in this script that you won't find in some other limiter
# scripts include the ability to select the channels in which to activate
# the limiting function, and a 'grace' to reduce the number of unnecessary
# mode changes (i.e. if the limit doesn't need to be changed by more than
# the grace number, it doesn't bother setting the new limit).
#
# DCC commands
# ------------
# For channel masters:
# .chanlimit check [<#chan> ...]: check limits
# .chanlimit stop [<#chan> ...]: stop limiting
# .chanlimit start [<#chan>> ...]: restart limiting on specific channels
# .chanlimit set <#chan> [<limit> [<grace> [<period>]]]: to configure a channel
# .chanlimit unset <#chan> [<#chan> ...]: to deactivate/remove channels
# .chanlimit help: show commands
# For bot masters:
# .chanlimit exclude <#chan> [<#chan> ...]: to exclude channels
# .chanlimit unexclude <#chan> [<#chan> ...]: to remove a channel off the exclude list
# .chanlimit setdefaults <limit> <grace> <period>: set defaults values
# .chanlimit status: show current channels and values
# .chanlimit timers: show running timers
# For bot owners:
# .chanlimit save: save paramaters to file
#
# Credits
# -------
# Initially based on chanlimit.tcl v1.5 (1 April 1999) by slennox
# (That script was inspired by UserLimiter v0.32 by ^Fluffy^)
#
# License
# -------
# MIT License
#
# chanlimit.tcl - eggdrop script
#
# Copyright (c) 2020 Nikopol <stan@astrorigin.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

namespace eval ::ChanLimit {

### CONFIGURATION

# Channels in which to activate limiting.
#
# This is a list like "#elephants #wildlife #etc".
#
# Set to "" (empty string) if you wish to activate limiting on all
# channels the bot is on. (If the list is non-empty, channels not in this
# list will not be limited.)
#
# Optionaly, the limit, grace and period values for a particular channel
# can also be set here, glued to the name with commas like so
# (name,limit,grace,period): "#spoilers,7,3,15 #xyz,4,2,20 #etc"
#
variable activechans ""

# Channels in which _not_ to activate limiting.
#
# This list is evaluated before the above 'activechans' list, and takes
# precedence over it.
#
# Set to "" (empty string) if you wish to activate limiting on all
# channels the bot is on.
#
variable notchans "#lamers #moo"

# Limit to set (number of users on the channel + this setting).
#
# This is the default value for channels not configured in the above
# 'activechans' list.
#
variable limit 5

# Limit grace (if the limit doesn't need to be changed by more than this,
# don't bother setting a new limit).
#
# This is the default value for channels not configured in the above
# 'activechans' list.
#
variable grace 2

# Frequency of checking whether a new limit needs to be set (in minutes).
#
# This is the default value for channels not configured in the above
# 'activechans' list.
#
variable period 10

# Wether to log limit changes (1=yes, 0=no).
#
variable debug 1

# Enable more debug info (1=yes, 0=no)
#
variable traceme 0

# File path of this script, used when saving variables to file.
#
# The script will overwrite itself when saving. It will also create a backup
# before. So make sure that the file and directory is writable by eggdrop.
# Path should be something similar to "scripts/chanlimit.tcl".
#
# Leave empty ("") to disable saving config to file.
#
variable scriptpath ""

### END CONFIGURATION -- dont modify below

variable timerids

# get list of names in activechans
proc activeChannels {} {
    variable activechans
    set chans ""
    foreach ch [split $activechans] {
        if {$ch != ""} {
            lappend chans [lindex [split $ch ","] 0]
        }
    }
    return $chans
}

# check user input channel name
proc isValidChanName { nam } {
    if {[string length $nam] < 2} {
        return 0
    }
    if {[lsearch -exact "# &" [string index $nam 0]] == -1} {
        return 0
    }
    if {[string first "," $nam] != -1} {
        return 0
    }
    if {[string first "\"" $nam] != -1} {
        return 0
    }
    return 1
}

# check user input limit
proc checkParamLimit { p } {
    return [expr {[set p [expr {int($p)}]] < 1 ? 1 : $p}]
}

# check user input grace
proc checkParamGrace { p } {
    return [expr {abs(int($p))}]
}

# check user input period
proc checkParamPeriod { p } {
    return [expr {[set p [expr {int($p)}]] < 1 ? 1 : $p}]
}

# get list of params for a channel
proc channelParams { chann } {
    variable activechans
    variable limit
    variable grace
    variable period
    set params "$limit $grace $period"
    foreach ch [split $activechans] {
        if {$ch == ""} {
            continue
        }
        set p [split $ch ","]
        if {[lindex $p 0] == $chann} {
            switch [llength $p] {
                1 {
                    break
                }
                2 {
                    lreplace $params 0 0 [checkParamLimit [lindex $p 1]]
                }
                3 {
                    lreplace $params 0 1 [checkParamLimit [lindex $p 1]] \
                                         [checkParamGrace [lindex $p 2]]
                }
                default {
                    lreplace $params 0 2 [checkParamLimit [lindex $p 1]] \
                                         [checkParamGrace [lindex $p 2]] \
                                         [checkParamPeriod [lindex $p 3]]
                }
            }
            break
        }
    }
    return $params
}

# get limit value from a channel modes string
proc currentLimit { modes } {
    if {[string match *l* [lindex $modes 0]]} {
        set start [expr {[string last " " $modes] + 1}]
        return [expr {[string range $modes $start end]}]
    } else {
        return 0
    }
}

# check limit in a channel
proc checkLimit { chann lmt grc {prd ""} } {
    variable debug
    tracer "checking limit in $chann,$lmt,$grc,$prd"
    set numusers [llength [chanlist $chann]]
    set newlimit [expr {$numusers + $lmt}]
    set currlimit [currentLimit [getchanmode $chann]]
    if {$newlimit == $currlimit} {
        return
    } elseif {$newlimit > $currlimit} {
        set delta [expr {$newlimit - $currlimit}]
    } elseif {$currlimit > $newlimit} {
        set delta [expr {$currlimit - $newlimit}]
    }
    if {$delta <= $grc} {
        return
    }
    # set limit
    pushmode $chann "+l" "$newlimit"
    flushmode $chann
    if {$debug} {
        putlog "chanlimit.tcl: mode $chann +l $newlimit"
    }
}

# check bot is +o in a channel
proc botIsOp { chann } {
    if {[catch {botisop $chann} res] == 0 && $res == 1} {
        return 1
    }
    return 0
}

# timer checks limit of a channel
proc timeout { chann } {
    variable timerids
    tracer "timeout $chann"
    if {[botIsOp $chann]} {
        set p [channelParams $chann]
        checkLimit $chann [lindex $p 0] [lindex $p 1]
        # reset timer
        array unset timerids $chann
        startTimer $chann [lindex $p 2]
    } else {
        # not an op, stop limiting
        array unset timerids $chann
    }
}

# check user is global or channel master
proc isChanMaster { hand ch } {
    if {[catch {lsearch -exact [userlist +m|m $ch] $hand} res] != 0} {
        return 0
    }
    if {$res != -1} {
        return 1
    }
    return 0
}

# check user is bot master
proc isMaster { hand } {
    if {[lsearch -exact [userlist +m] $hand] != -1} {
        return 1
    }
    return 0
}

# check user is bot owner
proc isOwner { hand } {
    if {[lsearch -exact [userlist +n] $hand] != -1} {
        return 1
    }
    return 0
}

# apply a function to each channel able to be limited by bot
# callback takes at least 4 args: channel, limit, grace, period
proc checkList { callback } {
    variable activechans
    variable notchans
    if {$activechans != ""} {
        set chans [activeChannels]
    }
    foreach ch [string tolower [channels]] {
        if {$notchans != "" && [lsearch -exact $notchans $ch] != -1} {
            continue
        }
        if {$activechans != "" && [lsearch -exact $chans $ch] == -1} {
            continue
        }
        if {![botisop $ch]} {
            continue
        }
        set p [channelParams $ch]
        {*}$callback $ch [lindex $p 0] [lindex $p 1] [lindex $p 2]
    }
}

# make list with no empty elements
proc makeArgs { lst } {
    set args ""
    foreach word $lst {
        if {$word != ""} {
            lappend args $word
        }
    }
    return $args
}

# process dcc commands
proc dccCommand { hand idx arg } {
    set words [split [string tolower [string trim $arg]]]
    switch [lindex $words 0] {
        check {
            dccCheck $hand $idx [makeArgs [lrange $words 1 end]]
        }
        stop {
            dccStop $hand $idx [makeArgs [lrange $words 1 end]]
        }
        start {
            dccStart $hand $idx [makeArgs [lrange $words 1 end]]
        }
        set {
            dccSet $hand $idx [makeArgs [lrange $words 1 end]]
        }
        unset {
            dccUnset $hand $idx [makeArgs [lrange $words 1 end]]
        }
        exclude {
            dccExclude $hand $idx [makeArgs [lrange $words 1 end]]
        }
        unexclude {
            dccUnexclude $hand $idx [makeArgs [lrange $words 1 end]]
        }
        status {
            dccStatus $hand $idx
        }
        timers {
            dccTimers $hand $idx
        }
        save {
            dccSave $hand $idx
        }
        help {
            dccHelp $hand $idx
        }
        default {
            putidx $idx {u wut m8? (see .chanlimit help)}
        }
    }
}

# get list of chans where bot is +o, from given list
proc botIsOpChans { chans idx } {
    set lst ""
    foreach ch $chans {
        if {![botIsOp $ch]} {
            putidx $idx "unable to limit in $ch"
        } else {
            lappend lst $ch
        }
    }
    return $lst
}

proc cbCheckIfMaster { hand idx chann lmt grc prd } {
    if {[isChanMaster $hand $chann]} {
        putidx $idx "checking limit in $chann"
        checkLimit $chann $lmt $grc
    } else {
        tracer "not +m in $chann"
    }
}

proc cbCheckIfMasterIn { hand idx chans chann lmt grc prd } {
    if {[lsearch -exact $chans $chann] != -1} {
        if {[isChanMaster $hand $chann]} {
            putidx $idx "checking limit in $chann"
            checkLimit $chann $lmt $grc
        } else {
            putidx $idx "not a master in $chann"
        }
    }
}

proc dccCheck { hand idx chans } {
    if {[llength $chans] == 0} {
        checkList "cbCheckIfMaster $hand $idx"
    } else {
        set chans [botIsOpChans $chans $idx]
        if {[llength $chans] != 0} {
            checkList "cbCheckIfMasterIn $hand $idx $chans"
        }
    }
}

proc cbStopIfMaster { hand idx chann lmt grc prd } {
    variable timerids
    if {[isChanMaster $hand $chann]} {
        if {[array names timerids -exact $chann] != ""} {
            stopTimer $chann
            putidx $idx "stopped limiting in $chann"
        } else {
            putidx $idx "already not limiting in $chann"
        }
    } else {
        tracer "not +m in $chann"
    }
}

proc cbStopIfMasterIn { hand idx chans chann lmt grc prd } {
    variable timerids
    if {[lsearch -exact $chans $chann] != -1} {
        if {[isChanMaster $hand $chann]} {
            if {[array names timerids -exact $chann] != ""} {
                stopTimer $chann
                putidx $idx "stopped limiting in $chann"
            } else {
                putidx $idx "already not limiting in $chann"
            }
        } else {
            putidx $idx "not a master in $chann"
        }
    }
}

proc dccStop { hand idx chans } {
    if {[llength $chans] == 0} {
        checkList "cbStopIfMaster $hand $idx"
    } else {
        set chans [botIsOpChans $chans $idx]
        if {[llength $chans] != 0} {
            checkList "cbStopIfMasterIn $hand $idx $chans"
        }
    }
}

proc cbStartIfMaster { hand idx chann lmt grc prd } {
    variable timerids
    if {[isChanMaster $hand $chann]} {
        if {[array names timerids -exact $chann] == ""} {
            startTimer $chann $prd
            putidx $idx "started limiting in $chann"
        } else {
            putidx $idx "already limiting in $chann"
        }
    } else {
        tracer "not +m in $chann"
    }
}

proc cbStartIfMasterIn { hand idx chans chann lmt grc prd } {
    variable timerids
    if {[lsearch -exact $chans $chann] != -1} {
        if {[isChanMaster $hand $chann]} {
            if {[array names timerids -exact $chann] == ""} {
                startTimer $chann $prd
                putidx $idx "started limiting in $chann"
            } else {
                putidx $idx "already limiting in $chann"
            }
        } else {
            putidx $idx "not master in $chann"
        }
    }
}

proc dccStart { hand idx chans } {
    if {[llength $chans] == 0} {
        checkList "cbStartIfMaster $hand $idx"
    } else {
        set chans [botIsOpChans $chans $idx]
        if {[llength $chans] != 0} {
            checkList "cbStartIfMasterIn $hand $idx $chans"
        }
    }
}

proc dccSet { hand idx params } {
    variable activechans
    variable limit
    variable grace
    variable period
    if {[llength $params] == 0} {
        putidx $idx "missing channel name"
        return
    }
    set ch [lindex $params 0]
    if {![isValidChanName $ch]} {
        putidx $idx "invalid channel name ($ch)"
        return
    }
    if {![isChanMaster $hand $ch]} {
        putidx $idx "not master in $ch"
        return
    }
    set lim [lindex $params 1]
    if {$lim == ""} {
        set lim $limit
    } elseif {[catch {set lim [checkParamLimit $lim]} res] != 0} {
        putidx $idx "invalid limit ($lim)"
        return
    }
    set grc [lindex $params 2]
    if {$grc == ""} {
        set grc $grace
    } elseif {[catch {set grc [checkParamGrace $grc]} res] != 0} {
        putidx $idx "invalid grace ($grc)"
        return
    }
    set prd [lindex $params 3]
    if {$prd == ""} {
        set prd $period
    } elseif {[catch {set prd [checkParamPeriod $prd]} res] != 0} {
        putidx $idx "invalid period ($prd)"
        return
    }
    set achans ""
    set done 0
    foreach chann $activechans {
        if {$ch == [lindex [split $chann ","] 0]} {
            lappend achans "$ch,$lim,$grc,$prd"
            set done 1
        } else {
            lappend achans $chann
        }
    }
    if {!$done} {
        lappend achans "$ch,$lim,$grc,$prd"
    }
    set activechans $achans
    # restart timer
    #if {[array names timerids -exact $ch] != ""} {
    #    stopTimer $ch
    #    startTimer $ch $prd
    #    putidx $idx "restarted limiting in $p"
    #} else {
    #    startTimer $ch $prd
    #    putidx $idx "started limiting in $p"
    #}
    putidx $idx "set: $ch limit=$lim grace=$grc period=$prd"
    putlog "chanlimit.tcl: $hand set: $ch limit=$lim grace=$grc period=$prd"
}

proc dccUnset { hand idx params } {
    variable activechans
    if {[llength $params] == 0} {
        putidx $idx "missing channel name"
        return
    }
    foreach p $params {
        if {![isValidChanName $p]} {
            putidx $idx "invalid channel name ($p)"
            return
        }
    }
    foreach p $params {
        if {![isChanMaster $hand $p]} {
            putidx $idx "not master in $p"
            return
        }
    }
    set achans ""
    set parms $params
    foreach chann $activechans {
        set ch [lindex [split $chann ","] 0]
        set i [lsearch -exact $parms $ch]
        if {$i == -1} {
            lappend achans $chann
        } else {
            set parms [lreplace $parms $i $i]
            putidx $idx "unset: $ch"
        }
    }
    if {[llength $parms]} {
        putidx $idx [concat "already unset:" [join $parms]]
    }
    set activechans $achans
    putlog [concat "chanlimit.tcl: $hand unset:" [join $params]]
}

proc dccExclude { hand idx params } {
    variable notchans
    variable timerids
    if {[llength $params] == 0} {
        putidx $idx "missing channel name"
        return
    }
    foreach p $params {
        if {![isValidChanName $p]} {
            putidx $idx "invalid channel name ($p)"
            return
        }
    }
    if {![isMaster $hand]} {
        putidx $idx "not bot master"
        return
    }
    set nchans ""
    set parms $params
    foreach ch $notchans {
        set i [lsearch -exact $parms $ch]
        if {$i != -1} {
            putidx $idx "already excluded: $ch"
            set parms [lreplace $parms $i $i]
        }
        lappend nchans $ch
    }
    if {[llength $parms]} {
        # stop timers immediately
        foreach p $parms {
            if {[array names timerids -exact $p] != ""} {
                stopTimer $p
                putidx $idx "stopped limiting in $p"
            }
        }
        putidx $idx [concat "excluded:" [join $parms]]
        set nchans [concat $nchans $parms]
    }
    set notchans $nchans
    putlog [concat "chanlimit.tcl: $hand excluded:" [join $params]]
}

proc dccUnexclude { hand idx params } {
    variable notchans
    if {[llength $params] == 0} {
        putidx $idx "missing channel name"
        return
    }
    foreach p $params {
        if {![isValidChanName $p]} {
            putidx $idx "invalid channel name ($p)"
            return
        }
    }
    if {![isMaster $hand]} {
        putidx $idx "not bot master"
        return
    }
    set nchans ""
    set parms $params
    foreach ch $notchans {
        set i [lsearch -exact $parms $ch]
        if {$i == -1} {
            lappend nchans $ch
        } else {
            set parms [lreplace $parms $i $i]
            putidx $idx "unexcluded: $ch"
        }
    }
    if {[llength $parms]} {
        putidx $idx [concat "already unexcluded:" [join $parms]]
    }
    set notchans $nchans
    putlog [concat "chanlimit.tcl: $hand unexcluded:" [join $params]]
}

proc dccSetDefaults { hand idx params } {
    variable limit
    variable grace
    variable period
    if {[llength $params] == 0} {
        putidx $idx "missing arguments"
        return
    }
    if {![isMaster $hand]} {
        putidx $idx "not bot master"
        return
    }
    set lim [lindex $params 0]
    if {$lim == ""} {
        set lim $limit
    } elseif {[catch {set lim [checkParamLimit $lim]} res] != 0} {
        putidx $idx "invalid limit ($lim)"
        return
    }
    set grc [lindex $params 1]
    if {$grc == ""} {
        set grc $grace
    } elseif {[catch {set grc [checkParamGrace $grc]} res] != 0} {
        putidx $idx "invalid grace ($grc)"
        return
    }
    set prd [lindex $params 2]
    if {$prd == ""} {
        set prd $period
    } elseif {[catch {set grc [checkParamPeriod $prd]} res] != 0} {
        putidx $idx "invalid period ($prd)"
        return
    }
    set limit $lim
    set grace $grc
    set period $prd
    putidx $idx "defaults set to: limit=$lim grace=$grc period=$prd"
    putlog "chanlimit.tcl: $hand set defaults to: limit=$lim grace=$grc period=$prd"
}

proc dccStatus { hand idx } {
    variable activechans
    variable notchans
    variable limit
    variable grace
    variable period
    if {![isMaster $hand]} {
        putidx $idx "not bot master"
        return
    }
    putidx $idx [concat "active channels:" [join $activechans]]
    putidx $idx [concat "excluded channels:" [join $notchans]]
    putidx $idx "defaults: limit=$limit grace=$grace period=$period"
}

proc dccTimers { hand idx } {
    if {![isMaster $hand]} {
        putidx $idx "not bot master"
        return
    }
    set chans ""
    foreach tmr [timers] {
        set cb [lindex $tmr 1]
        if {[lindex $cb 0] == "::ChanLimit::timeout"} {
            lappend chans [list [lindex $cb 1] [lindex $tmr 0]]
        }
    }
    foreach ch $chans {
        putidx $idx [concat "" [lindex $ch 0] ":" [lindex $ch 1] "min. left"]
    }
}

proc hasSed {} {
    set out [exec {which} {sed} 2>@1]
    if {$out == ""} {
        return 0
    }
    if {[string first "/" $out] != 0} {
        return 0
    }
    return 1
}

proc execCmd { c idx } {
    tracer [join $c]
    set out [exec [lindex $c 0] [lindex $c 1] [lindex $c 2] [lindex $c 3] 2>@1]
    if {$out != ""} {
        putidx $idx "error: $c"
        putidx $idx $out
        putlog "chanlimit.tcl: error: $c"
        putlog "chanlimit.tcl: $out"
        return 0
    }
    return 1
}

proc dccSave { hand idx } {
    variable activechans
    variable notchans
    variable limit
    variable grace
    variable period
    variable scriptpath
    if {![isOwner $hand]} {
        putidx $idx "not owner of the bot"
        return
    }
    if {$scriptpath == ""} {
        putidx $idx "script path not set"
        return
    }
    if {![hasSed]} {
        putidx $idx "cant find command 'sed'"
        return
    }
    if {![file writable $scriptpath]} {
        putidx $idx "cant write in '$scriptpath'"
        return
    }
    set ext [clock format [clock seconds] -format "%Y%m%d%H%M%S"]
    if {[catch {file copy $scriptpath "$scriptpath.$ext"} res] != 0} {
        putidx $idx "cant backup '$scriptpath': $res"
        return
    } else {
        putidx $idx "saved backup '$scriptpath.$ext' to disk"
    }
    set achans [join $activechans]
    set nchans [join $notchans]
    set cmds [list \
        [list {sed} {-iE} "0,/^ *variable +activechans +\"/ s/^ *variable +activechans +\".*\"/variable activechans \"$achans\"/" $scriptpath] \
        [list {sed} {-iE} "0,/^ *variable +notchans +\"/ s/^ *variable +notchans \".*\"/variable notchans \"$nchans\"/" $scriptpath] \
        [list {sed} {-iE} "0,/^ *variable +limit +/ s/^ *variable +limit +\[\[:digit:]]+/variable limit $limit/" $scriptpath] \
        [list {sed} {-iE} "0,/^ *variable +grace +/ s/^ *variable +grace +\[\[:digit:]]+/variable grace $grace/" $scriptpath] \
        [list {sed} {-iE} "0,/^ *variable +period +/ s/^ *variable +period +\[\[:digit:]]+/variable period $period/" $scriptpath] \
    ]
    foreach cmd $cmds {
        if {![execCmd $cmd $idx]} {
            return
        }
    }
    putidx $idx "saved script '$scriptpath' to disk"
    putlog "chanlimit.tcl: $hand saved script '$scriptpath' to disk"
}

proc dccHelp { hand idx } {
    set helptxt [list \
        {channel masters:} \
        { .chanlimit check [<channel> ...]} \
        { .chanlimit stop [<channel> ...]} \
        { .chanlimit start [<channel> ...]} \
        { .chanlimit set <channel> [<limit> [<grace> [<period>]]]} \
        { .chanlimit unset <channel> [<channel> ...]} \
        {bot masters:} \
        { .chanlimit status} \
        { .chanlimit timers} \
        { .chanlimit exclude <channel> [<channel> ...]} \
        { .chanlimit unexclude <channel> [<channel> ...]} \
        { .chanlimit setdefaults <limit> <grace> <period>} \
        {bot owners:} \
        { .chanlimit save} \
    ]
    foreach txt $helptxt {
        putidx $idx $txt
    }
}

# stop all running timers
proc stopAllTimers {} {
    variable timerids
    if {[array size timerids] != 0} {
        foreach {ch id} [array get timerids] {
            tracer "killing timer $ch (id: $id)"
            killtimer $id
        }
        array unset timerids
    }
}

proc cbStartAllTimers { chann lmt grc prd } {
    startTimer $chann $prd
}

# start all possible timers. expecting no timers already exist
proc startAllTimers {} {
    variable timerids
    if {[array size timerids] == 0} {
        checkList cbStartAllTimers
    } else {
        # should not happen
        error "chanlimit.tcl: ERROR: limiting already started"
    }
}

proc onJoin { nik uhost hand chann } {
    global botnick
    variable activechans
    variable notchans
    variable timerids
    if {$nik != $botnick} {
        return
    }
    if {[lsearch -exact $notchans $chann] != -1} {
        return
    }
    if {$activechans == "" || [lsearch -exact [activeChannels] $chann] != -1} {
        if {[array names timerids -exact $chann] == ""} {
            set prd [lindex [channelParams $chann] 2]
            startTimer $chann $prd
        }
    }
}

proc onPart { nik uhost hand chann txt } {
    global botnick
    variable timerids
    if {$nik != $botnick} {
        return
    }
    if {[array names timerids -exact $chann] != ""} {
        stopTimer $chann
    }
}

proc bindJoinPart {} {
    global nick
    global altnick
    foreach nik [list $nick $altnick] {
        bind join - "* $nik!*" ::ChanLimit::onJoin
        bind part - "* $nik!*" ::ChanLimit::onPart
    }
}

proc unbindJoinPart {} {
    foreach b [binds join] {
        if {[lindex $b 4] == "::ChanLimit::onJoin"} {
            unbind join - [lindex $b 2] ::ChanLimit::onJoin
        }
    }
    foreach b [binds part] {
        if {[lindex $b 4] == "::ChanLimit::onPart"} {
            unbind part - [lindex $b 2] ::ChanLimit::onPart
        }
    }
}

# called when (re)sourced
proc sourced {} {
    stopAllTimers
    startAllTimers
    unbindJoinPart
    bindJoinPart
}

# just set a timer
proc startTimer { chann prd } {
    variable timerids
    if {[array names timerids -exact $chann] != ""} {
        # should not happen
        error "chanlimit.tcl: ERROR: already limiting on $chann"
    }
    set id [timer $prd "::ChanLimit::timeout $chann"]
    tracer "set timer for $chann ($prd min.) (id: $id)"
    array set timerids "$chann $id"
}

# just stop a timer
proc stopTimer { chann } {
    variable timerids
    if {[array names timerids -exact $chann] == ""} {
        # should not happen
        error "chanlimit.tcl: ERROR: already not limiting in $chann"
    }
    set id [lindex [array get timerids $chann] 1]
    tracer "killing timer $chann (id: $id)"
    killtimer $id
    array unset timerids $chann
}

proc debugTimers {} {
    variable timerids
    foreach {ch id} [array get timerids] {
        putlog "$ch ($id)"
    }
    putlog "----------"
    foreach tmr [timers] {
        putlog $tmr
    }
}

proc tracer { txt } {
    variable traceme
    if {$traceme} {
        putlog "TRACE: $txt"
    }
}

# some initialization
set activechans [string tolower [string trim $activechans]]
set notchans [string tolower [string trim $notchans]]
set limit [checkParamLimit $limit]
set grace [checkParamGrace $grace]
set period [checkParamPeriod $period]

sourced

bind dcc m|m chanlimit ::ChanLimit::dccCommand

putlog "Loaded chanlimit.tcl v2.0.0 by Nikopol"
if {$activechans == ""} {
    putlog "\\_ active on: *"
} else {
    putlog [concat "\\_ active on:" [join [activeChannels]]]
}
if {$notchans != ""} {
    putlog [concat "\\_ inactive on:" [join $notchans]]
}

} ;# end namespace ChanLimit

# vi: set sw=4 ts=4 et
