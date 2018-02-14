use strict;
use warnings;
use v5.10;

use KG7OEM::MIDI::PTTInput;
use KG7OEM::MIDI::Runloop 'get_loop';

MIDI::ALSA::client("a name", 1, 1, 1);
MIDI::ALSA::connectfrom(0, 'USB Midi', 0);

my $ptt = KG7OEM::MIDI::PTTInput->new(
    status => 'unready',
    on_status_change => sub { say "Got new status: '$_[1]' old status: '$_[2]'" },
    on_ptt_change => sub { say "Got PTT change: '$_[1]' old: '$_[2]'" },
);



get_loop->run;
