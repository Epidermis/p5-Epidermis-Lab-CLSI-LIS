package Epidermis::Protocol::CLSI::LIS::LIS01A2::Session::Transition::Data;
# ABSTRACT: Data transitions

use Moo::Role;
use Future::AsyncAwait;

use Epidermis::Protocol::CLSI::LIS::LIS01A2::Session::MessageQueue;
use Epidermis::Protocol::CLSI::LIS::LIS01A2::Frame;

use Epidermis::Protocol::CLSI::LIS::Constants qw(
	STX
);
use Epidermis::Protocol::CLSI::LIS::Constants qw(LIS_DEBUG);
use Epidermis::Protocol::CLSI::LIS::LIS01A2::Session::Constants
	qw(:enum_device);

use boolean;

requires '_data_to_send_future';

requires '_message_queue';
requires '_frame_number';

requires '_read_control';

has _current_sendable_message => (
	is => 'rw',
	predicate => 1,
	clearer => 1,
);

has _current_receivable_message => (
	is => 'rw',
	predicate => 1,
	clearer => 1,
);

after _reset_after_step => sub {
	my ($self) = @_;
	$self->_update_data_to_send_future;
};

sub _update_data_to_send_future {
	my ($self) = @_;
	# Treat these two futures as producer-consumer semaphores.
	my $is_empty = $self->_message_queue_is_empty;
	$self->_data_to_send_future( Future->new ) if $self->_data_to_send_future->is_ready;
	$self->_message_queue_empty_future( Future->done( $is_empty ) );
}

has _process_frame_data_future => (
	is => 'rw',
	predicate => 1,
	clearer => 1,
);

sub _process_frame_data {
	my ($self) = @_;
	if( $self->_has_process_frame_data_future ) {
		return $self->_process_frame_data_future->without_cancel;
	}

	my $f = Future->done( eval {
			$self->_current_receivable_message->process_current_frame_data;
			{ is_good_frame => true };
		} or { is_good_frame => false, error => $@ })
		->set_label('process frame data');
	if( LIS_DEBUG && $self->_logger->is_trace) {
		$f = $f->then(sub {
			my ($result) = @_;
			$self->_logger->trace( "Processing frame data: "
				.  ( $result->{is_good_frame}
					? "Good frame"
					: "Bad frame; Error: $result->{error}" )
			);
			Future->done( $result )
		});
	}
	$self->_process_frame_data_future( $f );

	$f->without_cancel;
}

after _reset_after_step => sub {
	my ($self) = @_;
	if( $self->_has_process_frame_data_future
		&& $self->_process_frame_data_future->is_done ) {

		$self->_clear_process_frame_data_future;
	}
};

### ACTIONS

async sub do_send_frame {
	my ($self) = @_;
	await $self->_send_data(
		$self->_current_sendable_message->get_current_frame->frame_data
	);
}

async sub do_setup_next_frame {
	my ($self) = @_;

	my $create_new_sendable_message = 0;
	if( ! $self->_has_current_sendable_message ) {
		$create_new_sendable_message = 1;
	} elsif( ! $self->_current_sendable_message->has_next_frame ) {
		$create_new_sendable_message = 1;
		$self->_message_queue_dequeue->future->done;
	}

	if( $create_new_sendable_message ) {
		if( $self->_message_queue_size ) {
			$self->_logger->trace( 'Creating new sendable message' );
			$self->_current_sendable_message(
				$Epidermis::Protocol::CLSI::LIS::LIS01A2::Session::MessageQueue::SendableMessage->new(
					message_item => $self->_message_queue_peek,
					initial_fn => $self->_frame_number,
				)
			);
		} else {
			$self->_logger->trace( 'Message queue empty' );
			$self->_clear_current_sendable_message;
		}
	} else {
		$self->_current_sendable_message->next_frame;
	}
}

async sub do_setup_old_frame {
	true;
}

### EVENTS

async sub event_on_good_frame {
	my ($self) = @_;
	die unless (await $self->_process_frame_data)->{is_good_frame};
}

async sub event_on_bad_frame {
	my ($self) = @_;
	die if (await $self->_process_frame_data)->{is_good_frame};
}

async sub event_on_get_frame {
	my ($self) = @_;
	my $frame_data = await $self->_read_control;

	# Check this early to return from event early.
	die 'Invalid frame data: no STX' unless $frame_data =~ /\Q@{[ STX ]}\E/;

	if( ! $self->_has_current_receivable_message ) {
		$self->_current_receivable_message(
			$Epidermis::Protocol::CLSI::LIS::LIS01A2::Session::MessageQueue::ReceivableMessage->new(
					initial_fn => $self->_frame_number,
			)
		);
	}

	$self->_current_receivable_message->set_current_frame_data( $frame_data );
}

async sub event_on_has_data_to_send_sender {
	my ($self) = @_;
	die unless await $self->_data_to_send_future;
}

async sub event_on_has_data_to_send_receiver {
	my ($self) = @_;
	die if $self->_message_queue_is_empty;
}

async sub event_on_not_has_data_to_send_receiver {
	my ($self) = @_;
	die unless $self->_message_queue_is_empty;
}

async sub event_on_transfer_done {
	my ($self) = @_;
	die unless await $self->_message_queue_empty_future;
}

async sub event_on_not_transfer_done {
	my ($self) = @_;
	die if await $self->_message_queue_empty_future;
}

1;
