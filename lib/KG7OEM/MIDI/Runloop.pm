package KG7OEM::MIDI::Runloop;

# TODO
#
# change autostart to auto_start
#
# create auto_add which is like auto_start but for invoking add() to the
# runloop; allow auto_add to be controlled like auto_start

use Moo;

use Time::HiRes qw(alarm);
use IO::Async::Loop;
use IO::Async::Timer::Countdown;
use IO::Async::Timer::Periodic;
use IO::Async::Handle;
use IO::Handle;

# The instance of IO::Async::Loop that is in use
has _io => (
    is => 'lazy',
    handles => [qw(stop)],
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

sub _build_watchdog_timeout {
    return 1 / 20;
}

sub _build__watchdog_update {
    my ($self) = @_;
    return $self->watchdog_timeout / 2;
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

    # set up the first alarm right before the runloop
    # starts so the watchdog is not dependent on the
    # timer starting and invoking alarm() for the first
    # time
    if ($watchdog_timeout) {
        alarm($watchdog_timeout);
    }

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
    # FIXME this should call add() on the runloop automatically
    return IO::Async::Handle->new(%args);
}

sub alsa_midi {
    my ($self, %args) = @_;

    if (MIDI::ALSA::id() == 0) {
        die "ALSA MIDI is not yet initialized";
    }

    unless (exists $args{on_events}) {
        die "on_ready is a required argument";
    }

    unless (ref($args{on_events}) eq 'CODE') {
        die "on_ready must be a subref";
    }

    my $handle = $self->handle(
        read_handle => IO::Handle->new_from_fd(MIDI::ALSA::fd(), '<'),
        on_read_ready => sub { _handle_alsa_ready($args{on_events}, @_) },
    );

    $self->_io->add($handle);

    return $handle;
}

sub _handle_alsa_ready {
    my ($cb, $handle) = @_;
    my @events;

    # read all pending MIDI messages and provide the entire
    # list to the event handler
    while(MIDI::ALSA::inputpending()) {
        push(@events, [ MIDI::ALSA::input() ]);
    }

    $cb->(@events);

    return;
}

1;
