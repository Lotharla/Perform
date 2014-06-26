package Manage::Given;
use strict;
use warnings;
no warnings 'experimental';
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
use Manage::Utils qw(
	dump pp
	_gt
	_combine
	_getenv 
	_setenv
	_value_or_else 
	_interpolate_rex
	_tkinit 
	_set_selection 
	_replace_text 
	_file_types 
	_ask_file 
	_ask_directory
);
use Exporter::Easy (
	OK => [ qw(
		@given
		given_title
		append_given
		%dollars
		hasDollar
		isDollar
		dollar_amount
		make_dollar
		detect_dollar
		get_dollars
		set_dollars
		place_given
		replace_dollar
	)],
);
our @given = _getenv('given', sub{ () });
sub given_title {
	my $title = shift;
	$title = _getenv('title', $title);
	if (@given) {
		$title .= " on " . ($#given > 0 ? scalar(@given) . " files" : "'$given[0]'");
	}
	$title
}
sub append_given {
	my $output = shift;
	if (@given) {
		return _combine( $output, @given );
	}
	$output
}
our %dollars;
BEGIN {
	tie %dollars, 'Tie::IxHash';
}
my $dollar = qr/\$(\d+)|\$\{(\w+)(\:(\w+))?\}/;
sub hasDollar {
	my $str = _value_or_else '', shift;
	return $str =~ $dollar
}
sub isDollar {
	return shift(@_) =~ m[^$dollar$]
}
sub dollar_amount {
	$_[0] =~ /$dollar/;
	$1 ? $1 : ($3?[$2,$4]:$2)
}
sub detect_dollar {
	_interpolate_rex shift,$dollar,shift,@_
}
sub make_dollar {
	my $amount = shift;
	if (ref($amount) eq 'ARRAY') {
		$amount = $amount->[0] . ':' . $amount->[1];
	}
	return "\$" . sprintf(looks_like_number($amount) ? '%d' : '{%s}', $amount);
}
sub given_for_dollar {
	my $key = shift;
	my $a = $dollars{$key}->{amount};
	$a = ref($a) eq 'ARRAY' ? $a->[0] : $a;
	if (looks_like_number($a) && $a < @given + 1 && $a > 0) {
		return $given[$a - 1];
	} else {
		return make_dollar($a);
	}
}
sub get_dollars {
	%dollars = ();
	detect_dollar (shift, sub {
		my $key = $_[0];
		$dollars{$key} = { amount => dollar_amount(@_), value => $key };
		$dollars{$key}->{value} = given_for_dollar $key;
	});
	%dollars
}
sub set_dollars {
	return detect_dollar (shift, sub {
		my $value = $dollars{$_[0]}->{value};
		my $amount = $dollars{$_[0]}->{amount};
		if (ref($amount) eq 'ARRAY') {
			if ($amount->[1] eq 'dir' && -f $value) {
				$value = dirname $value;
			}
		}
		$value
	});
}
sub place_given {
	my $input = shift;
	get_dollars($input);
	set_dollars($input)
}
my ($obj, $window, $width);
sub inject {
	$obj = shift;
	$width = _value_or_else(75, 'width', $obj);
	$window = $obj->{window};
}
sub replace_dollar {
	my $input = shift;
	my @types = _file_types(shift);
	my $output = '';
	my @results = @_;
	if (@results) {
		$output = detect_dollar ($input, sub {
			shift(@results)
		});
		return $output;
	}
	%dollars = get_dollars($input);
	my $dlg = $window->DialogBox(
		-title => $input,
		-buttons => ['OK', 'Cancel'],
		-default_button => 'Cancel');
	my $book = $dlg->NoteBook()->pack( -fill=>'both', -expand=>1 );
	for my $key (keys %dollars) {
		my $en;
		my $tab = $book->add( $dollars{$key}->{value}, -label=>$key, -raisecmd=>sub{_set_selection($en)} );
		$en = $tab->Entry(
			-width => _value_or_else(75, $width),
			-textvariable => \$dollars{$key}->{value}
		)->grid(-row => 0, -column => 0, -columnspan => 4);
		my $btn = $tab->Menubutton( 
			-text => 'Given', 
			-tearoff => 0,
		)->grid(-row => 1, -column => 0);
		my $menu = $btn->cget('-menu');
		foreach my $gift (@given) {
			$menu->command(-label => $gift, 
				-command => sub{
					_replace_text($en, $gift, 1)
				}
			);
		}
		if (! @given) {
			my $ba = $window->Balloon(-background=>'yellow');
			$ba->attach($btn,-initwait => 0,-balloonmsg => "no given items");
		}
		my $choice = 'f';
		$tab->Button( 
			-text=>'Browse...', 
			-command=> sub { 
				my $answer = $choice eq 'f' ?
					_ask_file($window, 'Choose file', 
						-f $dollars{$key}->{value} ? $dollars{$key}->{value} : '', \@types) :
					_ask_directory($window, 'Choose directory', 
						-d $dollars{$key}->{value} ? $dollars{$key}->{value} : ''); 
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
show:
	my $answer = $dlg->Show();
	if ($answer and $answer eq "OK") {
		$output = set_dollars($input);
	}
	return $output;
}
given (_value_or_else(0, _getenv('test'))) {
	when (_gt 1) {
		push @given, "xxx", "yyy";
		$window = _tkinit(1);
		my $input = "find \${1:dir} -name \"\${GLOB}\" -print | xargs grep -e \"\${PATTERN}\" 2>/dev/null";
#		say place_given($input);
		say replace_dollar($input, [["No files", '']]);
	}
	when (_gt 0) {
		$window = _tkinit(1);
		say replace_dollar("\${PATTERN}", [["No files", '']]);
	}
	default {
		1
	}
}

=pod
=cut

