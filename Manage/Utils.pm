package Manage::Utils;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Scalar::Util qw(looks_like_number);
use Cwd qw(abs_path);
use File::Basename qw(dirname basename fileparse);
use File::Spec::Functions qw(catfile catdir tmpdir);
use File::Temp;
use Data::Dump qw(dump pp);
use IPC::Open3;
use XML::XML2JSON;
use Test::More;
use Tk;
use Exporter::Easy (
	OK => [ qw(
		dump 
		pp
		looks_like_number
		tmpdir
		catfile
		catdir
		ok is isnt is_deeply done_testing
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
		_is_code_ref
		_is_array_ref
		_is_hash_ref
		_array
		_hash
		_is_value
		_value_or_else
		_getenv
		_getenv_once
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
		_clipboard
		_get_clipboard
		_persist
		_implicit
		_visit_sorted_tree
		_iterate_sorted_values
		_fileparse
		_files_in_dir
		_is_glob
		_glob_match
		_dir_exists
		_file_exists
		_make_sure_dir
		_make_sure_file
		_contents_to_file
		_contents_of_file
		_is_sqlite_file
		_extract_from
		_diagnostic
		_temp_filename
		_transient_file
		_call
		_capture_output
		_check_output
		_perform
		_perform_2
		_capture_output_2
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
		_text_dialog
		_file_types
		_ask_file
		_ask_directory
		_menu
		_create_popup_menu
		_delete_popup_menu
		_install_menu
		_refresh_menu_button_items
		_install_menu_button
		_win32
		$_entries $_history
	)],
);
sub _max ($$) { $_[$_[0] < $_[1]] }
sub _min ($$) { $_[$_[0] > $_[1]] }
sub _eq ($) { $_ eq shift }
sub _ne ($) { $_ ne shift }
sub _gt ($) { looks_like_number($_) && $_ > $_[0] || $_ gt $_[0] }
sub _lt ($) { looks_like_number($_) && $_ < $_[0] || $_ lt $_[0] }
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
sub _is_code_ref { ref($_[0]) eq 'CODE' }
sub _is_array_ref { ref($_[0]) eq 'ARRAY' }
sub _is_hash_ref { ref($_[0]) eq 'HASH' }
sub _array { _is_array_ref($_[0]) ? @{$_[0]} : () }
sub _hash { _is_hash_ref($_[0]) ? %{$_[0]} : () }
sub _blessed { ref($_[0]) && UNIVERSAL::can($_[0],'can') }
sub _is_type_of { _blessed($_[1]) && $_[1]->isa($_[0]) }
sub _is_value { $_[0] || length($_[0]) }
sub _value_or_else {
	my $default = shift;
	my $key = shift;
	my $value = shift;
	given (ref($key)) {
		when ('HASH') {
			return _hash $key;
		}
		when ('ARRAY') {
			return _array $key;
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
					if (_is_code_ref($default)) {
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
	$_[2]->() if _is_code_ref $_[2];
	if (! _is_value($value)) {
		return _is_code_ref($default) ? 
			$default->() : 
			$default;
	}
	if (looks_like_number($default) && !looks_like_number($value)) {
		return $default;
	}
	my @values = split(/$_separator[1]/, $value);
	return @values > 1 ? 
		@values : 
		$values[0];
}
sub _getenv_once {
	my $key = _win32() ? uc($_[0]) : $_[0];
	_getenv @_[0,1], sub {
		delete $ENV{$key}
	}
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
	my $len = _value_or_else 8, shift;
	@_ = ('a'..'z', 0..9) if ! @_;
	join '', @_[ map { rand @_ } 1 .. $len ]
}
sub _index_of {
	my $value = shift;
	my @array = @_;
	my $i = 0;
	++$i until $i > $#array || (defined($value) ? $array[$i] eq $value : !defined($array[$i]));
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
	my ($haystack,$needle,$align) = @_;
	given ($align) {
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
	} else {
		open my $in, '<:encoding(UTF-8)', $file or die "Can't open file \"$file\" : $!\n";
		{
			local $/;    # slurp mode
			$ref = eval <$in>;
		}
		close $in;
	}
	return $ref;
}
sub _implicit {
	my $file = _make_sure_file(catfile(dirname(__FILE__), ".implicit"));
	my %implicits = _hash(_persist $file);
	return %implicits if ! @_;
	return $implicits{$_[-1]} if @_ % 2;
	my %items = @_;
	$implicits{$_} = $items{$_} foreach (keys %items);
	_persist $file, \%implicits;
}
sub _visit_sorted_tree {
	my %hash = %{$_[0]};
	my $func = $_[1];
	my $prefix = _value_or_else '', $_[2];
	foreach my $key (sort keys %hash) {
		my $path = $prefix ? join($_separator[2],$prefix,$key) : $key;
		my $value = $hash{$key};
		if (_is_hash_ref($value)) {
			_visit_sorted_tree($value, $func, $path) 
		} else {
			$func->($path, $value)
		}
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
#	returns	($name,$path,$suffix)
}
sub _files_in_dir {
	my $dir = shift;
	my $fullpath = shift;
	return () if ! _dir_exists($dir);
	opendir(DIR, $dir) || die "Can't open directory : $!\n";
	my @list = grep ! /^\.\.?$/, readdir(DIR);
	closedir(DIR);
	$fullpath ?
		map { catfile $dir, $_ } @list :
		@list;
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
sub _make_sure_dir {
	my $dir = shift;
	if (! _dir_exists $dir) {
		mkdir $dir || die "Can't make directory : $!\n"; 
	}
	$dir
}
sub _make_sure_file {
	my $file = shift;
	unlink $file if shift;
	if (! _file_exists $file) {
		my @parts = _fileparse $file;
		_make_sure_dir $parts[1];
		open my $fh, ">", $file || die "Can't open file : $!\n";
		close $fh;
	}
	$file
}
sub _contents_of_file {
	my $file = shift;
	my $encode;
	if (_is_array_ref($file)) {
		$encode = $file->[1];
		$file = $file->[0];
	}
	my $chars = shift;
	open my $fh, '<' . ($encode ? ":$encode" : ''), $file || die "Can't open file : $!\n";
	my $contents;
	if (_value_or_else(0, $chars) > 0) {
		read $fh, $contents, $chars
	} else {
		no warnings;
		local $/ = undef;    # slurp mode
		$contents = <$fh>;
	}
	close $fh;
	$contents
}
sub _is_sqlite_file {
	my $file = shift;
	my $header = _contents_of_file $file, 16;
	_string_contains $header, 'SQLite format 3', 0
}
sub _contents_to_file {
	my $file = shift;
	my ($encode,$append);
	if (_is_array_ref($file)) {
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
	join $sep, @extract
}
sub _diagnostic {
	my $msg = shift;
	my $diag = _make_sure_dir catdir(tmpdir, "diag");
	mkdir $diag unless -d $diag;
	$diag = new File::Temp( DIR => $diag, UNLINK => 0 );
	_contents_to_file [$diag,'encoding(UTF-8)'], $msg;
	$diag
}
sub _temp_filename {
	my $template = shift;
	my $dir = shift;
	$dir = File::Temp->newdir( CLEANUP => 0 ) if not $dir;
	$dir = _make_sure_dir $dir;
	return new File::Temp( TEMPLATE => $template, DIR => $dir, UNLINK => 0 )->filename;
}
sub _transient_file {
#	return "/tmp/trans/test";
	my $dir = _make_sure_dir "/tmp/trans";
	return new File::Temp( DIR => $dir, UNLINK => 1 );
}
sub _call {
	my $func = shift;
	given (ref $func) {
		when ('CODE') {
			$func->(@_);
		}
		when ('ARRAY') {
			my @array = @$func;
			$func = shift(@array);
			_call($func, @array, @_);
		}
	}
}
my @fstack;
sub _capture_output {
	my $func = shift;
	my $fname = shift;
	if (!$fname) {
		$fname = _transient_file->filename;
	}
	my $fhandle;
	open $fhandle, '>:encoding(UTF-8)', "$fname" || die "Can't open file : $!\n";
	select($fhandle);
	push @fstack, $fhandle;
	_call $func;
	pop @fstack;
	@fstack ? select($fstack[-1]) : select(STDOUT);
	close $fhandle;
	return _contents_of_file($fname);
}
sub _perform {
	exec @_;
}
sub _perform_2 {
	no warnings 'once';
	my $command = _escapeDoubleQuotes "@_";
	$command = "perl -e 'exec \"$command\"'";
	my $pid = open3(\*CHLD_IN, \*CHLD_OUT, \*CHLD_ERR, $command) or die "open3() failed $!";
	while (<CHLD_OUT>) {
	    print;
	} 
}
sub _capture_output_2 {
	my $command = shift;
	my $dir = "/tmp/out";
	my $file = _temp_filename 'outXXXX', $dir;
	_capture_output [\&_perform_2, $command], $file;
}
sub _check_output {
	my $func = shift;
	my @rgx = @_;
	my $output = _capture_output($func);
	foreach my $rg (@rgx) { 
		ok($output =~ $rg, $output)
	}
}
sub _clipboard {
	my $set = @_ > 0;
	my $cmd = sprintf "xclip -selection clipboard -%s", $set ? 'i' : 'o';
	my $pid = open3(\*CHLD_IN, \*CHLD_OUT, \*CHLD_ERR, "$cmd") or die "open3() failed $!";
	if ($set) {
		print CHLD_IN "@_";
	} else {
		while (<CHLD_OUT>) {
		    print;
		} 
	}
	use Time::HiRes;
	Time::HiRes::sleep(0.5);	
	waitpid($pid, 1);
}
sub _get_clipboard {
	_capture_output sub{ _clipboard }
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
sub _object_from_XML {
	my $fname = shift;
	system("xmllint --noout \"$fname\"") and die $!;
	my $xml = _contents_of_file($fname);
	local $SIG{__WARN__} = sub { };
	my $XML2JSON = XML::XML2JSON->new();
	return $XML2JSON->xml2obj($xml);
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
sub _text_menu_extension {
	my $widget = shift;
	my %menu_items = @_;
	my $text_widget = $widget->Subwidget('scrolled');
	if (%menu_items) {
		my $menu = $text_widget->menu;
		$menu->separator;
		foreach (keys %menu_items) {
			$menu->command(
				-label => $_, 
				-command => [$menu_items{$_},$_,$widget->parent,$widget]
			)
		}
	}
	$text_widget
}
sub _text_info {
	my $top = _value_or_else sub{_tkinit(1)}, shift;
	$top->title(_value_or_else('', shift));
	my $text = shift;
	my %menu_items = @_;
	require Tk::ROText;
	my $widget = $top->Scrolled("ROText", -scrollbars => 'oe');
	$widget->pack(-side => 'left', -fill => 'both', -expand => 1);
	$widget->insert('end', $text);
	_text_menu_extension($widget, %menu_items);
	_center_window $top;
}
sub _text_dialog {
	my $win = _value_or_else sub{_tkinit(1)}, shift;
	my $dim = shift;
	my $title = shift;
	my $text = shift;
	my $buttons = ['OK','Cancel'];
	given (@_ % 2 ? shift : 0) {
		when (1) {
			splice @$buttons, 1, 0, 'To clipboard';
		}
	}
	my %menu_items = @_;
	my $dlg = $win->DialogBox(
		-title => $title,
		-buttons => $buttons);
	$dlg->bind('<KeyPress-Return>', sub {});
	my $text_widget = sub {
		my $parent = shift;
		my $text = shift;
		my @params = (
			-background => '#ffffff', 
			-scrollbars => 'osoe',
		);
		if (_is_array_ref($dim) && @{$dim} > 1) {
			push @params, (-width, $dim->[0], -height, $dim->[1]);
		}
		my $widget = $parent->Scrolled("Text", @params);
		$widget->pack(-fill => 'both', -expand => 1);
		$widget->insert('end', $text);
		_text_menu_extension($widget, %menu_items)
	};
	my $book;
	my @widgets;
	if (_is_array_ref $text) {
		use Tk::NoteBook;
		$book = $dlg->NoteBook()->pack( -fill=>'both', -expand=>1 );
		my $i = 0;
		foreach (_array($text)) {
			my $widget;
			my $page = $book->add($i, 
				-label => $i++, 
				-raisecmd => sub {$widget->tagAdd('sel', '1.0', 'end -1 chars')} 
			);
			$widget = &$text_widget($page, $_);
			push @widgets, $widget;
		}
	} else {
		push @widgets, &$text_widget($dlg, $text);
	}
show:
	given ($dlg->Show) {
		when ('To clipboard') {
			my $page = $book->page_widget($book->raised);
			my @kids = $page->children;
			my $text_widget = $kids[0]->Subwidget('scrolled');
			_clipboard $text_widget->getSelected();
			goto show
		}
		when ('OK') {
			if (_is_array_ref $text) {
				my $i = 0;
				foreach (@widgets) {
					$text->[$i++] = $_->Contents;
				}
				return 1
			}
			return [$dlg->cget(-title), $widgets[0]->Contents]
		}
	}
	undef
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
sub _delete_popup_menu {
	my $win = shift;
	my $menu = shift;
	$win->bind('<3>', sub{});
	$win->bind('<1>', sub{});
	$menu->destroy
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
		if ($label eq '-') {
			$menu->separator;
			next
		}
		$menu->add('command', -label => $label, -command => $command);
	}
	$menu
}
sub _refresh_menu_button_items {
	my $win = shift;
	my $title = shift;
	my $btn = shift;
	my $command = shift;
	my @items = @_;
	if (@items) {
		my $menu = $btn->cget('-menu');
		$menu->delete(0, 'end');
		foreach my $item (@items) {
			$menu->command(-label => $item, 
				-command => sub{
					_call [$command, $item]
				}
			)
		}
	} else {
		use Tk::Balloon;
		my $ba = $win->Balloon(-background=>'yellow');
		$ba->attach($btn,-initwait => 0,-balloonmsg => sprintf "no %s items", $title);
	}
}
sub _install_menu_button {
	my $win = shift;
	my $title = shift;
	my $postcommand = shift;
	my $command = shift;
	my @items = @_;
	my $btn;
	$btn = $win->Menubutton( 
		-text => $title, 
		-tearoff => 0,
	);
	$btn->menu->configure(
		-postcommand => $postcommand
	);
	_refresh_menu_button_items $win, $title, $btn, $command, @items;
	$btn
}
our $_entries = catfile dirname(dirname  __FILE__), ".entries";
our $_history = catfile dirname(dirname  __FILE__), ".history";
1;

