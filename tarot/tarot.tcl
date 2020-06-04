# tarots.tcl v0.2.0
# by Nikopol
# created 20070821
# version 20200526
# ----------------
# Eggdrop script to draw some tarots cards.
#
# Normal usage:
# !tarot [number [<question asked>]]    (Max number of cards: 12)
#
# Special usage:
# Remove some cards off the deck and get answer privately.
# Deck auto resets after some time, or on command:
# !tarot [negative number]
# !tarot reset

namespace eval ::Tarots {
# CONFIGURATION:

# Channels we allow public use in (space seperated list)
variable allowed_chans {#astrology ##astrology #astrobot}

# Seconds between calls
variable thr 3

# Max time waiting before reseting deck (seconds)
variable decklife 600

# Binds
bind pub - !tarot  ::Tarots::handler
bind pub - !tarots ::Tarots::handler

# END CONFIG

variable lasttime 0

variable cards [list \
    "(I) The Magician" \
    "(II) The High Priestess" \
    "(III) The Empress" \
    "(IV) The Emperor" \
    "(V) The Hierophant" \
    "(VI) The Lovers" \
    "(VII) The Chariot" \
    "(VIII) The Hermit" \
    "(IX) Justice" \
    "(X) Wheel of Fortune" \
    "(XI) Strength" \
    "(XII) The Hanged Man" \
    "(XIII)" \
    "(XIV) Temperance" \
    "(XV) The Devil" \
    "(XVI) The Tower" \
    "(XVII) The Star" \
    "(XVIII) The Moon" \
    "(XIX) The Sun" \
    "(XX) Judgement" \
    "(XXI) The World" \
    "The Fool" \
]

variable decktime 0
variable curdeck $cards

proc handler { nick uhost hand chann txt } {
    variable allowed_chans
    variable thr
    variable lasttime

    # Check allowed channels
    if {[lsearch -exact $allowed_chans $chann] == -1} { return }

    # Check time
    set now [clock seconds]
    if {$now <= [expr {$lasttime + $thr}]} { return }
    set lasttime $now

    # Check number of cards
    set words [split [string tolower [string trim $txt]]]
    set numcards [list 1 2 3 4 5 6 7 8 9 10 11 12 \
        -1 -2 -3 -4 -5 -6 -7 -8 -9 -10 -11 -12]

    if {[llength $words] == 0} {
        set num 1
    } elseif {[lindex $words 0] == {reset}} {
        # reset deck
        variable cards
        variable decktime
        variable curdeck
        if {[llength $curdeck] != [llength $cards]} {
            puthelp "PRIVMSG $chann :deck is reset"
            set curdeck $cards
        } else {
            puthelp "PRIVMSG $chann :deck already is ready"
        }
        set decktime 0
        return
    } elseif {[lsearch $numcards [lindex $words 0]] != -1} {
        set num [expr {int([lindex $words 0])}]
    } else {
        # ignoring question :)
        set num 1
    }
    if {$num > 0} {
        drawOnce $nick $chann $num
    } else {
        drawMore $nick $chann $num
    }
}

proc drawOnce { nick chann num } {
    variable cards
    set msg "PRIVMSG $chann :cards for $nick: "
    expr srand([clock seconds])
    set copy $cards

    for {set x 0} {$x < $num} {incr x} {
        set ind [expr {int(rand()*([llength $copy] - 1))}]
        if {[expr {int(rand()*2)}]} {
            append msg [lindex $copy $ind]
        } else {
            # inversed
            append msg [string reverse [lindex $copy $ind]]
        }
        if {($x+1) != $num} { append msg {, } } else { break }
        set copy [lreplace $copy $ind $ind]
    }
    puthelp $msg
}

proc drawMore { nick chann num } {
    variable decklife
    variable cards
    variable decktime
    variable curdeck

    set now [clock seconds]
    if {[expr {$now - $decktime}] > $decklife || ![llength $curdeck]} {
        # reset deck
        set decktime 0
        set curdeck $cards
    }
    set decktime $now

    set msg "NOTICE $nick :hidden cards: "
    expr srand($now)
    set num [expr {abs($num)}]
    for {set x 0} {$x < $num} {incr x} {
        set ind [expr {int(rand()*([llength $curdeck] - 1))}]
        if {[expr {int(rand()*2)}]} {
            append msg [lindex $curdeck $ind]
        } else {
            # inversed
            append msg [string reverse [lindex $curdeck $ind]]
        }
        set curdeck [lreplace $curdeck $ind $ind]
        if {($x+1) != $num} { append msg {, } } else { break }
    }
    set m " ... [llength $curdeck] cards left"
    append msg $m
    puthelp $msg
    puthelp "PRIVMSG $chann :$m"
}

putlog {Loaded Tarots v0.2.0 script by Nikopol.}

} ;# end namespace

# vi: sw=4 ts=4 et
