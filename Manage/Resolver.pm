package Manage::Resolver;
use strict;
use warnings;
no warnings 'experimental';
use Scalar::Util qw(looks_like_number);
use Tie::IxHash;
use Tk;
use Tk::DialogBox;
use Tk::NoteBook;
use feature qw(say switch);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	catfile
	_gt _lt
	_combine
	_getenv 
	_setenv
	_is_value
	_value_or_else 
	_interpolate_rex
	_tkinit 
	_set_selection 
	_replace_text 
	_file_types 
	_ask_file 
	_ask_directory
	_install_menu_button
	_clipdir
	_files_in_dir
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
		make_value
		detect_dollar
		get_dollars
		set_dollars
		place_given
		resolve_dollar
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
my %dollars;
BEGIN {
	tie %dollars, 'Tie::IxHash';
}
my $dollar = qr/\$(\d+)|\$\{(\w+)(\:(\w+))?\}/;
sub hasDollar {
	_value_or_else('', shift) =~ $dollar
}
sub isDollar {
	shift(@_) =~ m[^$dollar$]
}
sub dollar_amount {
	$_[0] =~ /$dollar/;
	_is_value($1) ? 
		$1 : 
		($3?[$2,$4]:$2)
}
sub make_dollar {
	my $amount = shift;
	if (ref($amount) eq 'ARRAY') {
		$amount = $amount->[0] . ':' . $amount->[1];
	}
	"\$" . sprintf(looks_like_number($amount) ? '%d' : '{%s}', $amount)
}
sub make_value {
	my ($amount,$value) = @_;
	if (ref($amount) eq 'ARRAY') {
		if ($amount->[1] eq 'dir' && -f $value) {
			$value = dirname $value;
		}
	}
	$value
}
sub is_given {
	my $amount = shift;
	my $a = ref($amount) eq 'ARRAY' ? $amount->[0] : $amount;
	looks_like_number($a) && $a >= 0 && $a < @given + 1 ?
		$a : -1
}
sub detect_dollar {
	_interpolate_rex shift,$dollar,shift,@_
}
sub get_dollars {
	%dollars = ();
	detect_dollar (shift, sub {
		my $key = $_[0];
		$dollars{$key} = { amount => dollar_amount(@_), value => $key };
		my $amount = $dollars{$key}->{amount};
		my $x = is_given($amount);
		given ($x) {
			when (0) {
				$x = _combine map { make_value $amount, $_ } @given;
			}
			when (_gt 0) {
				$x = make_value $amount, $given[$x - 1];
			}
			default {
				$x = make_dollar $amount;
			}
		}
		$dollars{$key}->{value} = $x;
	});
	%dollars
}
sub set_dollars {
	return detect_dollar (shift, sub {
		make_value $dollars{$_[0]}->{amount}, $dollars{$_[0]}->{value}
	});
}
sub place_given {
	my $input = shift;
	get_dollars($input);
	set_dollars($input)
}
my ($window, $width);
sub inject {
	my $obj = shift;
	$window = $obj->{window};
	$width = _value_or_else(75, 'width', $obj);
}
sub resolve_dollar {
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
		my $tab = $book->add( $dollars{$key}->{value}, 
			-label => $key, 
			-raisecmd => sub{_set_selection($en)}
		);
		$en = $tab->Entry(
			-width => _value_or_else(75, $width),
			-textvariable => \$dollars{$key}->{value}
		)->pack(-side => 'top', -fill=>'x', -expand=>1);
		my $frm = $tab->Frame()->pack(-side => 'bottom', -fill=>'x', -expand=>1);
		my ($row,$col) = (0,0);
		my $btn = _install_menu_button $frm, 'given', sub{_replace_text($en, $_[0], 1)}, @given;
		$btn->grid(-row => $row, -column => $col++);
		my $dir = _clipdir;
		my @files = _files_in_dir($dir);
		$btn = _install_menu_button($frm, 'clips', 
			sub {
				my $repl = catfile $dir, $_[0];
				_replace_text($en, $repl, 1)
			}, 
			@files);
		$btn->grid(-row => $row, -column => $col++);
		my $choice = 'f';
		$frm->Button( 
			-text=>'Browse...', 
			-command=> sub { 
				my $answer = $choice eq 'f' ?
					_ask_file($window, 'Choose file', 
						-f $dollars{$key}->{value} ? $dollars{$key}->{value} : '', \@types) :
					_ask_directory($window, 'Choose directory', 
						-d $dollars{$key}->{value} ? $dollars{$key}->{value} : ''); 
				_replace_text($en, $answer) if $answer;
			} 
		)->grid(-row => $row, -column => $col++);
		$frm->Radiobutton(
			-text => 'files',
			-value => 'f',
			-variable => \$choice)->grid(-row => $row, -column => $col++);
		$frm->Radiobutton(
			-text => 'directories',
			-value => 'd',
			-variable => \$choice)->grid(-row => $row, -column => $col++);
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
		say resolve_dollar($input, [["No files", '']]);
	}
	when (_gt 0) {
		$window = _tkinit(1);
		say resolve_dollar("\${PATTERN}", [["No files", '']]);
	}
	default {
		1
	}
}

=pod
=cut

