package Manage::Utils;

use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Scalar::Util qw(looks_like_number);
use File::Basename qw(dirname basename fileparse);
use File::Temp;
use Data::Dump qw(dump pp);
use Test::More;
use Tk;

use Exporter::Easy (
	OK => [ qw(
		dump pp
		looks_like_number
		@_separator
		$_whitespace
		_combine
		_flatten
		_escapeDoubleQuotes
		_said
		_chomp
		_has_whitespace
		_split_on_whitespace
		_isBlessed
		_value_or_else
		_getenv
		_now
		_rndStr
		_indexOf
		_contains
		_flip_hash
		_persist_hash
		_iterate_sorted_values
		_fileparse
		_pathcombine
		_files_in_dir
		_is_glob
		_glob_match
		_make_sure_file
		_contents_to_file
		_contents_of_file
		_diagnostic
		_tempFilename
		_transientFile
		_capture_output
		_check_output
		_binsearch_alpha
		_binsearch_numeric
		_set_selection
		_replace_text
		_center_window
		__center_window
		_key_event
		_key_event_check
		_tkinit
		_question
		_message
		_text_info
		_file_types
		_ask_file
		_ask_directory
		_popup_menu
	)],

);

our @_separator = ("\t", "\n");

sub _combine {
	join ($_separator[0], @_);
}

sub _flatten {
	my $string = shift;
	$string =~ s/$_/ /g foreach @_separator;
	$string
}

sub _escapeDoubleQuotes {
	my $string = shift;
	$string =~ s/\"/\\"/g;
	$string
}

sub _said { _combine(@_) . $_separator[1] }

sub _chomp {
	my $var = shift;
	chomp $var;
	return $var
}

our $_whitespace = qr/[ \t\n]+/;

sub _has_whitespace {
	return shift(@_) =~ $_whitespace;
}

sub _split_on_whitespace {
	my $str = shift;
	my $limit = scalar(@_) > 0 ? shift : 2;
	return split(/$_whitespace/, $str, $limit);
}

sub _isBlessed {
	my $r = shift;
	ref($r) && UNIVERSAL::can($r,'can')
}

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
				when ($_ eq 'HASH' || _isBlessed($value)) {
					my %value = %{$value};
					return exists $value{$key} ? $value{$key} : _value_or_else($default);
				}
				default {
					return $key if $key;
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
	my $value = _value_or_else '', $_[0], \%ENV;
	my $default = _value_or_else '', 1, \@_;
	if (not $value) {
		return $default->() if ref($default) eq 'CODE';
		return $default;
	}
	if (looks_like_number($default) && !looks_like_number($value)) {
		return $default;
	}
	my @values = split(/$_separator[1]/, $value);
	return @values if scalar(@values) > 1;
	$values[0]
}

sub _now {
	use Time::HiRes;
	return Time::HiRes::time()
}

sub _rndStr{ 
	join'', @_[ map{ rand @_ } 1 .. shift ]
}

sub _indexOf {
	my $value = shift;
	my @array = @{$_[0]};
	my $i = 0;
	++$i until $i > $#array or $array[$i] eq $value;
	return $i > $#array ? -1 : $i;
}

sub _contains {
	my @array = @{$_[0]};
	my $value = $_[1];
	my %hash = map { $_ => 1 } @array;
	return exists $hash{$value};
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

sub _persist_hash {
	my $file = shift;
	my $hashref = shift;
	if ($hashref) {
		open my $out, '>:encoding(UTF-8)', $file or die "Can't open file \"$file\" : $!\n";
		print {$out} dump $hashref;
		close $out;
#_diagnostic(pp(%{$hashref}));
	} else {
		open my $in, '<:encoding(UTF-8)', $file or die "Can't open file \"$file\" : $!\n";
		{
			local $/;    # slurp mode
			$hashref = eval <$in>;
		}
		close $in;
#dump $hashref;
		return $hashref;
	}
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
	my @list = grep !/^\.\.?$/, readdir(DIR);
	if ($full) {
		for (my $i = 0; $i < scalar(@list); $i++) {
			$list[$i] = _pathcombine($dir, $list[$i]);
		}
	}
	closedir(DIR);
	return @list;
}

sub _make_sure_file {
	my $file = shift;
	unlink $file if shift;
	if (! -f $file) {
		open my $fh, ">", $file || die "Can't open file : $!\n";
		close $fh;
	}
	return $file;
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

sub _contents_of_file {
	my $file = shift;
	open my $fh, '<:encoding(UTF-8)', "$file" || die "Can't open file : $!\n";
	local $/ = undef;    # slurp mode
	my $contents = <$fh>;
	close $fh;
	return $contents;
}

sub _contents_to_file {
	my $file = shift;
	my $contents = shift;
	open my $fh, '>:encoding(UTF-8)', "$file" || die "Can't open file : $!\n";
	print $fh $contents;
	close $fh;
	return $contents;
}

sub _diagnostic {
	my $msg = shift;
	my $diag = "/tmp/diag";
	mkdir $diag unless -d $diag;
	$diag = new File::Temp( DIR => $diag, UNLINK => 0 );
	_contents_to_file $diag, $msg;
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
		ok($output =~ $rg)
	}
	say sprintf("output : '%s'", $output);
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
	$top
}

sub _question {
	use Tk::MsgBox;
	my $top = shift;
	return lc($top->MsgBox(-message => shift, -title => shift, -type => "YesNo", -icon => 'question')->Show)
}

sub _message {
	use Tk::MsgBox;
	my $top = _tkinit(1);
	my $result = $top->MsgBox(-message => shift, -title => shift, -type => "ok")->Show;
	$top->destroy;
	$result
}

sub _text_info {
	my( $title, $text)= @_;
	my $top = _tkinit 1, $title;
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
	my $len = scalar(@_);
	if ($len) {
		given(ref($_[0])) {
			when ('ARRAY') {
				push(@types, $_) foreach @{$_[0]};
			}
			when ('HASH') {
				my %hash = %{$_[0]};
				my %flip = _flip_hash(\%hash);
				push(@types, [$_, $flip{$_}]) foreach (keys %flip)
			}
			when ($len != 1) {
				for (my $i = 0; $i < ($len - 1); $i += 2) {
					push(@types, [$_[$i], $_[$i + 1]])
				}
			}
		}
	}
	return @types;
}

sub _ask_file {
	my $mw = shift;
	my $title = shift;
	my $file = shift;
	my @types = _file_types(@_);
	return $mw->getOpenFile(
		-title => $title,
		-initialdir => dirname($file),
		-initialfile => basename($file),
		-filetypes => \@types);
}

sub _ask_directory {
	my ($mw,$title,$dir) = @_;
	return $mw->chooseDirectory(
		-title => $title,
		-initialdir => $dir);
}

sub _popup_menu {
	my $win = shift;
	my $postcommand = shift;
	my @items = @_;
	use Tk::Menu;
	my $menu = $win->Menu(-tearoff => 0, -postcommand => $postcommand);
	while (defined($items[1])) {
		my( $label, $command )= splice(@items,0,2);
		$menu->add('command', -label => $label, -command => $command);
	}
	$win->bind('<3>', [sub {
		my ($self, $x, $y) = @_;
		$menu->post($win->x + $x, $win->y + $y);
	}, Ev('x'), Ev('y')]);
	$win->bind('<1>', [sub {
		$menu->unpost;
	}, Ev('x'), Ev('y')]);
	$menu
}

1;

