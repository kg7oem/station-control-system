package KG7OEM::MIDI::ALSA;

use Moo;
use v5.10;

use Const::Fast;
use curry;
use IO::Handle;
use MIDI::ALSA(':CONSTS');

use KG7OEM::MIDI::ALSA::Notifier;
use KG7OEM::MIDI::Runloop 'get_loop';

const our $ALSA_PORT_PTT_INPUT => 0;
const our $ALSA_MIDI_SUSTAIN => 64;

const our $ALSA_MESSAGE_TYPE => 0;
const our $ALSA_MESSAGE_FLAGS => 1;
const our $ALSA_MESSAGE_TAG => 2;
const our $ALSA_MESSAGE_QUEUE => 3;
const our $ALSA_MESSAGE_TIME => 4;
const our $ALSA_MESSAGE_SOURCE => 5;
const our $ALSA_MESSAGE_DESTINATION => 6;
const our $ALSA_MESSAGE_DATA => 7;

const our $ALSA_SOURCE_CLIENT => 0;
const our $ALSA_SOURCE_PORT => 1;

const our $ALSA_DESTINATION_CLIENT => 0;
const our $ALSA_DESTINATION_PORT => 1;

use Exporter 'import';

our @EXPORT = qw(
    $ALSA_PORT_PTT_INPUT $ALSA_MIDI_SUSTAIN

    $ALSA_MESSAGE_TYPE $ALSA_MESSAGE_FLAGS $ALSA_MESSAGE_TAG
    $ALSA_MESSAGE_QUEUE $ALSA_MESSAGE_TIME $ALSA_MESSAGE_SOURCE
    $ALSA_MESSAGE_DESTINATION $ALSA_MESSAGE_DATA

    $ALSA_SOURCE_CLIENT $ALSA_SOURCE_PORT

    $ALSA_DESTINATION_CLIENT $ALSA_DESTINATION_PORT
);

has _alsa_notifier => (
    is => 'lazy',
);

sub _build__alsa_notifier {
    my ($self) = @_;

    if (MIDI::ALSA::id() == 0) {
        die "ALSA MIDI is not yet initialized";
    }

    my $notifier = get_loop->handle(
        read_handle => IO::Handle->new_from_fd(MIDI::ALSA::fd(), '<'),
        on_read_ready => $self->curry::_handle_read_ready,
    );

    return $notifier;
}

# the key is the ALSA input port number
# and the value is the notifier object
# that will do the event handler invocation
has _subscribers => (
    is => 'ro',
    default => sub { {} },
);

sub BUILD {
    my ($self) = @_;

    $self->_drain;

    $self->_alsa_notifier;

    return;
}

# empty the MIDI event queue of any outstanding
# messages
sub _drain {
    my ($self) = @_;

    MIDI::ALSA::input() while MIDI::ALSA::inputpending();
}

# generates a sequence of events that goes like this:
#
# * on_begin
# * on_message
# * on_message
# * on_message
# * on_end
#
# on_begin - the ALSA message queue is going to be read
# on_message - one event per each message in the ALSA queue
# on_end - the ALSA message queue is now empty
#
sub _handle_read_ready {
    my ($self) = @_;
    my $subscribers = $self->_subscribers;
    my %seen_ports;

    while(MIDI::ALSA::inputpending()) {
        my @envelope = MIDI::ALSA::input();
        my $port = $envelope[$ALSA_MESSAGE_DESTINATION][$ALSA_DESTINATION_PORT];
        my $type = $envelope[$ALSA_MESSAGE_TYPE];
        my $notifiers = $subscribers->{$port};

        next unless $notifiers;

        unless ($seen_ports{$port}) {
            $seen_ports{$port} = 1;
            $self->_deliver('on_begin', $notifiers, @envelope);
        }

        $self->_deliver('on_everything', $notifiers, @envelope);

        if ($type == SND_SEQ_EVENT_CLIENT_START) {
            $self->_deliver('on_client_start', $notifiers, @envelope);
        } elsif ($type == SND_SEQ_EVENT_CLIENT_EXIT) {
            $self->_deliver('on_client_exit', $notifiers, @envelope);
        } elsif ($type == SND_SEQ_EVENT_CLIENT_CHANGE) {
            $self->_deliver('on_client_change', $notifiers, @envelope);
        } elsif ($type == SND_SEQ_EVENT_PORT_START) {
            $self->_deliver('on_port_start', $notifiers, @envelope);
        } elsif ($type == SND_SEQ_EVENT_PORT_EXIT) {
            $self->_deliver('on_port_exit', $notifiers, @envelope);
        } elsif ($type == SND_SEQ_EVENT_PORT_CHANGE) {
            $self->_deliver('on_port_change', $notifiers, @envelope);
        } elsif ($type == SND_SEQ_EVENT_PORT_SUBSCRIBED) {
            $self->_deliver('on_port_subscribed', $notifiers, @envelope);
        } elsif ($type == SND_SEQ_EVENT_PORT_UNSUBSCRIBED) {
            $self->_deliver('on_port_unsubscribed', $notifiers, @envelope);
        } else {
            $self->_deliver('on_message', $notifiers, @envelope);
        }
    }

    foreach my $port (keys %seen_ports) {
        $self->_deliver('on_end', $subscribers->{$port});
    }

    return;
}

sub _deliver {
    my ($self, $name, $who, @args) = @_;
    $_->maybe_invoke_event($name, @args) foreach @$who;
}

sub subscribe {
    my ($self, $port, @args) = @_;
    my $notifier = KG7OEM::MIDI::ALSA::Notifier->new(@args);
    my $subscriber_list = $self->_subscribers;
    my $port_subscribers = $subscriber_list->{$port};

    die "port was not defined" unless defined $port;

    unless (defined $port_subscribers) {
        $port_subscribers = $subscriber_list->{$port} = [];
    }

    push(@$port_subscribers, $notifier);

    return $notifier;
}

1;