package KG7OEM::MIDI::Operator;

use Moo;

use MIDI::ALSA(':CONSTS');
use Time::HiRes qw(time);
use Const::Fast;

use KG7OEM::MIDI::Runloop 'get_loop';
use KG7OEM::MIDI::Events;
use KG7OEM::MIDI::PTTInput;

const my $STATE_WAITING => 'waiting';
const my $STATE_READY => 'ready';

has current_state => (
    is => 'rwp',
    isa => \&_validate_current_state,
    default => $STATE_WAITING,
);

# control point PTT input event generator
has ptt_device => (
    is => 'lazy',
);

# FIXME Move the ptt_set_point into the PTTInput
# package, delegate out to that instance to get
# the value, and no longer set it in this
# package. The ptt_enable and ptt_disable events
# are still useful to send a state change message
# immediately while querying the PTTInput instance
# is used to send the periodic state messages.
#
# desired PTT state
has ptt_set_point => (
    is => 'rwp',
    default => 0,
);

sub _validate_current_state {
    my ($state_name) = @_;

    return if $state_name eq $STATE_WAITING;
    return if $state_name eq $STATE_READY;

    die "invalid state name: $state_name";
}

sub _build_ptt_device {
    my ($self) = @_;

    KG7OEM::MIDI::PTTInput->new(
        on_start => sub { $self->_handle_ptt_device_start },
        on_stop => sub { $self->_handle_ptt_device_stop },
        # FIXME make enable/disable event handlers immediately
        # send out a PTT state message to the radio side
        # and update the timer that sends the PTT state so the next
        # message is after the correct duration - the current PTT
        # input state comes from the PTTInput object
        #
        # TODO decide if the enable/disable handlers should check
        # the current PTT state stored in PTTInput and generate
        # a fault if there is a discrepency
        on_ptt_enable => sub { $self->_set_ptt_set_point(1) },
        on_ptt_disable => sub { $self->_set_ptt_set_point(0) },
    )->start;
}

sub run {
    my ($self) = @_;
    my $loop = get_loop();
    my $ptt_device = $self->ptt_device;

    $loop->add($ptt_device);

#    $loop->periodic_timer(interval => .1, on_tick => sub { $self->_send_updates });

    return $loop->run;
}

sub _handle_ptt_device_start {
    my ($self) = @_;
    my $previous_state = $self->current_state;

    if ($previous_state eq $STATE_READY) {
        die "got start event from PTT input while control point was ready";
    }

    $self->_set_current_state($STATE_READY);

    return;
}

sub _handle_ptt_device_stop {
    my ($self) = @_;

    # FIXME follow the same logic as the enable/disable event
    # handlers and send a message immediately and reset the
    # state transfer timer so the next message is after the
    # appropriate time
    $self->_set_ptt_set_point(0);

    return;
}

sub _send_updates {
    my ($self) = @_;

#    MIDI->sendevent('PTT', $self->ptt_set_point);
}

1;
