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
	$_whitespace _has_whitespace _split_on_whitespace _value_or_else 
	_chomp _combine _flip_hash  _binsearch_numeric
	_capture_output _check_output _transientFile _file_types 
	_contents_of_file
	_tkinit _ask_file
	_message _now
);
use Manage::Dollar qw(
	isDollar hasDollar dollar_amount make_Dollar 
	get_dollars set_dollars detect_dollar 
	place_given
	@given %dollars
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
_check_output(\&my_words);
our $_whitespace;
my @parts = split(/$_whitespace/, "", 2);
is scalar(@parts), 0;
@parts = split(/$_whitespace/, " ", 2);
is scalar(@parts), 2;
@parts = split(/$_whitespace/, " ", 0);
is scalar(@parts), 0;
@parts = _split_on_whitespace(join ("\t", ("AA", "BB", "cc")));
is scalar(@parts), 2;
ok $parts[0] =~ /^A.$/;
ok $parts[1] =~ /^B/;
ok $parts[1] =~ /c$/;
my $didnt = "I didn't do it";
@parts = _split_on_whitespace($didnt, 0);
is scalar(@parts), 4;
my %samples = ( 11 => "\$11", '1_1' => "\${1_1}", "D'oh" => "\${D'oh}", $didnt => "\${$didnt}", );
is make_Dollar($_), $samples{$_}, $_ foreach keys %samples;
foreach (values %samples) { ok(hasDollar($_) && isDollar($_), $_) 
	if !_has_whitespace($_) and index($_, "'") < 0 };
ok hasDollar($_) && !isDollar($_) && dollar_amount($_)==1 for '$1x1';
ok !hasDollar($_) && !isDollar($_) && !defined(dollar_amount($_)) for '$x11';
ok hasDollar($_) && !isDollar($_) && dollar_amount($_) eq 'x' for '${x}11';
ok hasDollar($_) && isDollar($_) && dollar_amount($_) eq 'x11' for '${x11}';
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
is scalar(@_), 7;
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
is_deeply $acca->{"cossa"}, \%cossa, "cossa";	#	30
Manage::Assoc::set_data ( assoc => \%assoc );
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
is_deeply scalar(@acca), 0;
#_message("xxxyyyzzz","test");
our @given = qw/I didn't do it/;
my $pattern = "find \$4 -name \"\${FILES}\" -print | xargs grep \"\$2\" 2>/dev/null";
is(place_given($pattern), 
	"find it -name \"\${FILES}\" -print | xargs grep \"didn't\" 2>/dev/null");
push @given, '';
#dump \@given;
is(place_given(_combine($pattern, "\$5")), 
	"find it -name \"\${FILES}\" -print | xargs grep \"didn't\" 2>/dev/null\t");
my $term = `gconftool-2 -g /desktop/gnome/applications/terminal/exec`;
isnt $term, "gnome-terminal";
is _chomp($term), "gnome-terminal";
$pattern = "find \${DIR} -name \"\${FILES}\" -print | xargs grep \"\$123\" 2>/dev/null";
my $temp = {"\${DIR}"=>"xxx","\${FILES}"=>"yyy","\$123"=>"zzz"};
is(detect_dollar($pattern, sub { $temp->{shift(@_)} }), 
	"find xxx -name \"yyy\" -print | xargs grep \"zzz\" 2>/dev/null");
$pattern = "find \${DIR} -name \"\${GLOB}\" -print | xargs grep -e \"\${PATTERN}\" 2>/dev/null";
our %dollars;
get_dollars($pattern);
my $dolls = _capture_output(sub{print %dollars});
is_deeply \%dollars, {'${DIR}'=>'DIR', '${GLOB}'=>'GLOB', '${PATTERN}'=>'PATTERN'}, $dolls;
is set_dollars($pattern),
	"find DIR -name \"GLOB\" -print | xargs grep -e \"PATTERN\" 2>/dev/null";
ok -d dirname(dirname abs_path $0);
$file = dirname(dirname abs_path $0) . "/.entries";
ok -f $file;
{
	tie my %data, "PersistHash", $file;
	my @keys = sort keys(%data);
	is_deeply \@keys, ["__file__","alias","assoc","history"];
	PersistHash::store(\%data, $file);
	$temp = PersistHash::fetch({}, $file);
	is_deeply $temp, \%data;
}
our @assoc_file_types;
assoc_file_types();
is scalar(@assoc_file_types), 6;
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
Manage::Alias::set_data ( alias => \%alias );
update_alias("chmod|chmod a+x", $didnt);
is resolve_alias("chmod|chmod a+x"), $didnt;
is keys %alias, 3;
update_alias("find|find-in-files", $pattern);
is resolve_alias("find|find-in-files"), $pattern;
is keys %alias, 4;
use POSIX qw(tzset);
my %history;
foreach ('Europe/London', 'America/New_York', 'America/Los_Angeles') {
	$ENV{TZ} = $_;
	tzset;
	$history{_now()}=$_;
}
if (%history) {
	my @timeline = sort {$a <=> $b} keys %history;
	my $len = scalar(@timeline);
	if ($len > 1) {
		$ENV{TZ} = 'Europe/Berlin';
		tzset;
		my $now = _now;
		$history{$now} = $ENV{TZ};
		is _binsearch_numeric($now, \@timeline), $len;
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
=pod
=cut
exit;

