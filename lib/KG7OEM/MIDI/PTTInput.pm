package KG7OEM::MIDI::PTTInput;

# fault conditions
# * MIDI SENSE messages are not coming in
# * ALSA disconnect events from the input device show up

use Moo;

use KG7OEM::MIDI::Notifier;
use KG7OEM::MIDI::Runloop 'get_loop';
#use KG7OEM::MIDI::ALSA;

extends Notifier(qw(start stop ptt_enable ptt_disable));

has ptt_state => (
    is => 'rwp',
    default => 0,
);

before start => sub {
    my ($self) = @_;
#    my $alsa = KG7OEM::MIDI::ALSA->new;
#    my $input_port = 0;
#    # all messages
#    my $message_type = undef;
#
#    my $notifier = $alsa->subscribe(
#        $input_port,
#        on_begin => sub { },
#        on_message => sub { },
#        on_end => sub { },
#    );
#
#    $alsa->unsubscribe($notifier);
};

1;
