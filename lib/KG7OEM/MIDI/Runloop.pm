package KG7OEM::MIDI::Runloop;

# TODO
#
# change autostart to auto_start
#
# create auto_add which is like auto_start but for invoking add() to the
# runloop; allow auto_add to be controlled like auto_start

use Moo;

use Sub::Exporter -setup => {
    exports => [qw( get_loop )],
};

use Time::HiRes qw(alarm);
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use IO::Async::Timer::Periodic;
use IO::Async::Handle;
use IO::Handle;

# the instance of this class that is used
# globally
our $SINGLETON;

# The instance of IO::Async::Loop that is in use
has _io => (
    is => 'lazy',
    handles => [qw(add later remove stop)],
);

# true if the runloop is currently or was prevously running
# false otherwise
has started => (
    is => 'rwp',
    default => 0,
);

# timeout in floating point seconds for the runloop watchdog or 0 to disable
# the watchdog
has watchdog_timeout => (
    is => 'lazy',
);

# how frequently the runloop watchdog should be reset in floating point
# seconds
has _watchdog_update => (
    is => 'lazy',
);

# the constructor returns the singleton runloop instance
# if it exists or initializes it otherwise
around new => sub {
    my ($orig, $self, @args) = @_;

    return $SINGLETON if defined $SINGLETON;
    return $SINGLETON = $self->$orig(@args);
};

sub BUILD {
    my ($self) = @_;
    # make IO::Async initialize during construction of this object
    # so any failures will show up early
    $self->_io;
}

sub _build__io {
    return IO::Async::Loop->new;
}

sub _build_watchdog_timeout {
    return 1 / 20;
}

sub _build__watchdog_update {
    my ($self) = @_;
    return $self->watchdog_timeout / 2;
}

# importable function for packages that want
# to use the runloop
sub get_loop {
    return $SINGLETON if defined $SINGLETON;
    # FIXME this won't subclass right
    return __PACKAGE__->new;
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
    my $update = $self->_watchdog_update;

    if (defined $SIG{ALRM}) {
        die "alarm handler was in use when setting up runloop watchdog";
    }

    $SIG{ALRM} = \&_alarm_handler;

    # periodically reset the runloop watchdog
    $self->periodic_timer(interval => $update, on_tick => sub { alarm($timeout) });
    # periodically ensure the watchdog alarm handler is set
    $self->periodic_timer(interval => 1, on_tick => sub { $self->_validate_alarm_handler });

    return;
}

sub run {
    my ($self) = @_;
    my $watchdog_timeout = $self->watchdog_timeout;

    if ($self->started) {
        die "attempt to start runloop twice";
    }

    if ($watchdog_timeout) {
        $self->_setup_watchdog;
        alarm($watchdog_timeout);
    }

    $self->_set_started(1);
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
    my $handle = IO::Async::Handle->new(%args);

    $self->add($handle);
    return $handle;
}

1;
