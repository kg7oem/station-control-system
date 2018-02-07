#!/usr/bin/env perl

use strict;
use warnings;

use KG7OEM::MIDI::PTT;

exit KG7OEM::MIDI::PTT->new->run;
