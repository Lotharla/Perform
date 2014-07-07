package Manage::Utils;

use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Scalar::Util qw(looks_like_number);
use Cwd qw(abs_path);
use File::Basename qw(dirname basename fileparse);
use File::Temp;
use Data::Dump qw(dump pp);
use XML::XML2JSON;
use Test::More;
use Tk;

use Exporter::Easy (
	OK => [ qw(
		dump pp
		looks_like_number
		_max
		_min
		_gt
		_lt
		_ne
		_eq
		@_separator
		$_whitespace
		_combine
		_flatten
		_escapeDoubleQuotes
		_chomp
		_surround
		_has_whitespace
		_split_on_whitespace
		_blessed
		_is_type_of
		_array
		_hash
		_is_value
		_value_or_else
		_getenv
		_setenv
		_now
		_rndstr
		_index_of
		_array_contains
		_duplicates
		_string_contains
		_detect
		_interpolate
		_interpolate_rex
		_subst_rex
		_flip_hash
		_persist
		_implicit
		_iterate_sorted_values
		_fileparse
		_pathcombine
		_files_in_dir
		_is_glob
		_glob_match
		_dir_exists
		_file_exists
		_make_sure_file
		_contents_to_file
		_contents_of_file
		_extract_from
		_diagnostic
		_tempFilename
		_transientFile
		_capture_output
		_check_output
		_binsearch_alpha
		_binsearch_numeric
		_object_from_XML
		_set_selection
		_replace_text
		_center_window
		__center_window
		_key_event
		_key_event_check
		_tkinit
		_choose_font
		_question
		_message
		_text_info
		_file_types
		_ask_file
		_ask_directory
		_menu
		_create_popup_menu
		_install_menu
		_win32
		$_entries
	)],
);
sub _max ($$) { $_[$_[0] < $_[1]] }
sub _min ($$) { $_[$_[0] > $_[1]] }

sub _gt ($) { looks_like_number($_) && $_ > shift }
sub _lt ($) { looks_like_number($_) && $_ < shift }
sub _eq ($) { $_ eq shift }
sub _ne ($) { $_ ne shift }

sub _win32 {
	$^O eq 'MSWin32'
}

our @_separator = ("\t", "\n", "|");

sub _combine {
	join "\t", @_;
}

sub _flatten {
	my $string = shift;
	$string =~ s/$_/ /g foreach ("\t", "\n");
	$string
}

sub _escapeDoubleQuotes {
	my $string = shift;
	$string =~ s/\"/\\"/g;
	$string
}

sub _chomp {
	my $var = shift;
	chomp $var if $var;
	return $var
}

sub _surround {
	my $surrounder = shift;
	my ($start,$end) = ('','');
	given ($surrounder) {
		when (1) { ($start,$end) = ('\'','\''); }
		when (2) { ($start,$end) = ('"','"'); }
		when (3) { ($start,$end) = ('(',')'); }
		when (4) { ($start,$end) = ('[',']'); }
		when (5) { ($start,$end) = ('{','}'); }
		default { ($start,$end) = _value_or_else(sub{($start,$end)}, $surrounder); }
	}
	$start . $_[0] . $end
}

our $_whitespace = qr/[ \t\n]+/;

sub _has_whitespace {
	return shift(@_) =~ $_whitespace;
}

sub _split_on_whitespace {
	my $str = shift;
	my $limit = @_ > 0 ? shift : 2;
	split(/$_whitespace/, $str, $limit)
}

sub _array { ref($_[0]) eq 'ARRAY' ? @{$_[0]} : () }
sub _hash { ref($_[0]) eq 'HASH' ? %{$_[0]} : () }

sub _blessed { ref($_[0]) && UNIVERSAL::can($_[0],'can') }
sub _is_type_of { _blessed($_[1]) && $_[1]->isa($_[0]) }

sub _is_value { $_[0] || length($_[0]) }

sub _value_or_else {
	my $default = shift;
	my $key = shift;
	my $value = shift;
	given (ref($key)) {
		when ('HASH') {
			return %{$key};
		}
		when ('ARRAY') {
			return @{$key};
		}
		default {
			given (ref($value)) {
				when ('ARRAY') {
					my @value = @{$value};
					return defined $value[$key] ? $value[$key] : _value_or_else($default);
				}
				when ($_ eq 'HASH' || _blessed($value)) {
					my %value = %{$value};
					return exists $value{$key} ? $value{$key} : _value_or_else($default);
				}
				default {
					return $key if _is_value($key);
					if (ref($default) eq 'CODE') {
						$default->()
					} else {
						$default
					}
				}
			}
		}
	}
}

