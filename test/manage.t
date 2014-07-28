#!/usr/bin/env perl
use diagnostics; # this gives you more debugging information
use warnings;    # this warns you of bad practices
use strict;      # this prevents silly errors
use feature qw(say switch);
use Test::More qw( no_plan ); # for the is() and isnt() functions
BEGIN { 
	$| = 1;	#	autoflush on
}
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path $0);
use Manage::PersistHash;
use Manage::Utils qw(
	dump pp
	catfile
	catdir
	tmpdir
	@_separator
	$_whitespace 
	_has_whitespace 
	_split_on_whitespace 
	_value_or_else 
	_is_value
	_surround
	_getenv
	_setenv
	_chomp 
	_combine 
	_flatten
	_flip_hash 
	_binsearch_numeric
	_capture_output 
	_capture_output_2
	_check_output 
	_file_exists
	_dir_exists
	_files_in_dir
	_transientFile 
	_file_types 
	_contents_of_file
	_make_sure_file
	_tkinit 
	_ask_file
	_message 
	_now
	_extract_from
	_object_from_XML
	_string_contains
	_rndstr
	_index_of
	$_entries
	_diagnostic
	_call
	_array
	_hash
);
use Manage::Resolver qw(
	is_dollar has_dollar dollar_amount make_dollar 
	make_value
	get_dollars set_dollars detect_dollar 
	@given 
	given_title
	place_given
	devels
);
use Manage::Alias qw(
	resolve_alias 
	update_alias
);
use Manage::Assoc qw(
	@assoc_file_types 
	assoc_file_types 
	find_assoc
	update_assoc
);
my $file = "/tmp/test";
open FILE, ">$file";
select FILE; # print will use FILE instead of STDOUT
say "Hello, world"; # goes to FILE
select STDOUT; # back to normal
say "Goodbye, girl"; # goes to STDOUT
open FILE, "<$file";
print <FILE>;
close FILE;
my $words = "IT works";
sub _say { 
	say(@_);
}
my $tale = _capture_output([\&_say, $words]);
chomp($tale);
is($tale, $words);
sub my_words { 
	print $words;
}
_check_output(\&my_words, qr/^IT/, qr/.ork.$/);
my @parts = split(/$_whitespace/, "", 2);
is @parts, 0;
@parts = split(/$_whitespace/, " ", 2);
is @parts, 2;
@parts = split(/$_whitespace/, " ", 0);
is @parts, 0;
@parts = _split_on_whitespace(join ("\t", ("AA", "BB", "cc")));
is @parts, 2;
ok $parts[0] =~ /^A.$/;
ok $parts[1] =~ /^B/;
ok $parts[1] =~ /c$/;
my $didnt = "I didn't do it";
@parts = _split_on_whitespace($didnt, 0);
is @parts, 4;
my %samples = ( 11 => "\$11", '2:dir' => "\${2:dir}", "D'oh" => "\${D'oh}", $didnt => "\${$didnt}", );
is make_dollar($_), $samples{$_}, _surround(['_','_'],$_) foreach keys %samples;
foreach (values %samples) { 
	ok(has_dollar($_) && is_dollar($_), $_) if !_has_whitespace($_) and index($_, "'") < 0 
};
ok has_dollar($_) && !is_dollar($_) && dollar_amount($_)==1 for '$1x1';
ok !has_dollar($_) && !is_dollar($_) && !defined(dollar_amount($_)) for '$x11';
ok has_dollar($_) && !is_dollar($_) && dollar_amount($_) eq 'x' for '${x}11';
ok has_dollar($_) && is_dollar($_) && dollar_amount($_) eq 'x11' for '${x11}';
my %assoc = (
	".pl" => "perl",
	".t" => "perl",
	".html" => "firefox",
	".xml" => "firefox",
	"*.sh" => "bash",
	".java" => "java",
	"build.xml" => "ant",
	"makefile" => "make",
	"Makefile" => "make",
	"GNUmakefile" => "make",
);
@_ = _file_types();
is_deeply \@_, [["All files", '*']];
@_ = _file_types("No files", '');
is_deeply \@_, [["All files", '*'], ["No files", '']];
@_ = _file_types(\%assoc);
is @_, 7;
#dump @_;
#_ask_file _tkinit(0), 'Test', "$ENV{HOME}/work/bin/devel.sh", \@_;
@_ = sort(keys %assoc);
is _value_or_else('', 4, \@_), '.t';
is _value_or_else('x', 10, \@_), 'x';
is _value_or_else(sub{'y'}, 11, \@_), 'y';
%_ = %assoc;
is _value_or_else('', '.t', \%_), 'perl';
is _value_or_else('', 'x', \%_), '';
my %cossa = _flip_hash(\%assoc);
my $acca = { assoc => \%assoc, cossa => \%cossa };
#say pp($acca);
$file = _transientFile();
PersistHash::store($acca, $file);
ok -f $file;
PersistHash::fetch($acca, $file);
is_deeply $acca->{"assoc"}, \%assoc, "assoc";
is_deeply $acca->{"cossa"}, \%cossa, "cossa";	#	32
Manage::Assoc::inject( assoc => \%assoc );
is find_assoc('.xxx'), '';
update_assoc '.xxx', 'XXX';
isnt find_assoc('.xxx'), '';
update_assoc '.xxx';
is find_assoc('.xxx'), '';
my @acca = (1,2);
@_ = _value_or_else(undef, \@acca);
is_deeply \@_, \@acca;
undef $acca;
is_deeply _value_or_else(undef, $acca), $acca;
@acca = _value_or_else(sub{()}, $acca);
is @acca, 0;
@given = qw/I didn't do it/;
is place_given("\$1"), "I";
is place_given("\$0") =~ s/\t/ /gr, $didnt;
my $pattern = "find \$4 -name \"\${FILES}\" -print | xargs grep \"\$2\" 2>/dev/null";
is place_given($pattern), 
	"find it -name \"\" -print | xargs grep \"didn't\" 2>/dev/null";
