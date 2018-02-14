package KG7OEM::MIDI::ALSA::Notifier;

use Moo;

use KG7OEM::MIDI::Notifier;

extends Notifier(qw(
    begin end everything
    client_start client_exit client_change
    port_start port_exit port_change
    port_subscribed port_unsubscribed
    message
));


1;