sub _getenv {
	my $key = _win32() ? uc($_[0]) : $_[0];
	my $value = _value_or_else '', $key, \%ENV;
	my $default = _value_or_else '', 1, \@_;
	if (! _is_value($value)) {
		return $default->() if ref($default) eq 'CODE';
		return $default;
	}
	if (looks_like_number($default) && !looks_like_number($value)) {
		return $default;
	}
	my @values = split(/$_separator[1]/, $value);
	return @values > 1 ? @values : $values[0];
}

sub _setenv {
	my $key = _win32() ? uc($_[0]) : $_[0];
	my $value = _value_or_else '', $_[1];
	$ENV{$key} = $value;
}

sub _now {
	use Time::HiRes;
	return Time::HiRes::time()
}

sub _rndstr { 
	join '', @_[ map { rand @_ } 1 .. shift ]
}

sub _index_of {
	my $value = shift;
	my @array = @_;
	my $i = 0;
	++$i until $i > $#array or $array[$i] eq $value;
	return $i > $#array ? -1 : $i;
}

sub _array_contains {
	my @array = @{$_[0]};
	my $value = $_[1];
	my %hash = map { $_ => 1 } @array;
	return exists $hash{$value};
}

sub _duplicates {
	my @array = @_;
	return () if ! @array;
	my %hash = map { $_ => 1 } @array;
	my @keys = keys %hash;
	foreach (@keys) {
		my $i = _index_of($_, @array);
		splice @array, $i, 1
	}
	@array
}

sub _string_contains {
	my ($haystack,$needle,$pos) = @_;
	given ($pos) {
		when (0) {
			return $haystack =~ /^\Q$needle\E/ ? 1 : 0;
		}
		when (-1) {
			return $haystack =~ /\Q$needle\E$/ ? 1 : 0;
		}
		default {
			return $haystack =~ /\Q$needle\E/ ? 1 : 0;
		}
	}
}

sub _detect {
	my ($haystack,$needle) = @_;
	my @found;
	my $j = 0;
	while(-1 < (my $i = index $haystack, $needle, $j)) {
		push @found, $i;
		$j = $i + 1
	};
	@found
}

sub _interpolate {
	my ($haystack,$needle,$replacement) = @_;
	while(-1 != (my $i = rindex $haystack,$needle)) {
		substr $haystack,$i,length($needle),$replacement
	};
	$haystack
}

sub _subst_rex {
	my ($haystack,$needle,$replacement,$option) = @_;
	if ($replacement =~ /\$([1-9])/) {
		$haystack =~ $needle;
		for my $i (1..9) {
			my $n = "\$" . $i;
			my $r = eval $n;
			last if ! $r;
			$replacement = _interpolate $replacement,$n,$r
		}
	} 
	if ($option) {
		$haystack =~ s|$needle|$replacement|g;
	} else {
		$haystack =~ s|$needle|$replacement|;
	}
	$haystack
}

sub _interpolate_rex {
	my $input = shift;
	my $needle = shift;
	my $picker = shift;
	my $haystack = $input;
	my $output = '';
	if ($haystack) {
		my $n = -1;
		while ($haystack =~ /$needle/) {
#dump \@-, \@+;
			my $p = $+[0];
			my $l = $p - $-[0];
			$output .= substr $haystack, 0, $p - $l;
			my $x = substr($haystack, $p - $l, $l);
			my $y = $_[++$n] ? $_[$n] : $picker->($x);
			return $input if !defined($y);
			$output .= $y;
			$haystack = substr $haystack, $p;
		}
		$output .= $haystack;
	}
	$output
}

sub _flip_hash {
	my %hash = %{$_[0]};
	my %flip;
	foreach my $key (keys %hash) {
		my $value = $hash{$key};
		if (exists $flip{$value}) {
			push(@{$flip{$value}}, $key);
		} else {
			my @array = ();
			unshift(@array, $key);
			$flip{$value} = \@array;
		}
	}
	return %flip;
}

