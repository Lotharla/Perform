#!/usr/bin/perl -w

use strict;
use warnings;
use feature qw(say switch);

require "$ENV{HOME}/work/bin/utils.pl";

$ENV{'title'} = value_or_else("Perform ...", 'title', \%ENV);

my $command = capture_output(
	sub {
		local @ARGV = ("$ENV{HOME}/work/bin/.entries");
		do "$ENV{HOME}/work/bin/entry.pl";
	}
);
exec $command if $command;

exit

