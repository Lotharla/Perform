package Manage::dollar;

use strict;
use warnings;
use Scalar::Util qw(looks_like_number);
use Tie::IxHash;
use Tk;
use Tk::Balloon;
use Tk::DialogBox;
use Tk::NoteBook;
use feature qw(say switch);

use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0);

use Manage::utils qw(dump _getenv _value_or_else _tkinit _set_selection _replace_text _ask_file _ask_directory);

use Exporter::Easy (
	OK => [ qw(
		$mw
		@given
		%dollars
		handle_given
		hasDollar
		isDollar
		dollar_amount
		make_Dollar
		detect_dollar
		get_dollars
		set_dollars
		place_given
		what_is_dollar
	)],
);

our $mw;
our @given = _getenv('given');
my $append_given = 1;

sub handle_given {
	my $output = shift;
	if ($given[0] and $append_given ) {
		return &combine( $output, $given[0] );
	}
	$output
}

our %dollars;
BEGIN {
	tie %dollars, 'Tie::IxHash';
}

our $dollar = qr/\$(\d+)|\$\{(\w+)\}/;

sub hasDollar {
	return shift(@_) =~ $dollar
}

sub isDollar {
	return shift(@_) =~ m[^$dollar$]
}

sub dollar_amount {
	$_[0] =~ /$dollar/;
	$1 ? $1 : $2
}

sub make_Dollar {
	my $what = shift;
	return "\$" . sprintf(looks_like_number($what) ? '%d' : '{%s}', $what);
}

sub detect_dollar {
	my $input = shift;
	my $picker = shift;
	my $output = '';
	my $temp = $input;
	if ($temp) {
		my $n = -1;
		while ($temp =~ /$dollar/) {
#dump \@-, \@+;
			my $p = $+[0];
			my $l = $p - $-[0];
			$output .= substr $temp, 0, $p - $l;
			my $x = substr($temp, $p - $l, $l);
			my $part = $_[++$n] ? $_[$n] : $picker->($x);
			return $input if !defined($part);
			$output .= $part;
			$temp = substr $temp, $p;
		}
		$output .= $temp;
	}
	return $output
}

sub get_dollars {
	%dollars = ();
	detect_dollar (shift, sub {
		$dollars{$_[0]} = dollar_amount(@_);
	});
	%dollars
}

sub set_dollars {
	return detect_dollar (shift, sub {
		$dollars{$_[0]}
	});
}

sub place_given {
	my $input = shift;
	return $input if !$append_given;
	get_dollars($input);
#dump \%dollars;
	foreach my $doll (keys %dollars) {
		my $d = $dollars{$doll};
		if (looks_like_number($d) && $d < scalar(@given) + 1 && $d > -1) {
			$dollars{$doll} = $given[$d - 1];
		} else {
			$dollars{$doll} = make_Dollar($d);
		}
	}
#dump \%dollars;
	set_dollars($input)
}

sub what_is_dollar {
	my $input = shift;
	my $types = shift;
	my $output = '';
	my @results = @_;
	if (@results) {
		$output = detect_dollar ($input, sub {
			shift(@results)
		});
		return $output;
	}
	%dollars = get_dollars($input);
	my $dlg = $mw->DialogBox(
				-title => $input,
				-buttons => ['OK', 'Cancel'],
				-default_button => 'Cancel');
	my $book = $dlg->NoteBook()->pack( -fill=>'both', -expand=>1 );
	for my $key (keys %dollars) {
		my $en;
		my $tab = $book->add( $dollars{$key}, -label=>$key, -raisecmd=>sub{_set_selection($en)} );
		$en = $tab->Entry(
			-width => 50,
			-textvariable => \$dollars{$key})->grid(-row => 0, -column => 0, -columnspan => 4);
		my $choice = 'f';
		my $btn = $tab->Button( 
			-text=>'Given document', 
			-state => ($given[0] ? 'normal' : 'disabled'),
			-command=> sub { 
				_replace_text($en, $given[0]);
			} )->grid(-row => 1, -column => 0);
		if ($given[0]) {
			my $ba = $mw->Balloon(-background=>'yellow');
			$ba->attach($btn,-initwait => 0,-balloonmsg => "$given[0]");
		}
		$tab->Button( 
			-text=>'Browse...', 
			-command=> sub { 
				my $answer = $choice eq 'f' ?
					_ask_file($mw, 'Choose file', -f $dollars{$key} ? $dollars{$key} : '', $types) :
					_ask_directory($mw, 'Choose directory', -d $dollars{$key} ? $dollars{$key} : ''); 
				_replace_text($en, $answer) if $answer;
			} )->grid(-row => 1, -column => 1);
		$tab->Radiobutton(
			-text => 'files',
			-value => 'f',
			-variable => \$choice)->grid(-row => 1, -column => 2);
		$tab->Radiobutton(
			-text => 'directories',
			-value => 'd',
			-variable => \$choice)->grid(-row => 1, -column => 3);
	}
	if ($given[0]) {
		my $en;
		my $tab = $book->add( 'finally', -label=>'finally', -raisecmd=>sub{_set_selection($en)} );
		$tab->Checkbutton(
			-text => 'append given document',
			-onvalue => 1, -offvalue => 0,
			-command => sub { $en->configure(-state => ($append_given ? 'normal' : 'disabled')) },
		  	-variable => \$append_given)->grid(-row => 0, -column => 0);
		$en = $tab->Entry(
			-width => 50,
			-state => 'normal',
			-textvariable => \$given[0])->grid(-row => 1, -column => 0);
	}
	my $answer = $dlg->Show();
	if ($answer and $answer eq "OK") {
		$output = set_dollars($input);
	}
	return $output;
}

my $test = _value_or_else(0, _getenv('test'));
given ($test) {
	when ('$') {
		$mw = _tkinit(1);
		say what_is_dollar(
			"\${PATTERN}", 
			[["No files", '']]);
	}
	when ('$$$') {
		$mw = _tkinit(1);
		say what_is_dollar(
			"find \${DIR} -name \"\${GLOB}\" -print | xargs grep -e \"\${PATTERN}\" 2>/dev/null", 
			[["No files", '']]);
	}
	default {
		1
	}
}

=pod
=cut

