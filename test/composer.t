#!/usr/bin/env perl
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
	_get_clipboard
	$_entries
	_tkinit
	_text_dialog
);
use Manage::Alias qw(
	resolve_alias 
	update_alias
);
use Manage::Settings;
use Manage::Resolver qw(
	place_given
	@given
	set_given
);
use Manage::Composer;
given (_value_or_else(0, _getenv('testing'))) {
	when (_ne 0) {
#		$ENV{'given'} = "/home/lotharla/work/perl\n/home/lotharla/work/bin/test.sh\nabc";
		my $composer = new Composer( 
			title => "Testing",
			label => '<<-->>',
			file => $_entries
		);
		$composer->relaunch;
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
	my $composer = new Composer(
		file => $temp, 
	);
	my %data = $composer->{data}->();
	my @keys = sort keys %data;
	is_deeply \@keys, ["__file__","alias","assoc","environ","history","options"];
	'Settings'->modify_setting($data{'assoc'}, $glob, $alias);
	update_alias $alias, $ntd;
	$composer->give($str);
	$composer->change_history('add');
	$composer->cancel;
}
tie my %data, "PersistHash", $temp;
is $data{'assoc'}->{$glob}, $alias;
is $data{'alias'}->{$alias}, $ntd;
my @history = values %{$data{'history'}};
ok _array_contains(\@history, $str);
_setenv 'given', "1.xxx\n2.yyy\n3.zzz";
set_given;
{
	my $composer = new Composer(
		file => $temp, 
	);
	my $item = $composer->item;
	ok $composer->is_new_entry($item);
	$ntd =~ s/\$1/.*/g;
	my $ref = $composer->can('commit');
	_check_output([$ref, $composer], qr/$ntd/);
	ok ! $composer->is_new_entry($composer->item);
	$composer->cancel;
}
{
	my $composer = new Composer(
		file => $_entries, 
	);
	my %history = $composer->history;
	my @timeline = $composer->timeline;
#	say $history{$_} foreach @timeline;
	my @pointers;
	foreach (values %history) {
		my $ptr = $composer->get_pointer_on_timeline($_, @timeline);
		push @pointers, $ptr;
	}
	ok !_duplicates(@pointers);
	@pointers = sort {$a<=>$b} @pointers;
	is $#pointers, @pointers - 1;
	$composer->cancel;
}
{
	my $win = _tkinit(0);
	_text_dialog $win, [20,3], "Given", \@given, 1;
	my $canvas = $win->Scrolled('Canvas', -width => 300, -height => 400);
	my $i;
	$canvas->createText(100, 10+100*($i++), -text => $_) foreach (@given, _get_clipboard);
	$canvas->pack;
	MainLoop();
}
=pod1.xxx
=cut
