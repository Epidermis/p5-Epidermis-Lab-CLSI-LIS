package Epidermis::Protocol::CLSI::LIS::LIS01A2::Session::Transition::Data;
# ABSTRACT: Data transitions

use Moo::Role;
use Future::AsyncAwait;

use Epidermis::Protocol::CLSI::LIS::LIS01A2::Session::MessageQueue;

requires '_data_to_send_future';

requires '_message_queue';
requires '_frame_number';

has _current_sendable_message => (
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
	if( $self->_data_to_send_future ) {
		$self->_data_to_send_future->cancel;
	}
	if( $self->_message_queue_size ) {
		$self->_data_to_send_future( Future->done )
	} else {
		$self->_data_to_send_future( Future->new )
	}
}

### ACTIONS

async sub do_send_frame {
	# TODO
	...
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
			$self->_current_sendable_message(
				$Epidermis::Protocol::CLSI::LIS::LIS01A2::Session::MessageQueue::SendableMessage->new(
					message_item => $self->_message_queue_peek,
					initial_fn => $self->_frame_number,
				)
			);
		} else {
			$self->_clear_current_sendable_message;
		}
	} else {
		$self->_current_sendable_message->next_frame;
	}
}

async sub do_setup_old_frame {
	# TODO
	die;
}

### EVENTS

async sub event_on_good_frame {
	# TODO
	...
}

async sub event_on_get_frame {
	# TODO
	...
}

async sub event_on_has_data_to_send {
	my ($self) = @_;
	await $self->_data_to_send_future;
	die unless $self->_data_to_send_future->is_done;
}

async sub event_on_not_has_data_to_send {
	my ($self) = @_;
	await $self->_data_to_send_future;
	die if $self->_data_to_send_future->is_done;
}

async sub event_on_bad_frame {
	# TODO
}

1;
