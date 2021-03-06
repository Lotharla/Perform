#!/usr/bin/env perl
use diagnostics; # this gives you more debugging information
use warnings;    # this warns you of bad practices
use strict;      # this prevents silly errors
no warnings 'experimental';
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
	_is_array_ref
	_surround
	_getenv
	_setenv
	_chomp 
	_combine 
	_flatten
	_flip_hash 
	_binsearch_numeric
	_capture_output 
	_result_perform
	_check_output 
	_file_exists
	_dir_exists
	_files_in_dir
	_transient_file 
	_file_types 
	_contents_of_file
	_contents_to_file
	_make_sure_file
	_tkinit 
	_ask_file
	_message 
	_now
	_extract_from
	_xml_object
	_is_xml_file
	_string_contains
	_rndstr
	_index_of
	$_entries $_history
	_diagnostic
	_call
	_array
	_hash
	_clipboard
	_get_clipboard
	_gt _lt
	_visit_sorted_tree
	_realpath
	_is_loaded
	_connect
	_make_sure_table
	_tables
	@_inputs 
	_inputs_title
);
use Manage::Resolver qw(
	is_dollar has_dollar dollar_amount dollar_attr
	make_dollar 
	make_value
	get_dollars set_dollars detect_dollar 
	place_inputs
	devels
);
use Manage::Alias qw(
	resolve_alias 
	update_alias
	visit_alias_tree
	aliases
);
use Manage::Settings;
my $file = catfile tmpdir, "test";
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
my ($doh,$didnt) = ("D'oh","I didn't do it");
@parts = _split_on_whitespace($didnt, 0);
is @parts, 4;
my %samples = ( 11 => "\$11", '2:dir' => "\${2:dir}", $doh => "\${$doh}", $didnt => "\${$didnt}", );
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
@parts = _file_types();
is_deeply \@parts, [["All files", '*']];
@parts = _file_types("No files", '');
is_deeply \@parts, [["All files", '*'], ["No files", '']];
@parts = _file_types(\%assoc);
is @parts, 7;
@parts = _file_types \%assoc, ["make"];
is @parts, 2;
@parts = _file_types \%assoc, ["bash"];
#say _ask_file _tkinit(0), 'Test', ["$ENV{HOME}/work/bin/devel.sh"], \@parts;
@parts = sort(keys %assoc);
is _value_or_else('', 4, \@parts), '.t';
is _value_or_else('x', 10, \@parts), 'x';
is _value_or_else(sub{'y'}, 11, \@parts), 'y';
%_ = %assoc;
is _value_or_else('', '.t', \%_), 'perl';
is _value_or_else('', 'x', \%_), '';
my %cossa = _flip_hash(\%assoc);
my $acca = { assoc => \%assoc, cossa => \%cossa };
#say pp($acca);
$file = _transient_file();
PersistHash::store($acca, $file);
ok -f $file;
PersistHash::fetch($acca, $file);
is_deeply $acca->{"assoc"}, \%assoc, "assoc";
is_deeply $acca->{"cossa"}, \%cossa, "cossa";
my $aref = \%assoc;
is 'Settings'->find_assoc($aref, '.xxx'), '';
'Settings'->modify_setting($aref, '.xxx', 'XXX');
is 'Settings'->find_assoc($aref, '.xxx'), 'XXX';
'Settings'->modify_setting($aref, '.xxx');
is 'Settings'->find_assoc($aref, '.xxx'), '';
is 'Settings'->find_assoc($aref, 'pom.xml'), 'firefox';
'Settings'->modify_setting($aref, 'pom.xml', 'mvn');
is 'Settings'->find_assoc($aref, 'pom.xml'), 'mvn';
'Settings'->modify_setting($aref, 'pom.xml');
is 'Settings'->find_assoc($aref, 'pom.xml'), 'firefox';
my @acca = (1,2);
@_ = _value_or_else(undef, \@acca);
is_deeply \@_, \@acca;
undef $acca;
is_deeply _value_or_else(undef, $acca), $acca;
@acca = _value_or_else(sub{()}, $acca);
is @acca, 0;
@_inputs = qw/I didn't do it/;
is place_inputs("\$1"), "I";
is place_inputs("\$0") =~ s/\t/ /gr, $didnt;
my $pattern = "find \$4 -name \"\${FILES}\" -print | xargs grep \"\$2\" 2>/dev/null";
is place_inputs($pattern), 
	"find it -name \"\" -print | xargs grep \"didn't\" 2>/dev/null";
push @_inputs, '';
is place_inputs(_combine($pattern, "\$5")), 
	"find it -name \"\" -print | xargs grep \"didn't\" 2>/dev/null\t";
