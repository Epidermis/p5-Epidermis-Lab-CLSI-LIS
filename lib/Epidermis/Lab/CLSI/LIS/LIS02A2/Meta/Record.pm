use Modern::Perl;
package Epidermis::Lab::CLSI::LIS::LIS02A2::Meta::Record;
# ABSTRACT: Metaclass helpers for defining records

use Import::Into;
use Moo::_Utils qw(_install_tracked);

use MooX::ClassAttribute ();
use Scalar::Util qw(blessed);

use Epidermis::Lab::CLSI::LIS::Types qw(RecordType);

our %RECORD_FIELD_STORE;

sub import {
	my $caller = caller;

	Moo::Role->apply_roles_to_package( $caller, __PACKAGE__ );

	MooX::ClassAttribute->import::into($caller);

	my $has = $caller->can( "has" ) or die "Moo not loaded in caller: $caller";

	my $add_field = sub {
		my ($target, $name) = @_;
		push @{ $RECORD_FIELD_STORE{ $target } }, $name;
	};

	_install_tracked $caller => field => sub {
		my ($name, @args) = @_;

		$add_field->($caller, $name);
		$has->(
			$name,
			is => 'ro',
			@args,
		);
	};

	my $class_has  = $caller->can( "class_has" );

	_install_tracked $caller => record_type_id => sub {
		my ($record_char) = @_;
		my $name = 'type_id';

		$add_field->($caller, $name);
		$class_has->(
			$name,
			is => 'ro',
			isa => RecordType,
			default => sub { $record_char },
		);
	};
}

use Moo::Role;

sub _fields {
	my $package = blessed $_[0] ? ref $_[0] : $_[0];
	return exists $RECORD_FIELD_STORE{$package} ? @{ $RECORD_FIELD_STORE{$package} } : ();
}

1;