push @given, '';
is place_given(_combine($pattern, "\$5")), 
	"find it -name \"\" -print | xargs grep \"didn't\" 2>/dev/null\t";
my $term = `gconftool-2 -g /desktop/gnome/applications/terminal/exec`;
isnt $term, "gnome-terminal";
is _chomp($term), "gnome-terminal";
#	42
$pattern = "find \${DIR} -name \"\${FILES}\" -print | xargs grep \"\$123\" 2>/dev/null";
my $temp = {"\${DIR}"=>"xxx","\${FILES}"=>"yyy","\$123"=>"zzz"};
is(detect_dollar($pattern, sub { $temp->{shift(@_)} }), 
	"find xxx -name \"yyy\" -print | xargs grep \"zzz\" 2>/dev/null");
my $dir = abs_path $0;
@given = ();
push @given, $dir, "**/*.*";
$pattern = "find \${1:dir} -name \"\$2\" -print | xargs grep -e \"\${PATTERN}\" 2>/dev/null";
$dir = dirname $dir;
is place_given($pattern), 
	"find $dir -name \"**/*.*\" -print | xargs grep -e \"\" 2>/dev/null";
ok -d dirname(dirname abs_path $0);
$file = $_entries;
ok -f $file;
{
	tie my %data, "PersistHash", $file;
	my @keys = sort keys(%data);
	is_deeply \@keys, ["__file__","alias","assoc","history","options"];
	PersistHash::store(\%data, $file);
	$temp = PersistHash::fetch({}, $file);
	is_deeply $temp, \%data;	#	50
}
assoc_file_types();
is @assoc_file_types, 6;
foreach my $type (@assoc_file_types) {
	is find_assoc($_), @$type[0] foreach @{@$type[1]};
}
my %alias = (
	ant   => "bash /home/lotharla/work/bin/ant-or-make.sh \"\$1\"",
	bash  => "bash \"\$1\"",
	chmod => {
			   "chmod a+x" => "chmod a+x \"\$1\"",
			   "chmod a-x" => "chmod a-x \"\$1\"",
			 },
);
Manage::Alias::inject( alias => \%alias );
update_alias("chmod|chmod a+x", $didnt);
is resolve_alias("chmod|chmod a+x"), $didnt;
is keys %alias, 3;
update_alias("find|find-in-files", $pattern);
is resolve_alias("find|find-in-files"), $pattern;
is keys %alias, 4;
%alias = ();
update_alias("xxx|xxx-in-files", $didnt);
is resolve_alias("xxx|xxx-in-files"), $didnt;
is keys %alias, 1;
use POSIX qw(tzset);
my %history;
foreach ('Europe/London', 'America/New_York', 'America/Los_Angeles') {
	$ENV{TZ} = $_;
	tzset;
	$history{_now()}=$_;
}
if (%history) {
	my @timeline = sort {$a <=> $b} keys %history;
	if (@timeline > 1) {
		$ENV{TZ} = 'Europe/Berlin';
		tzset;
		my $now = _now;
		$history{$now} = $ENV{TZ};
		is _binsearch_numeric($now, \@timeline), @timeline;
		is _binsearch_numeric($now, \@timeline, 1), 0;
	}
}
my $now = _now;
$file = _transientFile();
sub closure {
	tie my %data, "PersistHash", $file;
	$data{'history'} = {};
	return sub {
		%data = @_ if defined $_[0];
		%data
	};
}
my $closure = closure();
my %data = $closure->();
ok exists($data{'history'});
$data{'history'}->{$now} = 'bla';
ok exists($data{'history'}->{$now});
my %data2 = $closure->();
is $data2{'history'}->{$now}, 'bla';
is _flatten("1\n2\t3"), "1 2 3";
is _combine('1',(2,3)), "1\t2\t3";
ok !_is_value(undef);
ok !_is_value("");
ok _is_value(0);
ok _is_value([]);
ok !_is_value(());
@given=();
ok _is_value(\@given);
_setenv 'given', "xxx";
@given = _getenv 'given';
ok _string_contains given_title('title'), "on 'xxx'", -1;
_setenv 'given', "xxx\nzzz";
@given = _getenv 'given';
ok _string_contains given_title('title'), "on 2 given items", -1;
_setenv 'given', undef;
is _getenv('given', 'x'), 'x';
_setenv 'given', '';
is _getenv('given', 'x'), 'x';
_setenv 'given', 0;
is _getenv('given', 1), 0;		#	!!!
delete $ENV{'given'};
@given = _getenv('given', sub{()});
is @given, 0;
$dir = dirname(dirname abs_path $0);
ok _dir_exists($dir);
$_ = scalar(@_ = _extract_from(dirname(dirname abs_path $0) . "/Manage/Utils.pm", "sub\\s+(\\w+)"));
is $_ / $_, 1;
$file = dirname($dir) . "/bin/devel.sh";
ok _file_exists($file);
ok _extract_from($file, "\\v(\\w+)\\)\\v", " ");
$file = "/home/lotharla/work/Niklas/androidStuff/BerichtsheftApp/build.xml";
ok _file_exists($file);
my $obj = _object_from_XML($file);
isnt $obj->{project}, undef;
#dump $obj;
$file = $obj->{project}->{import}->{"\@file"};
isnt $file, undef, $file;
my @matches;
while ($file =~ /\$\{([^\}]+)\}/g) {
	my @minus = @-;
	my @plus = @+;
	push @matches, [ \@minus, \@plus ];
}
#dump \@matches;
for my $match (@matches) {
	my $name = substr($file,$match->[0]->[1],$match->[1]->[1]-$match->[0]->[1]);
	for my $prop (@{$obj->{project}->{property}}) {
		if ($prop->{"\@name"} && $prop->{"\@name"} eq $name) {
			my $value = $prop->{"\@value"};
			substr($file,$match->[0]->[0],$match->[1]->[0]-$match->[0]->[0],$value);
		}
	}
}
ok $file !~ /\$\{([^\}]+)\}/, $file;
@_ = ('a'..'z', 0..9);
$_ = _rndstr;
is length $_, 8;
ok _index_of($_, @_) > -1 for split '', $_;
$file = _diagnostic "";
ok _make_sure_file $file;
unlink $file;
$dir = catdir tmpdir, "clip";
my $name = "_1000";
$file = catfile $dir, $name;
_make_sure_file $file;
my @files = _files_in_dir($dir);
ok _index_of($name,@files) > -1;
unlink $file;
ok ! _file_exists $file;
ok _dir_exists $dir;
@parts = _array \@files;
is_deeply \@parts, \@files;
sub _dump { 
#	dump(@_);
	@_
}
my $p = \&_dump;
is _call([$p, @files]), @files;
$p = [$p, @files];
is _call([$p, @files]), 2 * @files;
$p = [$p, @files];
is _call([$p, @files]), 3 * @files;
my $doll = "\${1:dir}";
my $a = dollar_amount($doll);
is make_value($a,'x'), 'x';
is make_value($a,$_entries), dirname($_entries);
$doll = "\${*:devels}";
ok has_dollar($doll) && is_dollar($doll);
$a = dollar_amount($doll);
is_deeply $a, ["*","devels"];
ok _string_contains make_value($a,'x'), $_separator[2];
@_ = devels
ok @_ > 1;
is place_given("\$1", @_), $_[0];
=pod
=cut
exit;

