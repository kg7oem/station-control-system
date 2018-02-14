package KG7OEM::MIDI::PTTInput;

# fault conditions
# * MIDI SENSE messages are not coming in
# * ALSA disconnect events from the input device show up

use Moo;
use v5.10;

use curry;
use MIDI::ALSA(':CONSTS');

use KG7OEM::MIDI::Notifier;
use KG7OEM::MIDI::Runloop 'get_loop';
use KG7OEM::MIDI::ALSA;

extends Notifier(qw(status_change ptt_change));

has _alsa => (
    is => 'lazy',
);

# a string that is either 'unready', 'ready'
# or 'faulted'
has status => (
    is => 'rwp',
    default => 'unready',
    isa => \&_validate_status,
);

# true if transmit should be enabled
# false otherwise
has ptt => (
    is => 'rwp',
    default => 0,
);

# in floating point seconds
has sense_timeout => (
    is => 'ro',
    default => .3,
);

has _sense_timer => (
    is => 'lazy',
    clearer => '_clear__sense_timer',
);

# state of things when the 'begin' event comes in
# so when the 'end' event comes in changes can be
# detected and events generated as needed
has _begin_state => (
    is => 'rw',
);

sub _validate_status {
    my ($value) = @_;

    return if $value eq 'unready';
    return if $value eq 'ready';
    return if $value eq 'faulted';

    die "invalid status name: $value";
}

sub _build__alsa {
    my ($self) = @_;
    my $alsa = KG7OEM::MIDI::ALSA->new;
    my $notifier = $alsa->subscribe(
        0,
#        on_everything => sub { return if $_[1] == 42; say Dumper(\@_); use Data::Dumper; },
        on_begin => $self->curry::_handle_begin,
        on_end => $self->curry::_handle_end,
        on_port_unsubscribed => $self->curry::_handle_port_unsubscribed,
        on_message => $self->curry::_handle_message,
    );
}

sub _build__sense_timer {
    my ($self) = @_;

    return get_loop->countdown_timer(
        delay => $self->sense_timeout,
        on_expire => $self->curry::_handle_sense_timer_expire,
    );
}

sub BUILD {
    my ($self) = @_;

    $self->_alsa;

    # if sense_timeout is not set then the object is moved into
    # the ready status through invoking this sub to happen
    # inside the runloop after it starts
    unless ($self->sense_timeout) {
        get_loop->later(sub {
                # FIXME this has to fake a full message sequence
                # from the ALSA notifier to work right
                $self->_handle_begin;
                $self->_become_ready;
                $self->_handle_end;
        });
    }

    return;
}

sub _handle_begin {
    my ($self) = @_;
    $self->_begin_state({
        status => $self->status,
        ptt => $self->ptt,
    });
}

sub _handle_end {
    my ($self) = @_;
    my $begin = $self->_begin_state;

    # always send the PTT change event first so that the transmit
    # stop logic is handled before the fault handling logic
    if ($self->ptt != $begin->{ptt}) {
        $self->emit('ptt_change', $self->ptt, $begin->{ptt});
    }

    if ($self->status ne $begin->{status}) {
        $self->emit('status_change', $self->status, $begin->{status});
    }

    $self->_begin_state(undef);
}

sub _handle_port_unsubscribed {
    my ($self) = @_;
    $self->_become_faulted("MIDI port was unsubscribed");
}

sub _handle_message {
    my ($self, $notifier, @midi) = @_;
    my $type = $midi[$ALSA_MESSAGE_TYPE];
    my $data = $midi[$ALSA_MESSAGE_DATA];

    # MIDI devices might stop sending SENSE
    # messages if they send other data so
    # update the MIDI timeout when any
    # MIDI message comes in
    #
    # if sense_timeout is in use then the first message
    # that invokes _update_sense_timeout will cause the
    # object to move into the ready status
    $self->_update_sense_timeout if $self->sense_timeout;

    if ($type == SND_SEQ_EVENT_CONTROLLER) {
        if ($data->[4] == $ALSA_MIDI_SUSTAIN) {
            if ($data->[5]) {
                $self->_set_ptt(1);
            } else {
                $self->_set_ptt(0);
            }
        }
    } elsif ($type == SND_SEQ_EVENT_NOTEON && $data->[1] == $ALSA_MIDI_SUSTAIN) {
        $self->_set_ptt(1);
    } elsif ($type == SND_SEQ_EVENT_NOTEOFF && $data->[1] == $ALSA_MIDI_SUSTAIN) {
        $self->_set_ptt(0);
    }

    return;
}

sub _update_sense_timeout {
    my ($self, $notifier, @midi) = @_;
    my $status = $self->status;

    if ($status eq 'faulted') {
        die "got MIDI messages on a faulted PTT input device";
    } elsif ($status eq 'unready') {
        $self->_become_ready;
    } elsif ($status eq 'ready') {
        $self->_sense_timer->reset;
    }
}

sub _handle_sense_timer_expire {
    my ($self) = @_;
    $self->_become_faulted("MIDI SENSE timeout");
}

sub _become_ready {
    my ($self) = @_;
    my $status = $self->status;

    if ($status ne 'unready') {
        die "attempt to become ready when status was '$status'";
    }

    # force the MIDI SENSE timer to start
    # existing
    if ($self->sense_timeout) {
        $self->_sense_timer;
    }

    $self->_set_status('ready');

    return;
}

sub _become_faulted {
    my ($self) = @_;

    get_loop->remove($self->_sense_timer) if defined $self->_sense_timer;
    $self->_clear__sense_timer;

    $self->_set_ptt(0);
    $self->_set_status('faulted');

    return;
}

1;
