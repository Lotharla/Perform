package Manage::assoc;

use strict;
use warnings;
use Tk;
use Tk::MListbox;
use Tk::DialogBox;
use File::Basename;
use feature qw(say switch);

use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0);

use Manage::utils qw(dump _getenv _value_or_else _flip_hash _set_selection _tkinit);

use Exporter::Easy (
	OK => [ qw(
		$mw
		%assoc
		@assoc_file_types
		find_assoc
		assoc_file_types
		show_assoc
		refill
	)],
);

our ($mw, %assoc);

sub find_assoc {
	my $entry = shift;
	my(@parts) = fileparse($entry, qr/\.[^.]*/);
	$parts[1] = $parts[0] . $parts[2];
	_value_or_else( _value_or_else('', $parts[2], \%assoc), $parts[1], \%assoc);
}

our @assoc_file_types;

sub assoc_file_types {
	if (%assoc and ! @assoc_file_types) {
		my %flip = _flip_hash(\%assoc);
		push(@assoc_file_types, [$_, $flip{$_}]) foreach (keys %flip);
	}
	\@assoc_file_types
}

sub show_assoc {
	my $btn_text = ['Add/Update', 'Remove', 'Cancel'];
	my $dlg = $mw->DialogBox(
				-title => 'Associations',
				-buttons => $btn_text,
				-default_button => $btn_text->[2]);
	my $mlb = $dlg->Scrolled('MListbox',
		-selectmode => 'browse', 
		-scrollbars => 'oe',
	    -bd=>2,
	    -relief=>'sunken',
    )->grid(-row => 0, -column => 0, -columnspan => 2);
	$mlb->columnInsert('end', -text => "Glob", -width => 30);
	$mlb->columnInsert('end', -text => "Alias", -width => 20);
	refill($mlb);
	my( $glob, $alias );
	$mlb->bindRows("<Button-1>", sub {
	    my @sel = $mlb->curselection;
	    if (@sel == 1) {
			($glob, $alias) = $mlb->getRow($sel[0]);
	    }
	});
	my $en = $dlg->Entry( -width => 30,
		-textvariable => \$glob)->grid(-row => 1, -column => 0);
	$dlg->Entry( -width => 20,
		-textvariable => \$alias)->grid(-row => 1, -column => 1);
	_set_selection($en);
show:
	given($dlg->Show) {
		when ($btn_text->[0]) {
			if ($glob) {
				$assoc{$glob} = $alias;
				refill($mlb);
				goto show;
			}
		}
		when ($btn_text->[1]) {
			if (exists $assoc{$glob}) {
				delete $assoc{$glob};
				refill($mlb);
				goto show;
			}
		}
	}
}

sub refill {
	my $mlb = shift;
	$mlb->delete(0, 'end');
	foreach my $glob (keys %assoc) {
		$mlb->insert('end', [$glob, $assoc{$glob}])
	}
	undef @assoc_file_types;
}

my $test = _value_or_else(0, _getenv('test'));
given ($test) {
	when ($_ < 0) {
		my %data = %{persist_hash("$ENV{HOME}/work/bin/.entries")};
		%assoc = %{$data{"assoc"}};
		dump assoc_file_types();
	}
	when ($_ != 0) {
		%assoc = (
			".pl" => "perl",
			".t" => "perl",
			".html" => "firefox",
			".htm" => "firefox",
			".sh" => "bash",
			".java" => "java",
			".xml" => "firefox",
			"build.xml" => "ant",
			"makefile" => "make",
			"Makefile" => "make",
			"GNUmakefile" => "make",
		);
		$mw = _tkinit(1);
		show_assoc();
	}
	default {
		1
	}
}

=pod
=cut
