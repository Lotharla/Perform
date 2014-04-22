package Manage::Assoc;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::MListbox;
use Tk::DialogBox;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0);
use Manage::Utils qw(
	dump
	_getenv 
	_value_or_else 
	_flip_hash 
	_is_glob
	_glob_match
	_fileparse
	_tkinit
	_set_selection 
);
use Manage::PersistHash;
use Exporter::Easy (
	OK => [ qw(
		@assoc_file_types
		find_assoc
		update_assoc
		set_data
		assoc_file_types
		show_assoc
		refill
	)],
);
my ($obj, $window, %data);
sub inject {
	$obj = shift;
	$window = $obj->{window};
}
sub assoc_ref {
	my $key = shift;
	my $value = shift;
	%data = $obj->{data}->() if $obj;
	return $data{'assoc'};
}
sub set_data {	%data = @_	}
sub update_assoc {
	my $glob = shift;
	my $alias = shift;
	my $href = assoc_ref;
	if ($alias) {
		$href->{$glob} = $alias;
	} else {
		delete $href->{$glob};
	}
}
sub find_assoc {
	my $glob = shift;
	my(@parts) = _fileparse($glob);
	$parts[1] = $parts[0] . $parts[2];
	my %assoc = %{assoc_ref()};
	foreach (keys %assoc) {
		if (_is_glob($_)) {
			return $assoc{$_} if _glob_match $_, $parts[1];
		}
	}
	_value_or_else( _value_or_else('', $parts[2], \%assoc), $parts[1], \%assoc);
}
our @assoc_file_types;
sub assoc_file_types {
	my %assoc = %{assoc_ref()};
	if (%assoc and ! @assoc_file_types) {
		my %flip = _flip_hash(\%assoc);
		push(@assoc_file_types, [$_, $flip{$_}]) foreach (keys %flip);
	}
	\@assoc_file_types
}
sub show_assoc {
	my $btn_text = ['Add/Update', 'Remove', 'Cancel'];
	my $dlg = $window->DialogBox(
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
				update_assoc $glob, $alias;
				refill($mlb);
				goto show;
			}
		}
		when ($btn_text->[1]) {
			if (exists assoc_ref()->{$glob}) {
				update_assoc $glob;
				refill($mlb);
				goto show;
			}
		}
	}
}
sub refill {
	my $mlb = shift;
	$mlb->delete(0, 'end');
	my %assoc = %{assoc_ref()};
	foreach my $glob (keys %assoc) {
		$mlb->insert('end', [$glob, $assoc{$glob}])
	}
	undef @assoc_file_types;
}
my $file = dirname(dirname abs_path $0) . "/.entries";
given (_value_or_else(0, _getenv('test'))) {
	when ($_ < 0) {
		tie %data, "PersistHash", $file;
		dump assoc_file_types();
	}
	when ($_ > 0) {
		%data = (
			assoc => {
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
			}
		);
		$window = _tkinit(1);
		show_assoc();
	}
	default {
		1
	}
}
