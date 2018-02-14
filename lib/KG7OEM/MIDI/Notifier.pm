package KG7OEM::MIDI::Notifier;

use strict;
use warnings;
use v5.10;

use Package::Variant
    importing => [ 'Moo' ],
    subs => [ qw(has around before after with extends) ];

sub make_variant {
    my ($class, $target_package, @given_events) = @_;
    my @all_events = ('error', @given_events);
    my %event_names = map { my $n = "on_$_"; $n => 1 } @all_events;

    extends 'IO::Async::Notifier';

    foreach my $event_name (@all_events) {
        has "on_$event_name" => ( is => 'rwp', predicate => 1 );
    }

    # protect the new() method from attribute names passed
    # to the constructor
    install FOREIGNBUILDARGS => sub {
        my ($class, %args) = @_;

        foreach my $arg_name (keys %args) {
            delete $args{$arg_name} unless exists $event_names{$arg_name};
        }

        return %args;
    };

    # the start() method returns $self for call chaining
    install start => sub { return $_[0] };

    # the standard IO::Async can_event() method tries
    # to invoke setter methods if this behavior is not
    # changed
    install can_event => sub {
        my $self = shift;
        my ( $event_name ) = @_;

        return $self->{$event_name};
    };

    install emit => sub {
        my ($self, $name, @args) = @_;
        die "name was not specified" unless defined $name;
        $self->maybe_invoke_event("on_$name", @args);
    };

    around configure => sub {
        my ($orig, $self, %args) = @_;

        foreach my $event_name (@all_events) {
            my $handler_name = "on_$event_name";
            my $setter_name = "_set_$handler_name";
            my $handler_ref = $args{$handler_name};

            $self->$setter_name($handler_ref) if exists $args{$handler_name};
            # pass the error handler on through to IO::Async::Notifier
            delete $args{$handler_name} unless $event_name eq 'error';
        }

        return $self->$orig(%args);
    };
}

1;
