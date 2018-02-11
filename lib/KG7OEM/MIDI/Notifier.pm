package KG7OEM::MIDI::Notifier;

use strict;
use warnings;

use Package::Variant
    importing => [ 'Moo' ],
    subs => [ qw(has around before after with extends) ];

sub make_variant {
    my ($class, $target_package, @given_events) = @_;
    my @all_events = ('error', @given_events);

    extends 'IO::Async::Notifier';

    foreach my $event_name (@all_events) {
        has "on_$event_name" => ( is => 'rwp', predicate => 1 );
    }

    # the start() method returns $self for call chaining
    install start => sub { return $_[0] };

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
