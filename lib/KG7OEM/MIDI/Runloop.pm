package KG7OEM::MIDI::Runloop;

use Moo;

use Time::HiRes qw(alarm);
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use IO::Async::Timer::Periodic;
use IO::Async::Handle;

has _io => (
    is => 'ro',
    builder => 1,
    handles => [qw(stop)],
);

# timeout in floating point seconds for the runloop watchdog or 0 to disable
# the watchdog
has watchdog_timeout => (
    is => 'ro',
    default => 1 / 20,
);

sub BUILD {
    my ($self) = @_;
    # make IO::Async initialize during construction of this object
    # so any failures will show up early
    $self->_io;

    if ($self->watchdog_timeout) {
        $self->_setup_watchdog;
    }
}

sub _build__io {
    return IO::Async::Loop->new;
}

# FIXME there is some rather complex handling that should be
# implemented to gracefully handle the situation where the run
# loop isn't responsive
sub _alarm_handler {
    die "Hit watchdog timeout for runloop";
}

# FIXME this should be handled the same as a failed watchdog
sub _validate_alarm_handler {
    my ($self) = @_;
    die "watchdog alarm handler was not installed" unless $SIG{ALRM} eq \&_alarm_handler;
}

sub _setup_watchdog {
    my ($self) = @_;
    my $timeout = $self->watchdog_timeout;

    if (defined $SIG{ALRM}) {
        die "alarm handler was in use when setting up runloop watchdog";
    }

    $SIG{ALRM} = \&_alarm_handler;

    # periodically reset the runloop watchdog
    $self->periodic_timer(interval => $timeout * .9, on_tick => sub { alarm($timeout) });
    # periodically ensure the watchdog alarm handler is set
    $self->periodic_timer(interval => 1, on_tick => sub { $self->_validate_alarm_handler });

    return;
}

sub run {
    my ($self) = @_;
    my $watchdog_timeout = $self->watchdog_timeout;

    return $self->_io->run;
}

sub _new_timer {
    my ($self, $class, %args) = @_;
    my $autostart = 1;

    if (exists $args{autostart}) {
        $autostart = delete $args{autostart};
    }

    my $new_timer = $class->new(%args);
    $self->_io->add($new_timer);

    $new_timer->start if $autostart;

    return $new_timer;
}

sub countdown_timer {
    my ($self, %args) = @_;
    return $self->_new_timer('IO::Async::Timer::Countdown', %args);
}

sub periodic_timer {
    my ($self, %args) = @_;
    return $self->_new_timer('IO::Async::Timer::Periodic', %args);
}

sub handle {
    my ($self, %args) = @_;
    return IO::Async::Handle->new(%args);
}

1;