sub _persist {
	my $file = shift;
	my $ref = shift;
	if ($ref) {
		open my $out, '>:encoding(UTF-8)', $file or die "Can't open file \"$file\" : $!\n";
		print {$out} dump $ref;
		close $out;
#_diagnostic(pp(%{$ref}));
	} else {
		open my $in, '<:encoding(UTF-8)', $file or die "Can't open file \"$file\" : $!\n";
		{
			local $/;    # slurp mode
			$ref = eval <$in>;
		}
		close $in;
#dump $ref;
		return $ref;
	}
}

sub _implicit {
	my $file = _make_sure_file(_pathcombine(dirname(__FILE__), ".implicit"));
	my %implicits = _hash(_persist $file);
	return %implicits if ! @_;
	return $implicits{$_[-1]} if @_ % 2;
	my %items = @_;
	$implicits{$_} = $items{$_} foreach (keys %items);
	_persist $file, \%implicits;
}

sub _iterate_sorted_values {
	my %hash = %{$_[0]};
	my $func = $_[1];
	foreach my $value (sort {$a <=> $b} values %hash) {
		foreach my $key (keys %hash) {
			if ($hash{$key} == $value) {
				$func->($key, $value);
			}
		}
	}
}

#	returns	($name,$path,$suffix)
sub _fileparse {
	fileparse(shift, qr/\.[^.]*/);
}

sub _pathcombine {
	use File::Spec::Functions qw(catfile);
	catfile @_
}

sub _files_in_dir {
	my $dir = shift;
	my $full = shift;
	opendir(DIR, $dir) || die "Can't open directory : $!\n";
	my @list = grep ! /^\.\.?$/, readdir(DIR);
	if ($full) {
		for (my $i = 0; $i < @list; $i++) {
			$list[$i] = _pathcombine($dir, $list[$i]);
		}
	}
	closedir(DIR);
	return @list;
}

sub _is_glob {
	shift =~ m/\*|\?/
}

sub _glob_match {
	my $glob = shift;
	$glob =~ s/\./\\./g;
	$glob =~ s/\*/.*/g;
	$glob =~ s/\?/.?/g;
	my $str = shift;
	return $str =~ /$glob/;
}

sub _dir_exists {
	my $dir = shift;
	$dir && -d $dir
}

sub _file_exists {
	my $file = shift;
	$file && -f $file
}

sub _make_sure_file {
	my $file = shift;
	unlink $file if shift;
	if (! _file_exists $file) {
		my @parts = _fileparse $file;
		mkdir $parts[1] unless -d $parts[1];
		open my $fh, ">", $file || die "Can't open file : $!\n";
		close $fh;
	}
	return $file;
}

sub _contents_of_file {
	my $file = shift;
	my $encode;
	if (ref($file) eq 'ARRAY') {
		$encode = $file->[1];
		$file = $file->[0];
	}
	open my $fh, '<' . ($encode ? ":$encode" : ''), $file || die "Can't open file : $!\n";
	no warnings;
	local $/ = undef;    # slurp mode
	my $contents = <$fh>;
	close $fh;
	return $contents;
}

sub _contents_to_file {
	my $file = shift;
	my ($encode,$append);
	if (ref($file) eq 'ARRAY') {
		$encode = $file->[1];
		$append = $file->[2];
		$file = $file->[0];
	}
	open my $fh, ($append ? '>>' : '>') . ($encode ? ":$encode" : ''), $file || die "Can't open file : $!\n";
	print $fh $_ foreach @_;
	close $fh;
}

sub _extract_from {
	my $contents = shift;
	$contents = _file_exists($contents) ? _contents_of_file($contents) : $contents;
	my $rex = _value_or_else '', shift;
	my @extract = $contents =~ /$rex/g;
	my $sep = looks_like_number($_[0]) ? $_separator[$_[0]] : $_[0];
	return @extract if ! $sep;
	$sep = _value_or_else $_separator[0], $sep;
	return join $sep, @extract
}

sub _diagnostic {
	my $msg = shift;
	my $diag = "/tmp/diag";
	mkdir $diag unless -d $diag;
	$diag = new File::Temp( DIR => $diag, UNLINK => 0 );
	_contents_to_file [$diag,'encoding(UTF-8)'], $msg;
}

sub _tempFilename {
	my $template = shift;
	my $dir = shift;
	$dir = File::Temp->newdir( CLEANUP => 0 ) if not $dir;
	mkdir $dir unless -d $dir;
	return new File::Temp( TEMPLATE => $template, DIR => $dir, UNLINK => 0 )->filename;
}

