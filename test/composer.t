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
use Manage::PersistHash;
use Manage::Utils qw(
	dump pp
	_gt _lt _eq _ne
	_combine
	_chomp
	_is_code_ref
	_value_or_else 
	_getenv
	_setenv
	_array_contains
	_duplicates
	_rndstr
	_make_sure_file
	_check_output
	_get_clipboard
	$_entries $_history $_words
	_clipboard
	_tkinit
	_text_dialog
	_widget_info 
	_find_widget
	_center_window
	_contents_of_file
	_now
	_connect
	_tables
	_index_of
	@_inputs
	_set_inputs
);
use Manage::Alias qw(
	resolve_alias 
	update_alias
);
use Manage::Settings;
use Manage::Resolver qw(
	place_inputs
);
use Manage::Composite;
use Manage::Composer;
use Manage::SuggestEntry;
given (_value_or_else(0, _getenv('testing'))) {
	when (_ne 0) {
		my $composer = new Composer( 
			title => "Testing",
			label => '<<-->>',
			file => $_entries
		);
		$composer->relaunch;
		exit
	}
}
my ($entr,$hist) = ('/tmp/.entries', '/tmp/.history');
unlink $entr,$hist;
goto here;
my @ddd = ("D'oh","I didn't do it");
{
	my $composite = new Composite(
		file => $entr, 
	);
	ok $composite->use_file;
	is $composite->mode, 2;
	ok _is_code_ref $composite->{data};
	is $composite->{data}->('ddd'), undef;
	$composite->{data} = $composite->data(sub {
		$_[0]->{'ddd'} = _value_or_else([], 'ddd', $_[0]);
	});
	isnt $composite->{data}->('ddd'), undef;
	my %data = $composite->{data}->();
	push @{$data{'ddd'}}, @ddd;
	$composite->save;
	%data = $composite->data()->();
	is_deeply $data{'ddd'}, \@ddd;
	$composite->{window}->destroy;
}
my $glob = '*.xxx';
my $alias = _rndstr 8, 'a'..'z', 0..9;
my $ntd = _combine('nothing to do', "\$1");
my $dtn = reverse $alias;
{
	my $composer = new Composer(
		file => $entr, 
		history_db => $hist, 
	);
	my %data = $composer->{data}->();
	my @keys = sort keys %data;
	is_deeply \@keys, ["__file__","alias","assoc","ddd","environ","favor","options"];
	'Settings'->modify_setting($data{'assoc'}, $glob, $alias);
	update_alias $alias, $ntd;
	$composer->give($dtn);
	$composer->change_history('add');
	$composer->cancel;
}
tie my %data, "PersistHash", $entr;
is $data{'assoc'}->{$glob}, $alias;
is $data{'alias'}->{$alias}, $ntd;
tie %data, "PersistHash", $hist, 1;
my @history = values %{$data{'hash'}};
ok _array_contains(\@history, $dtn);
_setenv 'inputs', "1.xxx\n2.yyy\n3.zzz";
_set_inputs;
{
	my $composer = new Composer(
		file => $entr, 
		history_db => $hist, 
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
		history_db => $_history, 
	);
	my %history = $composer->history;
	my @timeline = $composer->timeline;
#	say $history{$_} foreach @timeline;
	my @pointers;
	foreach (values %history) {
		my $index = $composer->get_index_on_timeline($_, @timeline);
		push @pointers, $index;
	}
	my @duplicates = _duplicates(@pointers);
	ok !@duplicates;
	@pointers = sort {$a<=>$b} @pointers;
	is $#pointers, @pointers - 1;
	$composer->cancel;
}
sub fill_texts {
	Manage::SuggestEntry::init_texts($hist);
	my $dbh = _connect $hist;
	my $insert = $dbh->prepare('INSERT INTO texts (signature,date,text) VALUES (?,?,?)');
	my $signature = 'Composer.suggestentry';
	my $now = _now;
	my $i = 0;
	_contents_of_file $_words, 0, sub {
		my $text = _chomp shift;
		$insert->execute($signature, $now, $text) or die $DBI::errstr;
		++$i < 20 ? 1 : 0
	};
	$dbh->disconnect
}
here:
{
	fill_texts if _index_of('texts', _tables $hist) < 0;
	my $win = _tkinit(0,'SuggestEntry');
	my $wgt = $win->SuggestEntry(-history_db => $hist)->pack;
	$wgt->focus;
	_center_window($win, 1);
}
exit;
{
	_clipboard $ddd[0];
	my $win = _tkinit(0);
	_text_dialog $win, [20,3], 'Inputs', \@_inputs;
	my $canvas = $win->Scrolled('Canvas', -width => 300, -height => 400);
	my $i;
	$canvas->createText(100, 10+100*($i++), -text => $_) foreach (@_inputs, _get_clipboard);
	$canvas->pack;
dump _widget_info $win;
dump _widget_info _find_widget($win, '.frame.canvas'), 'layout';
=pod
=cut
	$win->destroy
}
