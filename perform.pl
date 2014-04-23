#!/usr/local/bin/perl
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path $0);
use Manage::Utils qw(
	dump 
	_chomp
	_combine
	_getenv 
	_value_or_else 
	_tempFilename
	_capture_output
	_diagnostic
	_tkinit
	_center_window
	_text_info
);
use Manage::Composer;
my $terminal = `gconftool-2 -g /desktop/gnome/applications/terminal/exec`;
$terminal = _chomp($terminal);
sub terminalize {
	my $title = $_[0];
	$title =~ s/\"//g;
	my $output = $_[0];
	$output =~ s/\t/ /g;
	$output =~ s/\"/\\"/g;
	$output = "bash -c '" . $output . " | less'";
	return _combine( "$terminal", "-t", sprintf("\"%s\"", $title), "-e", "\"$output\"" );
}
my $modifier;
my $command = _capture_output(
	sub {
		my $title = _getenv('title', "Perform ...");
		my $label = _getenv('label', '');
		my $file = dirname(abs_path $0) . '/.entries';
		my $obj = new Composer( 
			title => $title,
			label => $label,
			file => $file
		);
		MainLoop();
		$modifier = $obj->{modifier};
	}
);
sub perform {
	exec @_;
}
sub perform_2 {
	use IPC::Open3;
	no warnings 'once';
	my $command = "@_";
	$command =~ s/\"/\\"/g;
	$command = "perl -e 'exec \"$command\"'";
	my $pid = open3(\*CHLD_IN, \*CHLD_OUT, \*CHLD_ERR, $command) or die "open3() failed $!";
	while (<CHLD_OUT>) {
	    print;
	} 
}
if ($command) {
	given ($modifier) {
		when ('Alt') {
			perform terminalize($command)
		}
		when ('Control') {
			my $dir = "/tmp/out";
			my $file = _tempFilename 'outXXXX', $dir;
			my $text = _capture_output [\&perform_2, $command], $file;
			_text_info $command, $text;
		}
		default {
			perform $command
		}
	}
}

