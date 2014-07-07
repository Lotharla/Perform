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
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_lt	_gt _ne _eq
	_blessed
	_getenv 
	_value_or_else 
	_flip_hash 
	_is_glob
	_glob_match
	_fileparse
	_tkinit
	_set_selection 
	_text_info
	$_entries
);
use Manage::PersistHash;
use Exporter::Easy (
	OK => [ qw(
		@assoc_file_types
		find_assoc
		update_assoc
		assoc_file_types
		show_assoc
		refill
	)],
);
my ($window, %data);
sub inject {
	if (_blessed $_[0]) {
		$window = $_[0]->{window};
		%data = $_[0]->{data}->();
	} else {
		undef $window;
		%data = @_;
	}
	$data{'assoc'} = {} if !exists($data{'assoc'});
}
sub update_assoc {
	my $glob = shift;
	my $alias = shift;
	my $href = $data{'assoc'};
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
	my %assoc = %{$data{'assoc'}};
	foreach (keys %assoc) {
		if (_is_glob($_)) {
			return $assoc{$_} if _glob_match $_, $parts[1];
		}
	}
	_value_or_else( _value_or_else('', $parts[2], \%assoc), $parts[1], \%assoc);
}
our @assoc_file_types;
sub assoc_file_types {
	my %assoc = %{$data{'assoc'}};
	if (%assoc and ! @assoc_file_types) {
		my %flip = _flip_hash(\%assoc);
		push(@assoc_file_types, [$_, $flip{$_}]) foreach (keys %flip);
	}
	\@assoc_file_types
}
sub show_assoc {
	my $btn_text = ['Add/Update', 'Remove', 'Close'];
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
			if (exists $data{'assoc'}->{$glob}) {
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
	my %assoc = %{$data{'assoc'}};
	foreach my $glob (keys %assoc) {
		$mlb->insert('end', [$glob, $assoc{$glob}])
	}
	undef @assoc_file_types;
}
given (_value_or_else(0, _getenv('test'))) {
	when (_gt 0) {
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
		_text_info "file types", pp(assoc_file_types);
	}
	when (_lt 0) {
		tie %data, "PersistHash", $_entries;
		dump assoc_file_types();
	}
	default {
		1
	}
}
