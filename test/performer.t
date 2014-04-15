#!/usr/bin/perl
use strict;
use warnings;
use Tk;
use Test::More qw( no_plan );    
use feature qw(say switch);
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path $0);
use Manage::utils qw(
	dump pp
	_value_or_else 
	_getenv
	_rndStr
	_make_sure_file
);
use Manage::Performer;
given (_value_or_else(0, _getenv('testing'))) {
	when ($_ != 0) {
		my $file = '/tmp/.entries';
		ok _make_sure_file($file, 1);
		my $obj = new Performer(
			file => $file, 
		);
		my $str = _rndStr 8, 'a'..'z', 0..9;
		$obj->give($str);
		$obj->change_history('add');
		my $str2 = _rndStr 8, 'a'..'z', 0..9;
		$obj->give($str2);
		$obj->change_history('add');
	}
	default {
		my $obj = new Performer( 
			title => "Testing",
			label => '<<-->>',
			file => [dirname(dirname abs_path $0) . '/.entries']
		);
		MainLoop();
	}
}
=pod
=cut
