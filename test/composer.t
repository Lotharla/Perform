#!/usr/bin/perl
use strict;
use warnings;
no warnings 'experimental';
use Tk;
use Test::More qw( no_plan );    
use feature qw(say switch);
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path $0);
use Manage::Utils qw(
	dump pp
	_combine
	_value_or_else 
	_getenv
	_contains
	_rndStr
	_make_sure_file
	_check_output
);
use Manage::Given qw(
	isDollar hasDollar dollar_amount make_Dollar 
	get_dollars set_dollars detect_dollar 
	place_given
	@given
);
use Manage::Alias qw(
	resolve_alias 
	update_alias
);
use Manage::Assoc qw(
	find_assoc
	update_assoc
);
use Manage::Composer;
given (_value_or_else(0, _getenv('testing'))) {
	when ($_ != 0) {
		my $glob = '*.xxx';
		my $alias = _rndStr 8, 'a'..'z', 0..9;
		my $ntd = _combine('nothing to do', "\$1");
		my $str = reverse $alias;
		my $file = '/tmp/.entries';
		ok _make_sure_file($file, 1);
		{
			my $perf = new Composer(
				file => $file, 
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
		tie my %data, "PersistHash", $file;
		is $data{'assoc'}->{$glob}, $alias;
		is $data{'alias'}->{$alias}, $ntd;
		my @history = values %{$data{'history'}};
		ok _contains(\@history, $str);
		$ENV{'given'} = "1.xxx\n2.yyy\n3.zzz";
		{
			my $perf = new Composer(
				file => $file, 
			);
			ok $perf->new_entry($perf->item);
			$ntd =~ s/\$1/.*/g;
			my $ref = $perf->can('commit');
			_check_output([$ref, $perf], qr/$ntd/);
			ok ! $perf->new_entry($perf->item);
		}
	}
	default {
#		$ENV{'given'} = "/home/lotharla/work/perl\n/home/lotharla/work/bin/test.sh\nabc";
		my $perf = new Composer( 
			title => "Testing",
			label => '<<-->>',
			file => dirname(dirname abs_path $0) . '/.entries'
		);
		MainLoop();
	}
}
=pod
=cut
