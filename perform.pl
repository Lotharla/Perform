#!/usr/bin/env perl
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
	_flatten
	_escapeDoubleQuotes
	_getenv 
	_value_or_else 
	_tempFilename
	_capture_output
	_diagnostic
	_tkinit
	_center_window
	_text_info
	$_entries
);
use Manage::Resolver qw(
	@given
	given_title
);
use Manage::Composer;
my $modifier;
my $command = _capture_output(
	sub {
		my $title = given_title("Perform ...");
		my $label = _getenv('label', '');
		my $obj = new Composer( 
			title => $title,
			label => $label,
			file => $_entries,
			extendMenu => sub {
				my ($self, $menu) = @_;
				my $submenu = $menu->cascade(-label=>'Run', -underline=>0, -tearoff => 'no')->cget('-menu');
				$submenu->radiobutton(-label=>"in terminal", -command => sub{ $self->{modifier} = 'Alt' });
				$submenu->radiobutton(-label=>"capture output", -command => sub{ $self->{modifier} = 'Control' });
			}
		);
		$obj->relaunch;
		$modifier = $obj->{modifier};
	}
);
my $terminal = _chomp(`gconftool-2 -g /desktop/gnome/applications/terminal/exec`);
sub terminalize {
	my $output = _flatten $_[0];
	$output = _escapeDoubleQuotes $output;
	$output = "bash -c '" . $output . " | less'";
	return _combine( "$terminal", "-t", sprintf("\"%s\"", $output), "-e", "\"$output\"" );
}
sub perform {
	_diagnostic "@_";
	exec @_;
}
sub perform_2 {
	use IPC::Open3;
	no warnings 'once';
	my $command = _escapeDoubleQuotes "@_";
	$command = "perl -e 'exec \"$command\"'";
	_diagnostic $command;
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

