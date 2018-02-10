package KG7OEM::MIDI::PTT;

use v5.10;
use Moo;

use Getopt::Long;
use MIDI::ALSA(':CONSTS');

use KG7OEM::MIDI::Operator;

has client_name => (
    is => 'ro',
    # TODO support specifying client name via command line
    # or configuration file
    builder => sub { 'MIDI PTT DEV' },
);

has _args => (
    is => 'rwp',
);

sub run {
    my ($self) = @_;
    my $args = $self->_set__args($self->_parse_cli);

    if ($args->{list}) {
        return $self->_mode_list_midi_devices;
    } elsif ($args->{operator}) {
        # operator mode runs at the remote control station
        return $self->_mode_operator;
    } elsif ($args->{radio}) {
        die "radio mode is not implemented";
        #return $self->_mode_radio;
    }

    # If we make it here it is an unhandled case and something
    # has gone wrong
    die "should never get here";
}

sub _parse_cli {
    my %args;

    GetOptions(
        'list|l' => \$args{list},
        'operator|o' => \$args{operator},
        'pedal|p=s' => \$args{pedal},
    ) or die "Could not parse command line\n";

    # TODO perform validation here

    return \%args;
}

sub _init_midi {
    my ($self, $in_ports, $out_ports) = @_;

    die "in_ports was not specified" unless defined $in_ports;
    die "out_ports was not specified" unless defined $out_ports;

    # TODO validate that the client_name meets the criteria specified
    # by the MIDI::ALSA documentation:
    #
    # For full ALSA functionality, the $name should contain only letters,
    # digits, underscores or spaces, and should contain at least one letter.

    # the last argument enables the usage of the time stamped
    # event queue
    unless (MIDI::ALSA::client($self->client_name, $in_ports, $out_ports, 1)) {
        # FIXME how do you get the error string out of MIDI::ALSA?
        die "Could not create ALSA MIDI client";
    }

    MIDI::ALSA::start();

    return;
}

sub _mode_list_midi_devices {
    my ($self) = @_;

    $self->_init_midi(0, 0);

    my %clients = MIDI::ALSA::listclients();
    my $my_client_num = MIDI::ALSA::id();

    say "Port Client";

    foreach my $client_num (sort { $a <=> $b } keys %clients) {
        next if $client_num == $my_client_num;
        printf("% 4d %s\n", $client_num, $clients{$client_num});
    }

    return 0;
}

sub _mode_operator {
    my ($self) = @_;
    my $pedal_device = $self->_args->{pedal};

    die "pedal_device was not defined" unless defined $pedal_device;

    $self->_init_midi(1, 1);

    unless (MIDI::ALSA::connectfrom(0, $pedal_device, 0)) {
       die "Could not connect to pedal device: '$pedal_device'";
    }

    return KG7OEM::MIDI::Operator->new->run;
}

1;
