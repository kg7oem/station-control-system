package KG7OEM::MIDI::Operator;

# TODO is it better to call this side of the remote operation
# system the control point?

use Moo;

use KG7OEM::MIDI::Runloop;

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

    return $loop->run;
}

sub _state_offline {
    my ($self) = @_;
}

1;