my $term = `gconftool-2 -g /desktop/gnome/applications/terminal/exec`;
isnt $term, "gnome-terminal";
is _chomp($term), "gnome-terminal";
$pattern = "find \${DIR} -name \"\${FILES}\" -print | xargs grep \"\$123\" 2>/dev/null";
my $temp = {"\${DIR}"=>"xxx","\${FILES}"=>"yyy","\$123"=>"zzz"};
is(detect_dollar($pattern, sub { $temp->{shift(@_)} }), 
	"find xxx -name \"yyy\" -print | xargs grep \"zzz\" 2>/dev/null");
my $dir = abs_path $0;
@_inputs = ();
push @_inputs, $dir, "**/*.*";
$pattern = "find \${1:dir} -name \"\$2\" -print | xargs grep -e \"\${PATTERN}\" 2>/dev/null";
$dir = dirname $dir;
is place_inputs($pattern), 
	"find $dir -name \"**/*.*\" -print | xargs grep -e \"\" 2>/dev/null";
ok -d dirname(dirname abs_path $0);
$file = $_entries;
ok -f $file;
{
	tie my %data, "PersistHash", $file;
	my @keys = sort keys(%data);
	is_deeply \@keys, ["__file__","alias","assoc",'environ','favor',"options"];
	Settings->apply('Environment', %data);
	$words = Settings->to_string('Environment');
	ok $words, $words;
	PersistHash::store(\%data, $file);
	$temp = PersistHash::fetch({}, $file);
	is_deeply $temp, \%data;
}
my @types = @{Settings->apply('Associations', assoc => \%assoc)};
is @types, 6;
foreach my $type (@types) {
	is 'Settings'->find_assoc($aref, $_), @$type[0] foreach @{@$type[1]};
}
my %alias = ();
Manage::Alias::inject( alias => \%alias );
update_alias("xxx|x-in-files", $doh);
is keys %alias, 1, 'alias';
is keys %{$alias{"xxx"}}, 1;
is resolve_alias("xxx|x-in-files"), $doh;
update_alias("xxx|x-in-files|yz", $didnt);
is keys %{$alias{"xxx"}}, 1;
is keys %{$alias{"xxx"}->{"x-in-files"}}, 2;
@parts = ();
visit_alias_tree sub {
	push @parts, $_[0];
};
@parts = sort @parts;
is @parts, 2;
is resolve_alias($parts[0]), $doh;
is resolve_alias($parts[1]), $didnt;
%alias = (
	ant   => "bash ~/work/bin/ant-or-make.sh \"\$1\"",
	bash  => "bash \"\$1\"",
	chmod => {
			   "chmod a+x" => "chmod a+x \"\$1\"",
			   "chmod a-x" => "chmod a-x \"\$1\"",
			 },
	devel => { "\${*:devels}" => "~/work/bin/devel.sh \$1" },
);
update_alias("chmod|chmod a+x", $didnt);
is resolve_alias("chmod|chmod a+x"), $didnt;
is keys %alias, 4;
update_alias("find|find-in-files", $pattern);
is resolve_alias("find|find-in-files"), $pattern;
is keys %alias, 5;
ok ! _is_loaded "Manage::Favor";
ok _is_loaded "Manage::Alias";
Manage::Alias::inject( alias => \%alias );
@parts = aliases;
is @parts, 5;
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
{
	$file = _transient_file();
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
}
is _flatten("1\n2\t3"), "1 2 3";
is _combine('1',(2,3)), "1\t2\t3";
ok !_is_value(undef);
ok !_is_value("");
ok _is_value(0);
ok _is_value([]);
ok !_is_value(());
@_inputs=();
ok _is_value(\@_inputs);
_setenv 'inputs', "xxx";
@_inputs = _getenv 'inputs';
ok _string_contains _inputs_title('title'), "on 'xxx'", -1;
_setenv 'inputs', "xxx\nzzz";
@_inputs = _getenv 'inputs';
ok _string_contains _inputs_title('title'), "on 2 given items", -1;
_setenv 'inputs', undef;
is _getenv('inputs', 'x'), 'x';
_setenv 'inputs', '';
is _getenv('inputs', 'x'), 'x';
_setenv 'inputs', 0;
is _getenv('inputs', 1), 0;		#	!!!
delete $ENV{'inputs'};
@_inputs = _getenv('inputs', sub{()});
is @_inputs, 0;
$dir = dirname(dirname abs_path $0);
ok _dir_exists($dir);
$_ = scalar(@_ = _extract_from(dirname(dirname abs_path $0) . "/Manage/Utils.pm", "sub\\s+(\\w+)"));
is $_ / $_, 1;
$file = dirname($dir) . "/bin/devel.sh";
ok _file_exists($file);
ok _extract_from($file, "\\v(\\w+)\\)\\v", " ");
$file = catfile tmpdir, "test";
{
	use autodie;
	open my $fh, ">", "$file";
	my ($img,$type,$expansion,$keyword,$color,$linkcolor,$kickercolor,$cost,$strength,$health) = 
		(";-)","unregimented","contracted","lock","green","red","blue",'$0.00',"humungous","excellent");
	print $fh <<"END";
<card>
    <img>$img</img>
    <type>$type</type>
    <expansion>$expansion</expansion>
    <keyword>$keyword</keyword>
    <color>$color</color>
    <linkcolor>$linkcolor</linkcolor>
    <kickercolor>$kickercolor</kickercolor>
    <cost>$cost</cost>
    <strength>$strength</strength>
    <health>$health</health>
</card>
END
	close $fh;
}
ok _is_xml_file $file;
$file = "/home/lotharla/work/Niklas/androidStuff/BerichtsheftApp/build.xml";
ok _file_exists($file);
my $obj = _xml_object($file);
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
	@_
}
my $p = \&_dump;
is _call([$p, @files]), @files;
$p = [$p, @files];
is _call([$p, @files]), 2 * @files;
$p = [$p, @files];
is _call([$p, @files]), 3 * @files;
my $home = glob('~');
my $doll = "\${1:dir}";
my $a = dollar_amount($doll);
is_deeply $a, [1,'dir'];
is make_value($a,'~'), $home;
is make_value($a,$_entries), dirname($_entries);
$doll = "\${2:file}";
$a = dollar_amount($doll);
is_deeply $a, [2,'file'];
is make_value($a,'~'), $home;
is make_value($a,$_entries), $_entries;
$doll = "\${*:devels}";
ok has_dollar($doll) && is_dollar($doll);
$a = dollar_amount($doll);
is_deeply $a, ["*","devels"];
ok _string_contains make_value($a,'x'), $_separator[2];
@_ = devels
ok @_ > 1;
is place_inputs("\$1", @_), $_[0];
_clipboard $didnt;
is _get_clipboard, $didnt, 'clipboard';
ok !has_dollar($_) && !is_dollar($_) && !dollar_amount($_) && !dollar_attr($_) for '$ANT_HOME';
ok has_dollar($_) && is_dollar($_) && dollar_amount($_)==42 && !dollar_attr($_) for '$42';
ok has_dollar($_) && !is_dollar($_) && dollar_amount($_)==42 && !dollar_attr($_) for '$42:answer';
ok has_dollar($_) && is_dollar($_) && _is_array_ref(dollar_amount $_) && dollar_attr($_) for '${42:answer}';
ok _lt '42' for '33';
ok _gt '42' for '_33';
$file = catfile tmpdir, ".history";
unlink $file;
{
	tie my %data, "PersistHash", $file, 1;
	my @keys = sort keys(%data);
	is_deeply \@keys, ["__file__","hash"];
	$now = _now;
	$data{hash}->{$now} = $doh;
	$data{hash}->{1+$now} = $didnt;
	PersistHash::store(\%data, $file);
	$temp = PersistHash::fetch({}, $file);
	is_deeply $temp->{hash}, $data{hash};
	delete $data{hash}->{1+$now};
	$data{hash}->{2+$now} = $words;
	$data{hash}->{$now} = $didnt;
	PersistHash::store(\%data, $file);
	$temp = PersistHash::fetch({}, $file);
	is_deeply $temp->{hash}, $data{hash};
}
{
	_make_sure_table($file,'try', "a", "TEXT");
	my $dbh = _connect($file);
	ok defined $dbh;
	my $ins = $dbh->prepare('INSERT INTO try (a) VALUES (?)');
	for my $val (qw(foo bar bat woo oop craw)) {
	    $ins->execute($val);
	}
	my $sel = $dbh->prepare('SELECT a FROM try WHERE a REGEXP ?');
	sub actual {
	    print "'$_[0]' matches:\n  ";
	    print join "\n  " =>
	        @{ $dbh->selectcol_arrayref($sel, undef, $_[0]) };
	    print "\n";
	}
	sub expected {
		given ($_[0]) {
			when ('^b') { "'^b' matches:\n  bar\n  bat\n" }
			when ('a') { "'a' matches:\n  bar\n  bat\n  craw\n" }
			when ('w?oop?') { "'w?oop?' matches:\n  foo\n  woo\n  oop\n" }
		}
	}
	for (qw(^b a w?oop?)) {
	    is _capture_output([\&actual, $_]), expected($_), $_;
	}
	$dbh->do('DROP TABLE try');
	$dbh->disconnect;
}
=pod
{
	tie my %data, "PersistHash", $_history, 1;
	tie my %data2, "PersistHash", $_entries;
	my %history = %{$data2{'history'}};
	$data{$_} = $history{$_} foreach keys %history;
}
=cut
ok _index_of('texts', _tables $_history) > -1;
$p = dirname(__FILE__);
ok !_string_contains($p, '~');
$p =~ s/$home/~/;
ok _string_contains $p, '~', 1;
is _realpath($p), dirname(__FILE__);
exit;