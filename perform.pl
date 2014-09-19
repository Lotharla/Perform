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
	dump pp
	_chomp
	_combine
	_flatten
	_getenv 
	_value_or_else 
	_terminalize
	_perform
	_perform_2
	_capture_output
	_result_perform
	_contents_to_file
	_diagnostic
	_tkinit
	_center_window
	_text_info
	_ask_file
	$_entries $_history
	_widget_info
	_find_widget
);
use Manage::Resolver qw(
	@inputs
	inputs_title
	next_clip
);
use Manage::Composer;
my $composer;
my $command = _capture_output(
	sub {
		my $title = inputs_title("Perform ...");
		my $label = _getenv('label', '');
		$composer = new Composer( 
			title => $title,
			label => $label,
			file => $_entries,
			history_db => $_history,
			extendMenu => sub {
				my ($self, $menu) = @_;
#dump _widget_info $self->{window};
#dump _widget_info _find_widget($self->{window}, '.frame1.button'), 'layout';
				return;
				my $submenu = $menu->cascade(-label=>'Run', -underline=>0, -tearoff => 'no')->cget('-menu');
				my @runopts = @{Settings->strings('run')};
				for my $opt (0..$#runopts) {
					my $value = $self->modifier('',$opt);
					$submenu->radiobutton(-label => $runopts[$opt],
						-value => $value, 
						-variable => \$self->{modifier},
						-command => sub{ $self->modifier($opt) });
				}
				$submenu->separator;
				$submenu->checkbutton(-label=>"immediately", -onvalue => 1, -offvalue => 0, 
					-variable => \$self->{immediate}, -command => sub{
						my %data = $self->{data}->();
						$data{options}->{"immediate"} = $self->{immediate};
					});
			}
		);
		$composer->relaunch;
	}
);
exit unless $command;
use Manage::Settings;
Settings->apply('Environment');
given ($composer->modifier) {
	when ('Alt') {
		_perform _terminalize $command
	}
	when ('Control') {
		my $text = _result_perform $command;
		_text_info undef, $command, $text, 'Save text' => sub {
			my ($label,$widget,$parent) = @_;
			my $file = next_clip;
			$file = _ask_file($parent, $label, $file, [], 1);
			if ($file) {
				_contents_to_file $file, $text;
			}
		};
	}
	default {
		_perform $command
	}
}

