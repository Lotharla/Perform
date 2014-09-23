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
	_getenv_once
	_setenv
	_is_array_ref
	_is_value
	_is_blessed
	_value_or_else 
	_interpolate_rex
	_rndstr
	_clipboard
	_get_clipboard
	_capture_output
	_tkinit 
	_set_selection 
	_replace_text 
	_files_in_dir
	_file_types 
	_file_exists
	_make_sure_dir
	_contents_of_file
	_contents_to_file
	_ask_file 
	_ask_directory
	_refresh_menu_button_items
	_install_menu_button
	_message
	_text_dialog
	_question
	_result_perform
	_split_on_whitespace
	@_separator
	_realpath
);
require Manage::Settings;
use Exporter::Easy (
	OK => [ qw(
		@inputs
		set_inputs
		inputs_title
		%dollars
		has_dollar
		is_dollar
		dollar_amount
		dollar_attr
		make_dollar
		make_value
		detect_dollar
		get_dollars
		set_dollars
		place_inputs
		inputs_meet_dollars
		resolve_dollar
		clipdir
		next_clip
		get_clip
		devels
	)],
);
sub set_inputs {
	@inputs = @ARGV ? @ARGV : _getenv('inputs', sub{ () })
}
our @inputs = set_inputs;
sub inputs_title {
	my $title = _value_or_else '',shift;
	$title .=  $_separator[0];
	if (@inputs) {
		$title .= "on " . ($#inputs > 0 ? scalar(@inputs) . " given items" : "'$inputs[0]'");
	}
	$title
}
sub clipdir {
	_make_sure_dir catdir(tmpdir, "clip")
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
		if (_file_exists($file)) { 
			_contents_of_file($file)
		} else { 
			_get_clipboard
		}
	};
}
my %dollars;
BEGIN {
	tie %dollars, 'Tie::IxHash';
}
my $dollar = qr/\$(\d+)|\$\{([\w\*]+)(\:(\w+))?\}/;
sub has_dollar {
	my $expr = _value_or_else '', shift;
	my $res = $expr =~ $dollar;
	$res
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
sub dollar_attr {
	my $amount = dollar_amount $_[0];
	_is_array_ref($amount) ?
		$amount->[1] : ''
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
	my $output = _result_perform($sh . " -s");
	_split_on_whitespace $output, 0;
}
sub make_value {
	my ($amount,$value) = @_;
	if (_is_array_ref($amount)) {
		given ($amount->[1]) {
			when ('dir') {
				$value = _realpath $value;
				$value = dirname $value if -f $value;
			}
			when ('file') {
				$value = _realpath $value;
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
sub is_input {
	my $amount = shift;
	my @gin = @_ < 1 ? @inputs : @_;
	my $a = _is_array_ref($amount) ? $amount->[0] : $amount;
	looks_like_number($a) && $a >= 0 && $a < @gin + 1 ?
		$a : -1
}
sub get_dollars {
	my $input = shift;
	my @gin = @_ < 1 ? @inputs : @_;
	%dollars = ();
	detect_dollar ($input, sub {
		my $key = $_[0];
		$dollars{$key} = { amount => dollar_amount(@_), value => $key };
		my $amount = $dollars{$key}->{amount};
		my $x = is_input($amount, @gin);
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
		my $key = shift;
		make_value $dollars{$key}->{amount}, $dollars{$key}->{value}
	});
}
sub place_inputs {
	my $input = shift;
	my @gin = @_ < 1 ? @inputs : @_;
	get_dollars $input, @gin;
	set_dollars $input
}
sub inputs_meet_dollars {
	@inputs == keys %dollars
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
	my @dim = _is_blessed($obj) ? $obj->dimension("text") : ();
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
	my $command = shift;
	my $dir = clipdir;
	$command = sub {
		my $repl = catfile $dir, $_[0];
		_replace_text($entry, $repl, 1)
	} unless $command;
	my @files = _files_in_dir($dir);
	@files = sort @files;
	if ($btn) {
		_refresh_menu_button_items $win, $title, $btn, 
			$command, 
			@files;
	} else {
		$btn = _install_menu_button $win, $title, sub {}, 
			$command, 
			@files;
	}
	$btn
}
sub resolve_dollar {
	my $input = shift;
	my $output = '';
	my @results = @_;
	if (@results) {
		$output = detect_dollar ($input, sub {
			shift(@results)
		});
		return $output;
	}
	my @types = _file_types(Settings::apply('Associations'));
	%dollars = get_dollars $input;
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
		my $choice = dollar_attr($key) eq 'dir' ? 'd' : 'f';
		$frm->Button( 
			-text => 'Browse...', 
			-command => sub { 
				my $answer = $choice eq 'f'
					? _ask_file($window, 'Choose file', 
						[-f $dollars{$key}->{value} ? $dollars{$key}->{value} : ''], \@types)
					: _ask_directory($window, 'Choose directory', 
						-d $dollars{$key}->{value} ? $dollars{$key}->{value} : ''); 
				_replace_text $en, $choice eq 'f' ? "@$answer" : $answer if $answer;
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
		my $btn = _install_menu_button $frm, 'Inputs', sub{}, 
			sub{_replace_text($en, $_[0], 1)}, @inputs;
		$btn->grid(-row => $row, -column => $col++);
		my $contents = 0;
		my $clip_command = sub {
			my $repl = catfile clipdir, $_[0];
			_replace_text($en, 
				$contents ? _contents_of_file $repl : $repl, 
				1)
		};
		$btn = clip_menu $frm, 'Clips', $en, undef, $clip_command; 
		$btn->grid(-row => $row, -column => $col++);
		$frm->Checkbutton(
			-text => 'contents',
			-onvalue => 1, -offvalue => 0, 
			-variable => \$contents
		)->grid(-row => $row, -column => $col++);
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
	my $answer = $dlg->Show();
	if ($answer and $answer eq "OK") {
		$output = set_dollars $input ;
	}
	return $output;
}
given (_getenv_once('test', 0)) {
	when (_gt 1) {
		Manage::Resolver::inject({window => _tkinit(1)});
		push @inputs, "/tmp/clip", "*", ".*";
		my $input = "find \${1:dir} -name \"\${2:file}\" -print | xargs grep -e \"\${PATTERN}\" 2>/dev/null";
#		say place_inputs($input);
		say resolve_dollar($input);
	}
	when (_gt 0) {
		Manage::Resolver::inject({window => _tkinit(1)});
		say resolve_dollar("\${PATTERN}");
	}
	default {
		1
	}
}
