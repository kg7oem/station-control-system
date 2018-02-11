package KG7OEM::MIDI::Operator;

# TODO rename to ::ControlPoint

use Moo;

use MIDI::ALSA(':CONSTS');
use Time::HiRes qw(time);

use KG7OEM::MIDI::Runloop;
use KG7OEM::MIDI::Events;

# the operator interface is offline if SENSE has failed (if in use)
# or the radio side of this pair is not providing feedback
#
# The states and transitions are
# offline -> sense ok -> radio ok -> online
# offline -> radio ok -> online (when SENSE is not being used)
# online -> sense ok (when the radio side has failed but sense is ok)
# online -> offline (when the radio side has failed and there is no sense)
#
# when exiting the online state transmit needs to be disabled

# true if the system is currently online or false otherwise
has online => (
    is => 'rwp',
    default => 0,
);

# true if MIDI SENSE indicates a device is connected
# false if no SENSE is detected
# undef if SENSE is not being used
has sense_ok => (
    is => 'rwp',
    default => undef,
);

# the maximum time between MIDI SENSE messages before
# a failure is declared or 0 to disable the SENSE watchdog
has sense_timeout => (
    is => 'ro',
    default => .3,
);

has radio_ok => (
    is => 'rwp',
    default => 0,
);

# the current desired PTT state - true if
# transmitting should be happening
has transmit_enable => (
    is => 'rwp',
    default => 0,
);

has _sense_watchdog_timer => (
    is => 'rwp',
);

sub run {
    my ($self) = @_;
    my $midi_sense_timeout = $self->sense_timeout;
    my $loop = KG7OEM::MIDI::Runloop->new;

    # FIXME the pending MIDI events should be drained and ignored
    # as part of initialization in case anything is hanging around
    # in the buffer that is ancient history
    $loop->alsa_midi(on_events => sub { $self->_handle_midi(@_) });

    return $loop->run;
}

sub _handle_midi {
    my ($self, @events) = @_;

    foreach my $event (@events) {
        my $type = $event->[0];

        if ($type == SND_SEQ_EVENT_SENSING) {
            $self->_handle_midi_sense(@$event);
        } else {
            my $type_name = KG7OEM::MIDI::Events->get_name($type);
            print "Got unknown MIDI message: $type_name\n";
        }
    }

    return;
}

sub _handle_midi_sense {
    my ($self, @data) = @_;

    print scalar(time), " Got MIDI SENSE\n";
}

1;
