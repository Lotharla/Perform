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
use DBD::SQLite;
use Test::More;
use Tk;
use Exporter::Easy (
	OK => [ qw(
		dump 
		pp
		looks_like_number
		dirname 
		basename
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
		_chomp
		_prompt
		_surround
		_has_whitespace
		_split_on_whitespace
		_is_blessed
		_is_type_of
		_is_code_ref
		_is_array_ref
		_is_hash_ref
		_array
		_hash
		_boolean
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
		_xselection
		_clipboard
		_get_clipboard
		_persist
		_implicit
		_visit_sorted_tree
		_iterate_sorted_values
		_fileparse
		_filename_extension
		_files_in_dir
		_dir_exists
		_file_exists
		_realpath
		_make_sure_dir
		_make_sure_file
		_contents_to_file
		_contents_of_file
		_is_sqlite_file
		_connect
		_make_sure_table
		_tables
		_delete_record
		_extract_from
		_diagnostic
		_temp_filename
		_transient_file
		_call
		_capture_output
		_check_output
		_terminalize
		_perform
		_perform_2
		_result_perform
		_binsearch_alpha
		_binsearch_numeric
		_is_xml_file
		_xml_object
		_is_loaded
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
		_text_edit
		_text_dialog
		_file_types
		_ask_file
		_ask_directory
		_balloon
		_button
		_menu
		_create_popup_menu
		_delete_popup_menu
		_install_menu
		_refresh_menu_button_items
		_install_menu_button
		_win32
		_transit
		_dimension
		_top_widget
		_widget_info
		_find_widget
		$_entries $_history $_words
		@_inputs
		_set_inputs
		_inputs_title
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
sub _chomp {
	my $var = shift;
	chomp $var if $var;
	return $var
}
sub _prompt {
	print @_;
	chomp(my $answer = <>);
	return $answer;
}
sub _surround {
	my $surrounder = shift;
	my ($start,$end);
	given ($surrounder) {
		when (1) { ($start,$end) = ('\'','\''); }
		when (2) { ($start,$end) = ('"','"'); }
		when (3) { ($start,$end) = ('(',')'); }
		when (4) { ($start,$end) = ('[',']'); }
		when (5) { ($start,$end) = ('{','}'); }
		default { ($start,$end) = _value_or_else(sub{('','')}, $surrounder); }
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
sub _boolean { $_[0] ? 1 : 0 }
sub _is_blessed { ref($_[0]) && UNIVERSAL::can($_[0],'can') }
sub _is_type_of { _is_blessed($_[1]) && $_[1]->isa($_[0]) }
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
			given (ref $value) {
				when ('ARRAY') {
					my @value = @{$value};
					return defined $value[$key] ? $value[$key] : _value_or_else($default);
				}
				when (_eq 'HASH' || _is_blessed($value)) {
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
	@_ = ('a'..'z', 0..9) unless @_;
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
	return () unless @array;
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
			return _boolean $haystack =~ /^\Q$needle\E/;
		}
		when (-1) {
			return _boolean $haystack =~ /\Q$needle\E$/;
		}
		default {
			return _boolean $haystack =~ /\Q$needle\E/;
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
	while(-1 != ( my $i = rindex $haystack,$needle )) {
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
			last unless $r;
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
			return $input unless defined($y);
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
	my %hash = _hash(_persist $file);
	return %hash unless @_;
	if (@_ < 2) {
		my $key = shift;
		if (_is_array_ref $key) {
			my @keys = _array $key;
			for (@keys) {
				return $hash{$_} if exists $hash{$_}
			}
			return undef
		}
		return $hash{$key}
	}
	my %items = @_;
	$hash{$_} = $items{$_} foreach (keys %items);
	_persist $file, \%hash;
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
sub _filename_extension {
	my $file = shift;
	return '' unless $file;
	my @parts = _fileparse $file;
	$parts[2] =~ /^\./ 
		? substr($parts[2], 1) 
		: $parts[2]
}
sub _files_in_dir {
	my $dir = shift;
	my $fullpath = shift;
	return () unless _dir_exists($dir);
	opendir(DIR, $dir) || die "Can't open directory : $!\n";
	my @list = grep ! /^\.\.?$/, readdir(DIR);
	closedir(DIR);
	$fullpath ?
		map { catfile $dir, $_ } @list :
		@list;
}
sub _dir_exists {
	my $dir = shift;
	$dir && -d $dir
}
sub _file_exists {
	my $file = shift;
	$file && -f $file
}
sub _realpath {
	my $path = _value_or_else '', shift;
	$path =~ s{
	    	^ ~ # find a leading tilde
	    	( # save this in $1
	    		[^/] # a non-slash character
	    			* # repeated 0 or more times (0 means me)
    	)
    	}{
			$1
    			? (getpwnam($1))[7]
    			: ( $ENV{HOME} || $ENV{LOGDIR} )
    	}ex;
	$path
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
	my $func = shift;
	open my $fh, '<' . ($encode ? ":$encode" : ''), $file || die "Can't open file : $!\n";
	my $contents;
	if (_value_or_else(0, $chars) > 0) {
		read $fh, $contents, $chars
	} elsif (_is_code_ref $func) {
		while (<$fh>) {
			last unless _call([$func, $_]) 
		}
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
sub _connect {
	my $dbfile = shift;
	DBI->connect("DBI:SQLite:dbname=$dbfile", '', '',
	    {
	        RaiseError  => 1,
	        PrintError  => 0,
	    }
	);
}
sub _make_sure_table {
	my $dbfile = shift;
	my $table = shift;
	my @definition;
	push @definition, shift . ' ' . shift while (@_ > 1);
	my $definition = join ', ', @definition;
	my $dbh = _connect $dbfile;
	$dbh->do("CREATE TABLE IF NOT EXISTS $table ($definition)");
	$dbh->disconnect;
}
sub _tables {
	my @tables;
	my $dbfile = shift;
	if (_is_sqlite_file $dbfile) {
		my $dbh = _connect($dbfile);
		my $stmt = qq(SELECT name,sql FROM sqlite_master WHERE type = 'table');
		my $sth = $dbh->prepare( $stmt );
		$sth->execute() or die $DBI::errstr;
		while (my @row = $sth->fetchrow_array()) {
			push @tables, $row[0];
		}
		$dbh->disconnect;
	}
	@tables
}
sub _delete_record {
	my $dbfile = shift;
	my $table = shift;
	my $where = shift;
	if (_is_sqlite_file $dbfile) {
		my $dbh = _connect $dbfile;
		my $del = $dbh->prepare("DELETE FROM $table WHERE $where");
		$del->execute or die $dbh->errstr;
		$dbh->disconnect;
	}
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
	$file
}
sub _extract_from {
	my $contents = shift;
	$contents = _file_exists($contents) ? _contents_of_file($contents) : $contents;
	my $rex = _value_or_else '', shift;
	my @extract = $contents =~ /$rex/g;
	my $sep = looks_like_number($_[0]) ? $_separator[$_[0]] : $_[0];
	return @extract unless $sep;
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
			$func->(@_)
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
sub _escapeDoubleQuotes {
	my $string = shift;
	$string =~ s/\"/\\"/g;
	$string
}
sub _terminalize {
	my $output = _flatten $_[0];
	$output = _escapeDoubleQuotes $output;
	$output = "bash -c '" . $output . " 2>&1 | less'";
	my $terminal = _chomp(`gconftool-2 -g /desktop/gnome/applications/terminal/exec`);
	return _combine( "$terminal", "-t", sprintf("\"%s\"", $output), "-e", "\"$output\"" );
}
sub _perform {
	use Try::Tiny;
	my @args = @_;
	try {
		exec @args or die $!;
	} catch {
        _text_info(undef, "Error in \'exec @args\'", "$_");
	};
}
sub _perform_2 {
	no warnings 'once';
	my $command = _escapeDoubleQuotes "$_[0]";
	$command =~ s/\$(\w+)/\$ENV{'$1'}/g;
	$command = "env perl -e 'exec \"$command\"'";
	my $precommand = $_[1];
	$command = _combine($precommand, $command) if $precommand;
	my $pid = open3(\*CHLD_IN, \*CHLD_OUT, \*CHLD_ERR, $command) or die "open3() failed $!";
	while (<CHLD_OUT>) {
	    print;
	} 
	while (<CHLD_ERR>) {
	    print;
	} 
}
sub _result_perform {
	my $dir = "/tmp/out";
	my $file = _temp_filename 'outXXXX', $dir;
	_capture_output [\&_perform_2, @_], $file;
}
sub _check_output {
	my $func = shift;
	my $output = _capture_output($func);
	foreach (@_) { 
		ok($output =~ $_, $output)
	}
}
sub _xselection {
	my $type = shift;
	my $set = @_ > 0;
	my $cmd = sprintf "xclip -selection $type -%s", $set ? 'i' : 'o';
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
sub _clipboard {
	_xselection 'clipboard', @_
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
sub _is_xml_file {
	my $file = shift;
	! system("xmllint --noout \"$file\" 2>/dev/null");
}
sub _xml_object {
	my $file = shift;
	die $! unless _is_xml_file $file;
	my $xml = _contents_of_file($file);
	local $SIG{__WARN__} = sub { };
	my $XML2JSON = XML::XML2JSON->new();
	return $XML2JSON->xml2obj($xml);
}
sub _is_loaded {
    (my $file = shift) =~ s/::/\//g;
    $file .= '.pm';
    grep { $_ eq $file } keys %INC
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
	my $mainloop = shift;
	my $callback = shift;
	$win->withdraw; # avoid the jumping window bug 
	$win->Popup;
	$win->OnDestroy($callback) if _is_code_ref $callback;
	if ($mainloop) {
		MainLoop;
	}
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
sub __key_event {
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
sub __key_event_check {
	my $top = shift;
	$top->bind( '<Any-KeyPress>' => sub {__key_event(@_)});
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
	my $widgets = shift;
	my $widget = _value_or_else $widgets,0,$widgets;
	my $parent = _value_or_else $widget->parent,1,$widgets;
	my %menu_items = @_;
	my $text_widget = $widget->Subwidget('scrolled');
	if (%menu_items) {
		my $menu = $text_widget->menu;
		$menu->separator;
		foreach (keys %menu_items) {
			$menu->command(
				-label => $_, 
				-command => [$menu_items{$_},$_,$widget,$parent]
			)
		}
	}
	$text_widget
}
sub _text_window {
	my $mode = shift;
	my $main_loop = 0;
	my $top = _value_or_else sub { $main_loop = 1; _tkinit(1) }, shift;
	$top->title(_value_or_else('', shift));
	my $text = shift;
	my %menu_items = @_;
	require Tk::ROText;
	my $widget = $top->Scrolled($mode ? "Text" : "ROText", -scrollbars => 'oe');
	$widget->pack(-side => 'left', -fill => 'both', -expand => 1);
	$widget->insert('end', $text);
	my $text_widget = _text_menu_extension($widget, %menu_items);
	_center_window $top, $main_loop,
		sub { 
			$text = $text_widget->Contents unless $main_loop
		};
	$text
}
sub _text_info {
	_text_window 0, @_
}
sub _text_edit {
	_text_window 1, @_
}
sub _text_dialog {
	my $win = _value_or_else sub{_tkinit(1)}, shift;
	my $dim = shift;
	my $title = shift;
	my $text = shift;
	my %menu_items = @_;
	my $buttons = ['OK','Cancel'];
	my $dlg = $win->DialogBox(
		-title => $title,
		-buttons => $buttons);
	$dlg->bind('<KeyPress-Return>', sub {});
	my $book;
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
		_text_menu_extension([$widget,$book], %menu_items)
	};
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
	given ($dlg->Show) {
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
				my %hash = _hash $_[0];
				my @array = _array $_[1];
				my %flip = _flip_hash(\%hash);
				foreach (keys %flip) {
					next if @array && _index_of($_, @array) < 0;
					my $type = [$_, $flip{$_}];
					if (@array) {
						unshift(@types, $type);
					} else {
						push(@types, $type);
					}
				}
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
	my $save = looks_like_number $_[-1] ? $_[-1] : 0;
	my $top = _value_or_else sub{_tkinit(1)}, shift;
	my $default = $save ? "Save" : "Open";
	my $title = _value_or_else $default, shift;
	my $file = shift;
	my $multiple = _is_array_ref($file);
	$file = $file->[0] if $multiple;
	$file = _implicit [$title,$default] unless $file;
	my @types = _array(shift);
	@types = _file_types unless @types;
	if (@types == 1 && _win32()) {
		push @types, @types;
	}
	my $dir = dirname(_value_or_else abs_path($0), $file);
	$file = length($file) ? basename($file) : '';
	$file = $save
		? $top->getSaveFile(
			-title => $title,
			-initialdir => $dir,
			-initialfile => $file,
			-filetypes => \@types)
		: $top->getOpenFile(
			-title => $title,
			-initialdir => $dir,
			-initialfile => $file,
			-filetypes => \@types,
			-multiple => $multiple);
	_implicit $title, $file, $default, $file if $file;
	$file
}
sub _ask_directory {
	my $top = _value_or_else sub{_tkinit(1)}, shift;
	my $title = _value_or_else 'Directory', shift;
	my $dir = _value_or_else sub{_implicit [$title, 'Directory']}, shift;
	$dir = _value_or_else dirname(abs_path $0), $dir;
	$dir = $top->chooseDirectory(
		-title => $title,
		-initialdir => $dir);
	_implicit $title, $dir, 'Directory', $dir if $dir;
	$dir
}
sub _balloon {
	my ($win,$wgt) = @_;
	use Tk::Balloon;
	$win->Balloon(
		-background => _value_or_else('white',3,\@_)
	)->attach($wgt,
		-initwait => 0,
		-balloonmsg => _value_or_else('',2,\@_)
	)
}
sub _button {
	my $text = _value_or_else('',1,\@_);
	my $tooltip = _is_array_ref $text;
	if ($tooltip) {
		$tooltip = _value_or_else('',1,$text);
		$text = _value_or_else('',0,$text);
	}
	my $btn = $_[0]->Button(
		-text => $text, 
		-command => _value_or_else(sub{},2,\@_)
	)->grid(
		-row => _value_or_else(0,3,\@_), 
		-column => _value_or_else(0,4,\@_), 
		-padx => _value_or_else(10,5,\@_), 
		-pady => _value_or_else(5,6,\@_));
	_balloon $_[0], $btn, $tooltip if $tooltip;
	$btn
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
		_balloon $win, $btn, sprintf("no '%s' items", $title), 'yellow';
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
sub _top_widget {
	my $widget = shift;
	$widget = $widget->parent while $widget->parent;
	$widget
}
sub _widget_info {
	my ($widget, $info) = @_;
	return '' unless $widget;
	given ($info) {
		when ('signature') {
			return _top_widget($widget)->class . $widget->PathName
		}
		when ('basic') {
			return join '|', $widget->PathName, $widget->class
		}
		when ('layout') {
			return join '|', _widget_info($widget, 'basic'), $widget->geometry
		}
		when ('bind') {
			return join '|', _widget_info($widget, 'basic'), $widget->bindDump
		}
		default {
			$info = {} if ! defined $info;
			my $key = _widget_info($widget, 'basic');
			$info->{$key} = {};
			foreach my $kid ($widget->children) {
				_widget_info($kid, $info->{$key})
			}
		}
	}
	$info
}
sub _find_widget {
	my ($ancestor, $path) = @_;
	if (_string_contains($path,'.',0)) {
		return $ancestor if $path eq $ancestor->PathName;
		foreach my $kid ($ancestor->children) {
			my $p = substr($kid->PathName . '.', 0, length($path));
			return _find_widget($kid, $path) 
				if _string_contains($path, $p, 0);
		}
	} else {
		foreach my $kid ($ancestor->children) {
			return $kid if $path eq $kid->name;
		}
	}
	undef
}
sub _transit {
	my $obj = shift;
	my $name = shift;
	my $method = UNIVERSAL::can($obj, $name);
	return $method->($obj, @_) if $method;
	$method
}
sub _dimension {
	my $obj = shift;
	my $name = shift;
	my @dim = @_;
	if (UNIVERSAL::can($obj,'dimension')) {
		@dim = $obj->dimension($name);
	}
	@dim
}
our $_entries = catfile dirname(dirname  __FILE__), ".entries";
our $_history = catfile dirname(dirname  __FILE__), ".history";
our $_words = "/usr/share/dict/words";
our @_inputs = _set_inputs();
sub _set_inputs {
	@_inputs = @ARGV ? @ARGV : _getenv( 'inputs', sub{()} )
}
sub _inputs_title {
	my $title = _value_or_else '',shift;
	$title .=  $_separator[0];
	if (@_inputs) {
		$title .= "on " . ($#_inputs > 0 ? scalar(@_inputs) . " given items" : "'$_inputs[0]'");
	}
	$title
}
1;

