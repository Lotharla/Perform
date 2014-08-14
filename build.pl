#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	ok is isnt is_deeply done_testing
	_eq _ne _gt _lt
	catfile
	_combine
	_object_from_XML
	_file_exists
	_fileparse
	@_separator
	_index_of
	_value_or_else
	_getenv
	_getenv_once
	_setenv
	_string_contains
	_perform
	$_entries
);
sub make_targets {
	my $file = shift;
	my $command = <<"HERE_DOC";
make -pqf "$file" 2>/dev/null | \
	awk -F':' '
		/^# Not a target:/ { skip = ! skip; next }
		skip { skip = ! skip; next }
		/^[a-zA-Z0-9][^\$#\/\\t=]*:([^=]|\$)/ {
			split(\$1,a,/ /)
			for(i in a)
				print a[i]
		}
	'
HERE_DOC
	split /$_separator[1]/, `$command`;
}
sub ant_targets {
	my $file = shift;
	my @array = @_;
	if (_file_exists($file)) {
		my $obj = _object_from_XML($file);
		if ( defined $obj->{project}->{target} ) {
			my $item = $obj->{project}->{target};
			if (ref($item) eq 'ARRAY') {
				my @targets = @{$item};
				for (my $i=0; $i<scalar(@targets); $i++) {
					my %target = %{$targets[$i]};
					@array = ant_targets($target{"\@name"}, @array);
				}
			} else {
				@array = ant_targets($item->{"\@name"}, @array);
			}
		}
		if ( defined $obj->{project}->{import} ) {
			my @parts = _fileparse($file);
			my $item = $obj->{project}->{import};
			if (ref($item) eq 'ARRAY') {
				my @imports = @$item;
				for (my $i=0; $i<scalar(@imports); $i++) {
					my %import = %{$imports[$i]};
					my $file = do_substitutions($obj, $import{"\@file"});
					@array = ant_targets($parts[1] . $file, @array);
				}
			} else {
				my $file = do_substitutions($obj, $item->{"\@file"});
				@array = ant_targets($parts[1] . $file, @array);
			}
		}
	} elsif (index($file, '-') != 0) {
		push @array, $file;
	}
	@array;
}
sub do_substitutions {
	my ($obj, $file) = @_;
	my @matches;
	while ($file =~ /\$\{([^\}]+)\}/g) {
		my @minus = @-;
		my @plus = @+;
		push @matches, [ \@minus, \@plus ];
	}
	for my $match (@matches) {
		my $name = substr($file,$match->[0]->[1],$match->[1]->[1]-$match->[0]->[1]);
		for my $prop (@{$obj->{project}->{property}}) {
			if ($prop->{"\@name"} && $prop->{"\@name"} eq $name) {
				my $value = $prop->{"\@value"};
				substr($file,$match->[0]->[0],$match->[1]->[0]-$match->[0]->[0],$value);
			}
		}
	}
	$file;
}
sub ant_default_target {
	my $file = shift;
	my $obj = _object_from_XML($file);
	_value_or_else '', '@default', $obj->{project};
}
sub ant_or_make {
	my $file = shift;
	my @parts = _fileparse($file);
	@parts > 2 && lc($parts[2]) eq '.xml'
}
sub build_tool {
	my $file = shift;
	my $dir = dirname $file;
	ant_or_make($file) ? 
		"\$ANT_HOME/bin/ant" : 
		"make -C \"$dir\"";
}
sub build_targets {
	my $file = shift;
	ant_or_make($file) ? 
		ant_targets($file) : 
		make_targets($file);
}
sub choice {
	my $cmd = catfile(dirname(__FILE__), "entry.pl");
	$cmd .= " @_";
	`$cmd`
}
sub build_command {
	my $file = shift;
	return '' if ! _file_exists $file;
	my $output = build_tool($file);
	$output .= " -f \"$file\"";
	if (@_) {
		$output = _combine $output, "@_";
	} else {
		my @targets = build_targets($file);
		unshift @targets, '-d';
		_setenv 'title', $output;
		_setenv 'item', 'default';
		_setenv "list-multiple", 1;
		given (choice sort @targets) {
			when ('') {return ''}
			when ('default') {
				$output = $output;
			}
			default {
				$output = _combine $output, $_;
			}
		}
	}
	$output;
}
given (_getenv_once('testing', 0)) {
	when (_gt 1) {
		use Manage::PersistHash;
		tie my %data, "PersistHash", $_entries;
		use Manage::Settings;
		Settings->apply('Environment', %data);
		Settings->apply('Environment');
		my @files = (
			"/home/lotharla/work/jdk/MathTest/build.xml",
			"/home/lotharla/work/c+plus/Makefile",
			"/home/lotharla/work/sqlite/extension/sqlite3-pcre/Makefile",
		);
		my $command = build_command choice @files;
		say $command;
		_perform $command;
	}
	when (_gt 0) {
		my $output = build_command "/home/lotharla/work/c+plus/Makefile", "realpath", "pcre_example";
		ok _string_contains $output, build_tool('makefile'), 0;
		ok _string_contains $output, "realpath";
		ok _string_contains $output, "pcre_example";
		$output = build_command "/home/lotharla/work/jdk/MathTest/build.xml", "clean", "compile";
		ok _string_contains $output, build_tool('build.xml'), 0;
		ok _string_contains $output, "clean";
		ok _string_contains $output, "compile";
		done_testing;
	}
	default {
		_perform build_command @ARGV;
	}
}
