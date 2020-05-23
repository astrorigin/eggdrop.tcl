# tarot.tcl
# by Nikopol
# created 20070821
# version 20200430
# ----------------
# Eggdrop script to draw some tarots cards.
#
# Usage:
# !tarot [number [<question asked>]]    (Max number of cards: 12)
#

namespace eval Tarots {
# CONFIGURATION:

# Channels we allow public use in (space seperated list)
variable allowed_chans "#astrology ##astrology #astrobot"

# Seconds between calls
variable throttle 30

# Binds
bind pub - >tarots Tarots::drawCards
bind pub - !tarots Tarots::drawCards

# END CONFIG

variable lastCall 0

proc drawCards {nick uhost hand chann txt} {
    variable allowed_chans
    variable throttle
    variable lastCall

    # Check allowed channels
    if {[lsearch -exact $allowed_chans $chann] == -1} { return }

    # Check time
    set now [clock seconds]
    set lmt [expr {$lastCall + $throttle}]
    if {$now <= $lmt} { return } else { set lastCall $now }

    # Check number of cards
    set words [split [string trim $txt]]
    set numcards [list \
        "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" \
    ]

    if {[llength $words] == 0} {
        set num 1
    } elseif {[lsearch $numcards [lindex $words 0]] != -1} {
        set num [expr int([lindex $words 0])]
    } else {
        # ignoring question :)
        set num 1
    }

    # Cards
    set cards [list \
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

    # response
    set msg "PRIVMSG $chann :Cards for $nick: "
    expr srand([clock seconds])

    for {set x 0} {$x < $num} {incr x} {
        set ind [expr int(rand()*([llength $cards] - 1))]
        append msg [lindex $cards $ind]
        if {($x+1) != $num} { append msg ", " } else { break }
        set cards [lreplace $cards $ind $ind]
    }

    puthelp $msg
}

putlog "Loaded Tarot script by Nikopol."
}

# vi: sw=4 ts=4 et
