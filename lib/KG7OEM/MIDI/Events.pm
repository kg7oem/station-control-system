package KG7OEM::MIDI::Events;

use Moo;

use Data::Section::Simple qw(get_data_section);

our $SINGLETON;

has _name_map => (
    is => 'lazy',
);

sub _build__name_map {
    my %by_number;

    foreach my $line (split("\n", get_data_section()->{events})) {
        next if $line =~ m/^\s*$/;
        chomp($line);

        $line =~ s/^\s+//;
        my ($num, $name) = split(/\s+/, $line);
        next unless defined $name;

        $name =~ s/^SND_SEQ_EVENT_//;

        $by_number{$num} = $name;
    }

    return \%by_number;
}

sub get_name {
    my ($package, $num) = @_;

    die "num was not defined" unless defined $num;

    $SINGLETON = $package->new unless defined $SINGLETON;

    return $SINGLETON->_name_map->{$num};
}

1;

__DATA__

# This is taken from the MIDI::ALSA
# CPAN module documentation

@@ events
  0     SND_SEQ_EVENT_SYSTEM
  1     SND_SEQ_EVENT_RESULT
 
  5     SND_SEQ_EVENT_NOTE
  6     SND_SEQ_EVENT_NOTEON
  7     SND_SEQ_EVENT_NOTEOFF
  8     SND_SEQ_EVENT_KEYPRESS
 
 10     SND_SEQ_EVENT_CONTROLLER
 11     SND_SEQ_EVENT_PGMCHANGE
 12     SND_SEQ_EVENT_CHANPRESS
 13     SND_SEQ_EVENT_PITCHBEND
 14     SND_SEQ_EVENT_CONTROL14
 15     SND_SEQ_EVENT_NONREGPARAM
 16     SND_SEQ_EVENT_REGPARAM
 
 20     SND_SEQ_EVENT_SONGPOS
 21     SND_SEQ_EVENT_SONGSEL
 22     SND_SEQ_EVENT_QFRAME
 23     SND_SEQ_EVENT_TIMESIGN
 24     SND_SEQ_EVENT_KEYSIGN
 
 30     SND_SEQ_EVENT_START
 31     SND_SEQ_EVENT_CONTINUE
 32     SND_SEQ_EVENT_STOP
 33     SND_SEQ_EVENT_SETPOS_TICK
 34     SND_SEQ_EVENT_SETPOS_TIME
 35     SND_SEQ_EVENT_TEMPO
 36     SND_SEQ_EVENT_CLOCK
 37     SND_SEQ_EVENT_TICK
 38     SND_SEQ_EVENT_QUEUE_SKEW
 39     SND_SEQ_EVENT_SYNC_POS
   
 40     SND_SEQ_EVENT_TUNE_REQUEST
 41     SND_SEQ_EVENT_RESET
 42     SND_SEQ_EVENT_SENSING
   
 50     SND_SEQ_EVENT_ECHO
 51     SND_SEQ_EVENT_OSS
  
 60     SND_SEQ_EVENT_CLIENT_START
 61     SND_SEQ_EVENT_CLIENT_EXIT
 62     SND_SEQ_EVENT_CLIENT_CHANGE
 63     SND_SEQ_EVENT_PORT_START
 64     SND_SEQ_EVENT_PORT_EXIT
 65     SND_SEQ_EVENT_PORT_CHANGE
 66     SND_SEQ_EVENT_PORT_SUBSCRIBED
 67     SND_SEQ_EVENT_PORT_UNSUBSCRIBED
  
 90     SND_SEQ_EVENT_USR0
 91     SND_SEQ_EVENT_USR1
 92     SND_SEQ_EVENT_USR2
 93     SND_SEQ_EVENT_USR3
 94     SND_SEQ_EVENT_USR4
 95     SND_SEQ_EVENT_USR5
 96     SND_SEQ_EVENT_USR6
 97     SND_SEQ_EVENT_USR7
 98     SND_SEQ_EVENT_USR8
 99     SND_SEQ_EVENT_USR9
 
130     SND_SEQ_EVENT_SYSEX
131     SND_SEQ_EVENT_BOUNCE
135     SND_SEQ_EVENT_USR_VAR0
136     SND_SEQ_EVENT_USR_VAR1
137     SND_SEQ_EVENT_USR_VAR2
138     SND_SEQ_EVENT_USR_VAR3
139     SND_SEQ_EVENT_USR_VAR4
   
255     SND_SEQ_EVENT_NONE