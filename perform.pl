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
	_capture_output
	_perform
	_perform_2
	_capture_output_2
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
				my ($submenu, $value);
				$submenu = $menu->cascade(-label=>'Run', -underline=>0, -tearoff => 'no', 
					-postcommand => sub {
						$value = _value_or_else ' ', $self->{modifier};
					}
				)->cget('-menu');
				$submenu->radiobutton(-label=>"in terminal", -value => 'Alt', 
					-variable => \$value, -command => sub{ $self->{modifier} = 'Alt' });
				$submenu->radiobutton(-label=>"capture output", -value => 'Control', 
					-variable => \$value, -command => sub{ $self->{modifier} = 'Control' });
				$submenu->radiobutton(-label=>"normal", -value => ' ', 
					-variable => \$value, -command => sub{ $self->{modifier} = ' ' });
			}
		);
		$obj->relaunch;
		$modifier = $obj->{modifier};
	}
);
exit if ! $command;
sub terminalize {
	my $terminal = _chomp(`gconftool-2 -g /desktop/gnome/applications/terminal/exec`);
	my $output = _flatten $_[0];
	$output = _escapeDoubleQuotes $output;
	$output = "bash -c '" . $output . " | less'";
	return _combine( "$terminal", "-t", sprintf("\"%s\"", $output), "-e", "\"$output\"" );
}
given ($modifier) {
	when ('Alt') {
		_perform terminalize $command
	}
	when ('Control') {
		my $text = _capture_output_2 $command;
		_text_info undef, $command, $text;
		MainLoop;
	}
	default {
		_perform $command
	}
}

