package Manage::alias;

use strict;
use warnings;
use Tk;
use Tk::Menu;
use Tk::DialogBox;
use feature qw(say switch);

use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0);

use Manage::utils qw(dump _getenv _value_or_else _persist_hash _tkinit _set_selection _replace_text _center_window);

use Exporter::Easy (
	OK => [ qw(
		$mw
		%alias
		cascades
		resolve_alias
		update_expression
		ask_expression
		create_menu
		install_menu_button
		show_menu
		install_popup_button
	)],
);

our ($mw, %alias);

my $path_sep = qr/\|/;

sub cascades {
	my( $menu, $name, $href, $func )= @_;
	my @parts = split(/$path_sep/, $name);
	$menu = $menu->cascade(
		-label   => $parts[$#parts],
		-tearoff => 0
	) if $name;
	my %hash = $href ? %{$href} : %alias;
	foreach my $key (sort keys(%hash)) {
		my $value = $hash{$key};
		my $path = $href ? join('|', $name, $key) : $key;
		given (ref($value)) {
			when ('HASH') {
				cascades($menu, $path, $value, $func) 
			}
			default {
				$menu->command(
					-label   => $key,
					-command => [ $func, $value, $path ]
				)
			}
		}
	};
}

sub resolve_alias {
	my $path = shift;
	my $href = \%alias;
	for (;;) {
		my @parts = split(/$path_sep/, $path, 2);
		my $name = $parts[0];
		if (scalar(@parts) < 2) {
			return $href->{$name};
		} elsif (not exists $href->{$name}) {
			last;
		}
		$href = $href->{$name};
		$path = $parts[1]
	}
	''
}

sub update_expression {
	my( $path, $value )= @_;
	my $href = \%alias;
	my $_path = $path;
	for (;;) {
		my @parts = split(/$path_sep/, $path, 2);
		my $final = scalar(@parts) < 2 ? 1 : 0;
		my $name = $parts[0];
		if ($final) {
			if ($value) {
				$href->{$name} = $value;
			} else {
				delete $href->{$name};
				if (scalar(keys %$href) < 1) {
					update_expression (substr($_path, 0, length($_path)-length($name)-1));
				}
			}
		} elsif (not exists $href->{$name}) {
			$href->{$name} = {};
		}
		last if $final;
		$href = $href->{$name};
		$path = $parts[1]
	}
}

sub ask_expression {
	my( $path, $value )= @_;
	my $dlg = $mw->DialogBox(
		-title => "Expression",
		-buttons => ['OK', 'Update', 'Remove', 'Cancel'],
		-default_button => 'Cancel');
	$dlg->Label( -text => 'Path' )->grid(-row => 0, -column => 0);
	$dlg->Entry( -width => 50,
		-textvariable => \$path)->grid(-row => 0, -column => 1);
	$dlg->Label( -text => 'Value' )->grid(-row => 1, -column => 0);
	my $en = $dlg->Entry( -width => 50,
		-textvariable => \$value)->grid(-row => 1, -column => 1);
	_set_selection($en);
	given($dlg->Show) {
		when ('Update') {
			update_expression $path, $value;
			return $value
		}
		when ('Remove') {
			update_expression $path;
		}
		when ('OK') {
			return $value
		}
	}
	''
}

my $popup = undef;
my $modify = 0;

sub create_menu {
	my( $menu, $name, $func )= @_;
	cascades $menu, $name, undef, sub { 
		my( $value, $path )= @_;
		if ($modify) {
			$value = ask_expression $path, $value;
		}
		$func->($value, $path); 
		undef $popup if $popup; 
	};
	$menu->separator;
	$menu->add('checkbutton', 
		-label => 'modify', 
		-onvalue => 1, -offvalue => 0, 
		-variable => \$modify,
		-command => sub { 
			undef $popup if $popup; 
		}
	);
}

sub install_menu_button {
	my ($menu, $label, $func) = @_;
	my $btn;
	$btn = $menu->Menubutton(
		-text => $label, 
		-tearoff => 0,
		-postcommand => sub {
			$btn->menu->delete(0, 'end');
			create_menu $btn->menu, '', $func
		}
	);
	$btn
}

sub show_menu {
	my ($self, $mw, $func) = @_;
	if (defined $popup) {
		$popup->unpost;
		undef $popup
	} else {
		$popup = $mw->Menu(-tearoff => 0);
		create_menu $popup, '', $func;
		$popup->post($mw->x + $self->x, $mw->y + $self->y + $self->height)
	}
}

sub install_popup_button {
	my ($wnd, $label, $func) = @_;
	my $btn;
	$btn = $wnd->Button(
		-text   => $label,
		-command => sub {show_menu($btn, $mw, $func)}
	);
	$btn
}

my $test = _value_or_else(0, _getenv('test'));
given ($test) {
	when ($_ > 1) {
		my %data = %{_persist_hash("$ENV{HOME}/work/bin/.entries")};
		%alias = %{$data{"alias"}};
		$mw = _tkinit(0);
		$mw->configure(-menu => my $menu = $mw->Menu);
		install_menu_button($menu, 'Alias', sub { my $value = shift; say $value if $value });
		_center_window ($mw);
		MainLoop();
	}
	when ($_ > 0) {
		my %data = %{_persist_hash("$ENV{HOME}/work/bin/.entries")};
		%alias = %{$data{"alias"}};
		$mw = _tkinit(0);
		install_popup_button($mw, 'Alias', sub { my $value = shift; say $value if $value })->pack;
		_center_window ($mw);
		MainLoop();
	}
	when ($_ < 0) {
		%alias = (
			ant   => "bash /home/lotharla/work/bin/ant-or-make.sh \"\$1\"",
			bash  => "bash \"\$1\"",
			chmod => {
					   "chmod a+x" => "chmod a+x \"\$1\"",
					   "chmod a-x" => "chmod a-x \"\$1\"",
					 },
		);
		$mw = &tk_init(0);
		$mw->configure(-menu => my $menu = $mw->Menu);
		cascades $menu, 'Alias', undef, sub { 
			my( $value, $path )= @_;
			say ask_expression ( $path, $value ) 
		};
		_center_window ($mw);
		MainLoop();
	}
	default {
		1
	}
}

=pod
=cut

