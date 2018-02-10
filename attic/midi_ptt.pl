#!/usr/bin/env perl

use strict;
use warnings;
use v5.10;

use MIDI::ALSA(':CONSTS');

main();

sub main {
    my $midi_device_name = shift(@ARGV);
    die "must specify a midi device name" unless defined $midi_device_name;

    logger("Initializing midi device $midi_device_name");
    init_alsa_midi($midi_device_name);

    while(1) {
        my ($type, $flags, $tag, $queue, $time, $source, $destination, $data) = MIDI::ALSA::input();

        # check for midi control events that contain the foot pedal position data
        if ($type == SND_SEQ_EVENT_CONTROLLER) {
            # 64 seems to be the sustain pedal
            next unless $data->[4] == 64;

            if ($data->[5] == 0) {
                ptt_disable();
            } else {
                ptt_enable();
            }
        # if the pedal is released really quickly (~20 ms) a note off event
        # comes instead of a new control event
        } elsif ($type == SND_SEQ_EVENT_NOTEOFF) {
            if ($data->[1] == 64) {
                ptt_disable();
            }
        } else {
            logger("Got stuff");
        }
    }
}

sub logger {
    say scalar(localtime) . ' ' . join(' ', @_);
}

sub init_alsa_midi {
    my ($device_name) = @_;

    die "could not init ALSA client" unless MIDI::ALSA::client('IC-7100', 1, 0, 1);
    die "could not connect to MIDI device: '$device_name'" unless MIDI::ALSA::connectfrom(0, $device_name, 0);

    return;
}

sub ptt_enable {
    logger("Begin transmitting");
    system('rig', 'T', '1');
}

sub ptt_disable {
    logger("Stop transmitting\n\n");
    system('rig', 'T', '0');
}
