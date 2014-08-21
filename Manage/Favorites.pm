package Manage::Favorites;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::TList;
use Tk::PNG;
use Tk::DialogBox;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_lt	_gt _ne _eq
	_is_blessed
	_getenv_once 
	_value_or_else 
	_flip_hash 
	_is_glob
	_glob_match
	_fileparse
	_filename_extension
	_tkinit
	_set_selection 
	_text_info
	_ask_file
	_file_types
	$_entries
);
use Manage::PersistHash;
use Exporter::Easy (
	OK => [ qw(
		ask_favor
		organize_favor
	)],
);
my ($obj, $window, %data);
sub inject {
	$obj = $_[0];
	if (_is_blessed $obj) {
		$window = $obj->{window};
		%data = $obj->{data}->();
	} else {
		undef $obj;
		undef $window;
		%data = @_;
	}
	$data{'favor'} = {} unless exists($data{'favor'});
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
sub picture {
	my( $file,$pic,$btn ) = @_;
#say 'picture : ', pp @_;
	if ($file) {
		my $ext = _filename_extension($file);
		if ($pic) {
			$pic->configure(-format => $ext, -file => $file);
		} else {
			$pic = $window->Photo(-format => $ext, -file => $file);
		}
	}
	$btn->configure(-image => $pic) if $btn;
	$pic
}
sub ask_favor {
}
sub organize_favor {
	my $buttons = ['Add/Update', 'Remove', 'Close'];
	my $dlg = $window->DialogBox(
		-title => 'Favorites',
		-buttons => $buttons,
		-default_button => $buttons->[2]);
	my( $lst, $btn, $pic, $name, $command );
	$lst = $dlg->Scrolled('TList',
		-orient => 'vertical', 
		-scrollbars => 'oe',
		-browsecmd => sub {
			my $sel = $_[0];
			$name = $lst->entrycget($sel, '-text');
			my @fave = @{$data{'favor'}->{$name}};
			$command = $fave[2];
			picture(undef, $pic = $lst->entrycget($sel, '-image'), $btn);
		},
    )->pack(-side => 'top', -fill => 'both');
	refill($lst);
	my $pnl = $dlg->Frame()->pack(-side => 'bottom', -fill=>'x', -expand=>1);
	$btn = $pnl->Button(
		-image => $pic,
		-command => sub {
			return unless $pic;
			my $file = $pic->cget(-file);
			my @types = _file_types($data{'assoc'}, ["image"]);
			$file = _ask_file($dlg, 'Image file', $file, \@types);
			if ($file) {
				$pic = picture($file, $pic, $btn);
			}
		}
	)->grid(-row => 0, -column => 0);
	my $en = $pnl->Entry( -width => 20,
		-textvariable => \$name)->grid(-row => 0, -column => 1);
	$pnl->Entry( -width => 30,
		-textvariable => \$command)->grid(-row => 1, -column => 0, -columnspan => 2);
	_set_selection($en);
show:
	given($dlg->Show) {
		when ($buttons->[0]) {
			if ($name) {
				update_assoc $name, $command;
				refill($lst);
				goto show;
			}
		}
		when ($buttons->[1]) {
			if (exists $data{'favor'}->{$name}) {
				update_assoc $name;
				refill($lst);
				goto show;
			}
		}
	}
}
sub refill {
	my $lst = shift;
	my $top = $lst->toplevel;
	$lst->delete(0, 'end');
	my %favor = %{$data{'favor'}};
	foreach (keys %favor) {
		my @fave = @{$favor{$_}};
		$lst->insert('end',
			-itemtype => 'imagetext',
			-image => picture($fave[1]),
			-text => $_,
		)
	}
}
given (_getenv_once('test', 0)) {
	when (_gt 0) {
		%data = (
			favor => {
				"view" => [0,"/home/lotharla/fugue-icons-3.5.6/icons/binocular.png","/home/lotharla/work/tools/viewer.pl \$0"],
				"compare" => [0,"/home/lotharla/fugue-icons-3.5.6/icons/documents.png","meld -n\t\"\$1\"\t\"\$2\""],
			}
		);
		tie %data, "PersistHash", $_entries;
		$window = _tkinit(1);
		organize_favor();
	}
	default {
		1
	}
}