sub _transientFile {
#	return "/tmp/test";
	return new File::Temp( UNLINK => 1 );
}

sub _capture_output {
	my $func = shift;
	my $name = shift;
	my $file;
	if (!$name) {
		$file = _transientFile;
		$name = $file->filename;
	}
	open $file, '>:encoding(UTF-8)', "$name" || die "Can't open file : $!\n";
	select($file);
	given (ref $func) {
		when ('CODE') {
			$func->(@_);
		}
		when ('ARRAY') {
			my @array = @$func;
			$func = shift(@array);
			$func->(@array);
		}
	}
	select(STDOUT);
	close $file;
	return _contents_of_file($name);
}

sub _check_output {
	my $func = shift;
	my @rgx = @_;
	my $output = _capture_output($func);
	foreach my $rg (@rgx) { 
		ok($output =~ $rg, $output)
	}
}

sub _binsearch (&$\@) {
    my ( $comp, $target, $aref ) = @_;
    my ( $low, $high ) = ( 0, scalar @{$aref} );
    while ( $low < $high ) {
        my $cur = int( ( $low + $high ) / 2 );
        no strict 'refs';
        local ( ${ caller() . '::a'}, ${ caller() . '::b'} ) = ( $target, $aref->[$cur] );
        if ( $comp->( $target, $aref->[$cur] ) > 0 ) {
            $low = $cur + 1;
        }
        else {
            $high = $cur;
        }
    }
    return $low;
}

sub _binsearch_alpha {
	my $desc = $_[2];
	return _binsearch {$desc ? $b cmp $a : $a cmp $b} $_[0], @{$_[1]};
}

sub _binsearch_numeric {
	my $desc = $_[2];
	return _binsearch {$desc ? $b <=> $a : $a <=> $b} $_[0], @{$_[1]};
}



sub _set_selection {
	my $en = _value_or_else(undef,0,\@_);
	if ($en) {
		$en->focus;
		$en->selectionRange(0, 'end');
		$en->icursor('end');
	}
}

sub _replace_text {
	my $en = _value_or_else(undef,0,\@_);
	my $replacement = _value_or_else('',1,\@_);
	my $partial = _value_or_else(0,2,\@_);
	if ($en) {
		if ($partial) {
			my $index = $en->index('insert');
			if ($en->selectionPresent()) {
				$index = $en->index('sel.first');
				$en->delete('sel.first', 'sel.last') ;
			}
			$en->insert($index, $replacement);
			$en->focus;
		} else {
			$en->focus;
			$en->delete(0,'end');
			$en->insert(0, $replacement);
			_set_selection($en);
		}
	}
}

sub _object_from_XML {
	my $fname = shift;
	system("xmllint --noout \"$fname\"") and die $!;
	my $xml = _contents_of_file($fname);
	local $SIG{__WARN__} = sub { };
	my $XML2JSON = XML::XML2JSON->new();
	return $XML2JSON->xml2obj($xml);
}

sub _center_window {
	my $win = shift;
	$win->withdraw; # avoid the jumping window bug 
	$win->Popup;
}

sub __center_window {
	my $win = shift;
	$win->withdraw;   # Hide the window while we move it about
	$win->update;     # Make sure width and height are current
	# Center window
	my $xpos = int(($win->screenwidth  - $win->width ) / 2);
	my $ypos = int(($win->screenheight - $win->height) / 2);
	$win->geometry("+$xpos+$ypos");
	$win->deiconify;  # Show the window again
}

sub _key_event {
    my($c) = @_;
    my $e = $c->XEvent;
    my( $x, $y, $W, $K, $A ) = ( $e->x, $e->y, $e->K, $e->W, $e->A );
    say "Key pressed:";
    say "  x = $x";
    say "  y = $y";
    say "  W = $W (Widget)";
    say "  K = $K (Symbolic keysym)";
    say "  A = $A (ASCII character)";
}

sub _key_event_check {
	my $top = shift;
	$top->bind( '<Any-KeyPress>' => sub {_key_event(@_)});
}

sub _tkinit {
	my $top = tkinit;
	$top->withdraw if shift;
	$top->title(_value_or_else('', shift));
	my $font = shift;
	$top->optionAdd('*font', $font) if $font;
	$top
}

