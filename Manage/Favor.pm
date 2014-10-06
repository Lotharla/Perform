package Manage::Favor;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::TList;
use Tk::PNG;
use Tk::JPEG;
use Tk::DialogBox;
use Tk::NumEntry;
use Tk::BrowseEntry;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_lt	_gt _ne _eq
	_is_blessed
	_getenv_once 
	_value_or_else 
	_index_of
	_file_exists
	_fileparse
	_filename_extension
	_tkinit
	_set_selection 
	_text_info
	_ask_file
	_file_types
	$_entries
	_dimension
	_menu
	_center_window
	_implicit
);
use Manage::PersistHash;
use Manage::Settings;
use Exporter::Easy (
	OK => [ qw(
		find_favorite
		update_favorite
		inc_favor
		organize_favor
		install_favor_button
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
sub update_favorite {
	my $name = shift;
	return unless $name;
	my $faves = $data{'favor'};
	if (@_) {
		$faves->{$name} = \@_;
	} elsif (exists $faves->{$name}) {
		delete $faves->{$name};
	}
}
sub find_favorite {
	my $name = shift;
	return () unless $name;
	my $fave = $data{'favor'}->{$name};
	$fave ? @{$fave} : ()
}
sub inc_favor {
	my $name = shift;
	my @fave = find_favorite $name;
	$fave[0] += shift;
	update_favorite $name, @fave;
}
sub runopts {
	my @runopts = @{Settings->strings('run')};
	return @runopts if $#_ < 0;
	my $i = _value_or_else 0,$_[0];
	$runopts[$i]
}
sub organize_favor {
	my ($name, $favor, $file, $command, $runopt) = @_;
	my $find = sub {
		my @fave = find_favorite shift;
		$favor = $fave[0];
		$file = $fave[1];
		$command = $fave[2];
		$runopt = runopts $fave[3];
	};
	if ($name) {
		$find->($name);
	} else {
		$runopt = runopts $runopt;
	}
	my $modopts = Settings->strings('mod');
	my $dlg = $window->DialogBox(
		-title => 'Favorites',
		-buttons => $modopts,
		-default_button => $modopts->[2]);
	my( $lst, $btn, $pic );
	$lst = $dlg->Scrolled('TList',
		-orient => 'vertical', 
		-scrollbars => 'oe',
		-browsecmd => sub {
			my $sel = $_[0];
			$pic = $lst->entrycget($sel, '-image');
			$name = $lst->entrycget($sel, '-text');
			$find->($name);
			picture(undef, $pic, $btn);
		},
    )->pack(-side => 'top', -fill => 'both');
	fill($lst);
	my $pnl = $dlg->Frame()->pack(-side => 'bottom', -fill=>'x', -expand=>1);
	$btn = $pnl->Button(
		-image => $pic,
		-command => sub {
			my $file = photo_file($pic);
			my @types = _file_types($data{'assoc'}, ["image"]);
			$file = _ask_file($dlg, 'Image file', $file, \@types);
			if ($file) {
				$pic = picture($file, $pic, $btn);
			}
		}
	)->grid(-row => 0, -column => 0, -sticky => 'e');
	$pic = picture($file, $pic, $btn);
	my ($en,$be);
	$en = $pnl->Entry( 
		-width => 20,
		-textvariable => \$name
	)->grid(-row => 0, -column => 1, -sticky => 'w');
	$pnl->Label(
		-text => 'Favor',
	)->grid(-row => 1, -column => 0, -sticky => 'e');
	$pnl->NumEntry(
		-minvalue => 0,
		-maxvalue => 100,
		-textvariable => \$favor,
	)->grid(-row => 1, -column => 1, -sticky => 'w');
	$pnl->Label(
		-text => 'Run',
	)->grid(-row => 2, -column => 0, -sticky => 'e');
	$be = $pnl->BrowseEntry(
		-listcmd => sub {
			$be->delete(0,'end');
			$be->insert('end', $_) foreach runopts;
		},
		-variable => \$runopt
	)->grid(-row => 2, -column => 1, -sticky => 'w');
	$be->Subwidget("entry")->configure(-state => 'readonly');
	$be->Subwidget("slistbox")->configure(-height => 5);
	my @dim = _dimension($obj,'entry',50);
	$pnl->Entry( 
		-width => $dim[0],
		-textvariable => \$command,
	)->grid(-row => 3, -column => 0, -columnspan => 2);
	_set_selection($en);
	given($dlg->Show) {
		when ($modopts->[0]) {
			$file = photo_file($pic);
			$runopt = _index_of $runopt, runopts;
			my @params = ($name, $favor, $file, $command, $runopt);
			update_favorite(@params);
			organize_favor(@params);
		}
		when ($modopts->[1]) {
			update_favorite($name);
			organize_favor($name);
		}
	}
}
sub fill {
	my $wgt = shift;
	my $func = _value_or_else sub{return sub{}}, shift;
	my $class = ref $wgt;
	$wgt->delete(0, 'end');
	my %favor = %{$data{'favor'}};
	foreach my $name (sort {$favor{$b}->[0] <=> $favor{$a}->[0]} keys(%favor)) {
		my @fave = @{$favor{$name}};
		my $pic = picture($fave[1]);
		my $cmd = [ $func, $name ];
		given ($class) {
			when ('Tk::Menu') {
				$wgt->command(
					-compound => 'left',
					-label => $name,
					-image => $pic,
					-command => $cmd
				);
			}
			default {
				$wgt->insert('end',
					-itemtype => 'imagetext',
					-text => $name,
					-image => $pic,
				)
			}
		}
	}
}
sub picture {
	my( $file,$pic,$btn ) = @_;
	if (_file_exists $file) {
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
sub photo_file {
	my $pic = shift;
	$pic ? $pic->cget(-file) : ''
}
sub install_favor_button {
	my ($menu, $label, $func) = @_;
	my $btn;
	$btn = $menu->Menubutton(
		-text => $label, 
		-tearoff => 0,
		-postcommand => sub {
			fill $btn->menu, $func;
		}
	);
	$btn
}
given (_getenv_once('_test', 0)) {
	when (_gt 1) {
		tie %data, "PersistHash", $_entries;
		$window = _tkinit(0);
		install_favor_button(_menu($window), 'Favorites', sub { say pp @_ });
		_center_window $window, 1;
	}
	when (_gt 0) {
		%data = (
			favor => {
				"view" => [
					0,
					"/home/lotharla/fugue-icons-3.5.6/icons/binocular.png",
					dirname(dirname abs_path __FILE__) . "viewer.pl \$0"],
				"compare" => [
					0,
					"/home/lotharla/fugue-icons-3.5.6/icons/documents.png",
					"meld -n\t\"\$1\"\t\"\$2\""],
				devel   => [
					99,
					'',
					"/home/lotharla/work/bin/devel.sh",
				],
			},
			assoc => {
               ".png"        => "image",
               ".gif"        => "image",
               ".xbm"        => "image",
               ".xml"        => "firefox",
               ".xpm"        => "image",
			}
		);
		_implicit 'Image file', "/home/lotharla/fugue-icons-3.5.6/icons/abacus.png";
		$window = _tkinit(1);
		organize_favor('devel');
#		organize_favor("", 42, "/home/lotharla/fugue-icons-3.5.6/icons/beer.png", 'Zaphod Beeblebrox');
		$window->destroy();
		_text_info undef, "", pp(\%data);
	}
	default {
		1
	}
}
