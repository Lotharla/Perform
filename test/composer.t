#!/usr/bin/perl
use strict;
use warnings;
no warnings 'experimental';
use Tk;
use Test::More qw( no_plan );    
use feature qw(say switch);
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_gt _lt _eq _ne
	_combine
	_value_or_else 
	_getenv
	_setenv
	_array_contains
	_duplicates
	_rndstr
	_make_sure_file
	_check_output
	$_entries
);
use Manage::Alias qw(
	resolve_alias 
	update_alias
);
use Manage::Assoc qw(
	find_assoc
	update_assoc
);
use Manage::Resolver qw(
	place_given
	@given
);
use Manage::Composer;
given (_value_or_else(0, _getenv('testing'))) {
	when (_ne 0) {
#		$ENV{'given'} = "/home/lotharla/work/perl\n/home/lotharla/work/bin/test.sh\nabc";
		my $perf = new Composer( 
			title => "Testing",
			label => '<<-->>',
			file => $_entries
		);
		$perf->relaunch;
		exit
	}
}
my $glob = '*.xxx';
my $alias = _rndstr 8, 'a'..'z', 0..9;
my $ntd = _combine('nothing to do', "\$1");
my $str = reverse $alias;
my $temp = '/tmp/.entries';
ok _make_sure_file($temp, 1);
{
	my $perf = new Composer(
		file => $temp, 
	);
	my %data = $perf->{data}->();
	my @keys = sort keys %data;
	is_deeply \@keys, ["__file__","alias","assoc","history"];
	update_assoc $glob, $alias;
	update_alias $alias, $ntd;
	$perf->give($str);
	$perf->change_history('add');
	$perf->cancel;
}
tie my %data, "PersistHash", $temp;
is $data{'assoc'}->{$glob}, $alias;
is $data{'alias'}->{$alias}, $ntd;
my @history = values %{$data{'history'}};
ok _array_contains(\@history, $str);
_setenv 'given', "1.xxx\n2.yyy\n3.zzz";
{
	my $perf = new Composer(
		file => $temp, 
	);
	my $item = $perf->item;
	ok $perf->new_entry($item);
	$ntd =~ s/\$1/.*/g;
	my $ref = $perf->can('commit');
	_check_output([$ref, $perf], qr/$ntd/);
	ok ! $perf->new_entry($perf->item);
}
{
	my $perf = new Composer(
		file => $_entries, 
	);
	my %history = $perf->history;
	my @timeline = $perf->timeline;
#	say $history{$_} foreach @timeline;
	my @pointers;
	foreach (values %history) {
		my $ptr = $perf->get_pointer_on_timeline($_, @timeline);
		push @pointers, $ptr;
	}
	ok !_duplicates(@pointers);
	@pointers = sort {$a<=>$b} @pointers;
	is $#pointers, @pointers - 1;
	MainLoop();
}
=pod
=cut
