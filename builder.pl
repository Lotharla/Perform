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
	basename
	catfile
	tmpdir
	_combine
	_surround
	_xml_object
	_file_exists
	_fileparse
	_filename_extension
	@_separator
	_index_of
	_value_or_else
	_getenv
	_getenv_once
	_setenv
	_string_contains
	_perform
	_result_perform
	_text_info
	$_entries
	_contents_to_file
);
sub choice {
	my $cmd = catfile(dirname(__FILE__), "entry.pl");
	$cmd .= " @_";
	`$cmd`
}
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
		my $obj = _xml_object($file);
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
sub xml_project_attr {
	my $obj = _xml_object(shift);
	my $name = shift;
	_value_or_else '', '@' . $name, $obj->{project};
}
sub maven_or_ant {
	my $file = shift;
	return $file eq "pom.xml" unless _file_exists $file;
	my $xmlns = xml_project_attr $file, 'xmlns';
	_string_contains $xmlns, 'http://maven.apache.org/POM', 0
}
sub xml_or_makefile {
	my $ext = _filename_extension(shift);
	lc($ext) eq 'xml'
}
sub build_tool {
	my $file = shift;
	xml_or_makefile($file) ? 
		(maven_or_ant($file) ?
			"\$M2_HOME/bin/mvn" : 
			"\$ANT_HOME/bin/ant") : 
		"/usr/bin/make";
}
sub build_targets {
	my $file = shift;
	my $maven = 0;
	my @targets = xml_or_makefile($file) ? 
		(($maven = maven_or_ant($file)) ?
			('help:effective-pom') : 
			ant_targets($file)) : 
		make_targets($file);
	unshift @targets, '-d' unless $maven;
	@targets
}
sub build_command {
	my $file = shift;
	return '' unless _file_exists $file;
	my $output = build_tool($file);
	if (xml_or_makefile($file)) {
		$output .= " -f \"$file\"";
	} else {
		$output .= " -C " . _surround(2, dirname($file));
		$output .= " -f " . _surround(2, basename($file));
	} 
	if (@_) {
		$output = _combine $output, "@_";
	} else {
		my @targets = build_targets($file);
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
my @test_files = (
	"/home/lotharla/work/maven/my-app/pom.xml",
	"/home/lotharla/work/ant/Ant_Tut/build.xml",
	"/home/lotharla/work/ant/groovy.xml",
	"/home/lotharla/work/c+plus/Makefile",
	"/home/lotharla/work/sqlite/extension/sqlite3-pcre/Makefile",
);
sub test_makefile {
	use Manage::PersistHash;
	tie my %data, "PersistHash", $_entries;
	use Manage::Settings;
	Settings->apply('Environment', %data);
	Settings->apply('Environment');
	my $contents = <<'END';
all:
	@echo "Environment"
END
	$contents .= "\t\@echo \"$_ = \$\$$_\"\n" foreach keys %{$data{'environ'}};
	_contents_to_file catfile(tmpdir, "makefile"), $contents
}
given (_getenv_once('testing', 0)) {
	when (_gt 1) {
		test_makefile;
		if (my $command = build_command choice @test_files) {
			say $command;
			my $text = _result_perform $command;
			_text_info undef, "build log", $text;
		}
	}
	when (_gt 0) {
		my $output = build_command $test_files[0], "help:effective-pom";
		ok _string_contains $output, build_tool('pom.xml'), 0;
		ok _string_contains $output, "help:effective-pom";
		$output = build_command $test_files[1], "clean", "compile";
		ok _string_contains $output, build_tool('build.xml'), 0;
		ok _string_contains $output, "clean";
		ok _string_contains $output, "compile";
		$output = build_command test_makefile, "all";
		ok _string_contains $output, build_tool('makefile'), 0;
		my $text = _result_perform $output;
		_text_info undef, "build log", $text;
		done_testing;
	}
	default {
		_perform build_command @ARGV;
	}
}