sub _choose_font {
	my $mw = shift;
	my $font = $mw->FontDialog->Show;
	if ($font) {
		$mw->optionAdd('*font', $font);
		$mw->update;
	}
}

sub _question {
	use Tk::MsgBox;
	my $top = _value_or_else sub{_tkinit(1)}, shift;
	return lc($top->MsgBox(-message => shift, -title => shift, -type => "YesNo", -icon => 'question')->Show)
}

sub _message {
	use Tk::MsgBox;
	my $top = _value_or_else sub{_tkinit(1)}, shift;
	my $result = $top->MsgBox(-message => shift, -title => shift, -type => "ok")->Show;
	$top->destroy;
	$result
}

sub _text_info {
	my( $title, $text)= @_;
	my $top = _tkinit 1, $title;
	require Tk::ROText;
	my $txt = $top->Scrolled("ROText", -scrollbars => 'e');
	$txt->pack(-side => 'left', -fill => 'both', -expand => 1);
	$txt->insert('end', $text);
	_center_window $top;
	MainLoop
}

sub _file_types {
	my @types = (
		["All files", '*'],
	);
	if (@_) {
		given(ref($_[0])) {
			when ('ARRAY') {
				push(@types, $_) foreach @{$_[0]};
			}
			when ('HASH') {
				my %hash = %{$_[0]};
				my %flip = _flip_hash(\%hash);
				push(@types, [$_, $flip{$_}]) foreach (keys %flip)
			}
			when (@_ != 1) {
				for (my $i = 0; $i < (@_ - 1); $i += 2) {
					push(@types, [$_[$i], $_[$i + 1]])
				}
			}
		}
	}
	return @types;
}

sub _ask_file {
	my $top = _value_or_else sub{_tkinit(1)}, shift;
	my $title = _value_or_else '', shift;
	my $file = _value_or_else sub{_implicit("file")}, shift;
	my @types = _array(shift);
	@types = _file_types if ! @types;
	if (@types == 1 && _win32()) {
		push @types, @types;
	}
	my $dir = dirname(_value_or_else abs_path($0), $file);
	$file = length($file) ? basename($file) : '';
	if (shift) {
		$file = $top->getSaveFile(
			-title => $title,
			-initialdir => $dir,
			-initialfile => $file,
			-filetypes => \@types);
	} else {
		$file = $top->getOpenFile(
			-title => $title,
			-initialdir => $dir,
			-initialfile => $file,
			-filetypes => \@types);
	}
	_implicit "file", $file if $file;
	$file
}

sub _ask_directory {
	my $top = _value_or_else sub{_tkinit(1)}, shift;
	my $title = _value_or_else '', shift;
	my $dir = _value_or_else sub{_implicit("directory")}, shift;
	$dir = _value_or_else dirname(abs_path $0), $dir;
	$dir = $top->chooseDirectory(
		-title => $title,
		-initialdir => $dir);
	_implicit "directory", $dir if $dir;
	$dir
}

sub _menu {
	my $win = shift;
	$win->configure(-menu => my $menu = $win->Menu);
	$menu
}

sub _create_popup_menu {
	my $win = shift;
	my $postcommand = shift;
	my $menu = $win->Menu(-tearoff => 0, -postcommand => $postcommand);
	$win->bind('<3>', [sub {
		my ($self, $x, $y) = @_;
		$x += $win->x();
		$y += $win->y();
		$menu->post($x, $y);
	}, Ev('x'), Ev('y')]);
	$win->bind('<1>', [sub {
		$menu->unpost;
	}, Ev('x'), Ev('y')]);
	$menu;
}

sub _install_menu {
	my $obj = shift;
	my $postcommand = shift;
	my @items = @_;
	my $menu;
	if (_is_type_of("Tk::Menu",$obj)) {
		$menu = $obj->cascade(-label => pop(@items), 
			-underline => 0, 
			-tearoff => 'no',
			-postcommand => $postcommand
		)->cget('-menu');
	} else {
		$menu = _create_popup_menu($obj, $postcommand);
	}
	while (defined($items[1])) {
		my( $label, $command )= splice(@items,0,2);
		$menu->add('command', -label => $label, -command => $command);
	}
	$menu
}

our $_entries = dirname(dirname  __FILE__) . "/.entries";
1;

