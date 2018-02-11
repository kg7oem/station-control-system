package KG7OEM::MIDI::Operator;

# TODO rename to ::ControlPoint

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

    $self->_set_ptt_set_point(0);

    return;
}

sub _send_updates {
    my ($self) = @_;

#    MIDI->sendevent('PTT', $self->ptt_set_point);
}

1;
