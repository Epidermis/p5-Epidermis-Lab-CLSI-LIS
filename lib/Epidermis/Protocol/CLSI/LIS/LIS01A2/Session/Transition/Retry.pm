package Epidermis::Protocol::CLSI::LIS::LIS01A2::Session::Transition::Retry;
# ABSTRACT: Retry transitions

use Moo::Role;
use MooX::Should;
use Future::AsyncAwait;

use Epidermis::Protocol::CLSI::LIS::Constants qw(LIS01A2_MAX_RETRIES);

use Types::Common::Numeric qw(PositiveOrZeroInt);

has max_retries => (
	is => 'ro',
	should => PositiveOrZeroInt,
	default => sub { LIS01A2_MAX_RETRIES },
);

has _retries => (
	is => 'rw',
	should => PositiveOrZeroInt,
	default => sub { 0 },
);

sub do_reset_retry_count {
	my ($self) = @_;
	$self->_retries(0);
}

sub do_increment_retry_count {
	my ($self) = @_;
	$self->_retries( $self->_retries + 1 );
}

async sub event_on_can_retry {
	my ($self) = @_;
	$self->_retries < $self->max_retries;
}

async sub event_on_no_can_retry {
	my ($self) = @_;
	! $self->event_on_no_can_retry;
}

1;