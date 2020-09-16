use Modern::Perl;
package Epidermis::Lab::CLSI::LIS::LIS02A2::Record::MessageHeader;
# ABSTRACT: Message Header Record

use Moo;
use Epidermis::Lab::CLSI::LIS::LIS02A2::Meta::Record;
use Epidermis::Lab::CLSI::LIS::Types qw(Separator);
use Types::Standard        qw(Str StrMatch ArrayRef);
use List::AllUtils qw(uniq);
use Epidermis::Lab::CLSI::LIS::Constants qw(
	FIELD_SEP
	REPEAT_SEP
	COMPONENT_SEP
	ESCAPE_SEP
);

use failures qw( LIS02A2::Record::InvalidDelimiterSpec );

use MooX::Struct
	DelimiterSpec => [
		field_sep     => [ isa => Separator, default => sub { FIELD_SEP     } ],
		repeat_sep    => [ isa => Separator, default => sub { REPEAT_SEP    } ],
		component_sep => [ isa => Separator, default => sub { COMPONENT_SEP } ],
		escape_sep    => [ isa => Separator, default => sub { ESCAPE_SEP    } ],

		_check_valid_spec => sub {
			my ($self) = @_;
			failure::LIS02A2::Record::InvalidDelimiterSpec->throw(
				"Delimiter specification separators not unique"
			) unless @$self == uniq(@$self);
		},

		to_delimiter_definition => sub {
			my ($self) = @_;
			$self->_check_valid_spec;
			return join "", @$self, $self->field_sep;
		},

		coerce => sub {
			my ($class, $data) = @_;

			my $return;
			if( $class->TYPE_TINY->check($data) ) {
				$return = $data;
			} elsif( (StrMatch[qr/^\A....\z/])->check($data) ) {
				$return = $class->new([ split //, $data ]);
			} elsif( (StrMatch[qr/^\A(.)...\1\z/])->check($data) ) {
				$return = $class->new([ split //, substr($data, 0, 4) ]);
			} elsif( (ArrayRef[Separator,4,4])->check($data) ) {
				$return = $class->new($data);
			}
			if( $return && $return->_check_valid_spec ) {
				return $return;
			}
			failure::LIS02A2::Record::InvalidDelimiterSpec->throw(
				"Could not coerce data for delimiter definition"
			);

		},

		TO_STRING => sub {
			my ($self) = @_;
			$self->to_delimiter_definition;
		},
	];

record_type_id 'H';

field 'delimiter_definition', default => sub {
	DelimiterSpec->new;
}, isa => DelimiterSpec->TYPE_TINY|Str|ArrayRef, coerce => sub {
	DelimiterSpec->coerce($_[0]);
};

1;