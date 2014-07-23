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
	catdir 
	tmpdir
	_array
	_max _min
	_gt _lt
	_combine
	_getenv 
	_setenv
	_is_array_ref
	_is_value
	_blessed
	_value_or_else 
	_interpolate_rex
	_rndstr
	_tkinit 
	_set_selection 
	_replace_text 
	_files_in_dir
	_file_types 
	_file_exists
	_contents_of_file
	_contents_to_file
	_ask_file 
	_ask_directory
	_refresh_menu_button_items
	_install_menu_button
	_message
	_text_dialog
	_question
	_capture_output_2
	_split_on_whitespace
	@_separator
);
use Exporter::Easy (
	OK => [ qw(
		@given
		set_given
		given_title
		%dollars
		has_dollar
		is_dollar
		dollar_amount
		make_dollar
		make_value
		detect_dollar
		get_dollars
		set_dollars
		place_given
		resolve_dollar
		clipdir
		next_clip
		get_clip
		devels
	)],
);
sub set_given {
	@given = _getenv('given', sub{ () })
}
our @given = set_given;
sub given_title {
	my $title = shift;
	$title = _getenv('title', $title);
	$title .=  $_separator[0];
	if (@given) {
		$title .= "on " . ($#given > 0 ? scalar(@given) . " given items" : "'$given[0]'");
	}
	$title
}
sub clipdir {
	my $dir = catdir tmpdir, "clip";
	mkdir $dir if ! -d $dir;
	$dir
}
sub next_clip {
	my $dir = clipdir;
	my $d = 1;
	foreach my $label (_files_in_dir($dir)) {
		if ($label =~ /^_(\d+)$/) {
			$d = _max $d, $1 + 1;
		}
	}
	catfile $dir, "_$d"
}
sub get_clip {
	my $win = shift;
	my $file = shift;
	Tk::catch {
		_file_exists($file) ? 
			_contents_of_file($file) : 
			$win->clipboardGet;
	};
}
my %dollars;
BEGIN {
	tie %dollars, 'Tie::IxHash';
}
my $dollar = qr/\$(\d+)|\$\{([\w\*]+)(\:(\w+))?\}/;
sub has_dollar {
	_value_or_else('', shift) =~ $dollar
}
sub is_dollar {
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
	if (_is_array_ref($amount)) {
		$amount = $amount->[0] . ':' . $amount->[1];
	}
	"\$" . sprintf(looks_like_number($amount) ? '%d' : '{%s}', $amount)
}
sub devels {
	my $sh = catfile dirname(dirname  __FILE__), "../bin/devel.sh";
	my $output = _capture_output_2($sh . " -s");
	_split_on_whitespace $output, 0;
}
sub make_value {
	my ($amount,$value) = @_;
	if (_is_array_ref($amount)) {
		given ($amount->[1]) {
			when ('dir') {
				$value = dirname $value if -f $value;
			}
			when ('devels') {
				$value = join($_separator[2], devels);
			}
		}
	}
	$value
}
sub detect_dollar {
	_interpolate_rex shift,$dollar,shift,@_
}
sub is_given {
	my $amount = shift;
	my @gin = @_ < 1 ? @given : @_;
	my $a = _is_array_ref($amount) ? $amount->[0] : $amount;
	looks_like_number($a) && $a >= 0 && $a < @gin + 1 ?
		$a : -1
}
sub get_dollars {
	my $input = shift;
	my @gin = @_ < 1 ? @given : @_;
	%dollars = ();
	detect_dollar ($input, sub {
		my $key = $_[0];
		$dollars{$key} = { amount => dollar_amount(@_), value => $key };
		my $amount = $dollars{$key}->{amount};
		my $x = is_given($amount, @gin);
		given ($x) {
			when (0) {
				$x = _combine map { make_value $amount, $_ } @gin;
			}
			when (_gt 0) {
				$x = make_value $amount, $gin[$x - 1];
			}
			default {
				$x = '';
			}
		}
		$dollars{$key}->{value} = $x;
	});
	%dollars
}
sub set_dollars {
	my $input = shift;
	return detect_dollar ($input, sub {
		make_value $dollars{$_[0]}->{amount}, $dollars{$_[0]}->{value}
	});
}
sub place_given {
	my $input = shift;
	my @gin = @_ < 1 ? @given : @_;
	get_dollars $input, @gin;
	set_dollars $input
}
my ($obj, $window, $width);
sub inject {
	$obj = shift;
	$window = $obj->{window};
	$width = _value_or_else(75, 'width', $obj);
}
sub add_clip {
	my $win = shift;
	my $file = next_clip;
	my $text = get_clip $window, $file;
	my @dim = _blessed($obj) ? $obj->dimension("text") : ();
	my $result = _text_dialog $win, \@dim, $file, $text;
	if ($result) {
		my @result = _array($result);
		$file = _ask_file($win, 'Save clip', $file, [], 1);;
		_contents_to_file $file, $result->[1] if $file;
		return 1
	}
	0
}
sub remove_clip {
	my $win = shift;
	my $file = shift;
	unlink $file if _file_exists($file) && _question($win, $file, 'Remove clip');
}
sub clip_menu {
	my $win = shift;
	my $title = shift;
	my $entry = shift;
	my $btn = shift;
	my $dir = clipdir;
	my @files = _files_in_dir($dir);
	my $command = sub {
		my $repl = catfile $dir, $_[0];
		_replace_text($entry, $repl, 1)
	};
	if ($btn) {
		_refresh_menu_button_items $win, $title, $btn, 
			$command, 
			sort @files;
	} else {
		$btn = _install_menu_button $win, $title, sub {}, 
			$command, 
			sort @files;
	}
	$btn
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
		my $page = $book->add( _rndstr, 
			-label => $key, 
			-raisecmd => sub{_set_selection($en)}
		);
		$en = $page->Entry(
			-width => _value_or_else(75, $width),
			-textvariable => \$dollars{$key}->{value}
		)->pack(-side => 'top', -fill=>'x', -expand=>1);
		my $frm = $page->Frame()->pack(-side => 'bottom', -fill=>'x', -expand=>1);
		my ($row,$col) = (0,0);
		my $choice = 'f';
		$frm->Button( 
			-text => 'Browse...', 
			-command => sub { 
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
		($row,$col) = (1,0);
		my $btn = _install_menu_button $frm, 'Given', sub{}, 
			sub{_replace_text($en, $_[0], 1)}, @given;
		$btn->grid(-row => $row, -column => $col++);
		$btn = clip_menu $frm, 'Clips', $en; 
		$btn->grid(-row => $row, -column => $col++);
=pod
		$frm->Button( 
			-text => 'Add clip', 
			-command => [sub { 
				my ($frm, $en, $btn) = @_;
				if (add_clip $dlg) {
					clip_menu $frm, 'clip', $en, $btn;
				}
			}, $frm, $en, $btn] 
		)->grid(-row => $row, -column => $col++);
		$frm->Button( 
			-text => 'Remove clip', 
			-command => [sub { 
				my ($frm, $en, $btn) = @_;
				my $file = $dollars{$key}->{value};
				if (remove_clip $dlg, $file) {
					clip_menu $frm, 'clip', $en, $btn;
				}
			}, $frm, $en, $btn] 
		)->grid(-row => $row, -column => $col++);
=cut
	}
show:
	my $answer = $dlg->Show();
	if ($answer and $answer eq "OK") {
		$output = set_dollars($input);
	}
	return $output;
}
1;
