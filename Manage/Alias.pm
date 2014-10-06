package Manage::Alias;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::Menu;
use Tk::DialogBox;
use Tk::BrowseEntry;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_gt _lt
	_is_blessed
	_is_hash_ref
	_is_value
	_getenv_once 
	_value_or_else 
	_make_sure_file
	_tkinit 
	_menu
	_set_selection 
	_replace_text 
	_center_window
	$_entries
	@_separator
	_visit_sorted_tree
	_dimension
	@_inputs
);
use Manage::PersistHash;
use Manage::Settings;
use Manage::Resolver qw(
	is_dollar has_dollar dollar_amount make_dollar 
	make_value
	place_inputs
	resolve_dollar
);
use Exporter::Easy (
	OK => [ qw(
		resolve_alias
		update_alias
		visit_alias_tree
		aliases
		ask_alias
		install_alias_button
		install_alias_popup_button
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
	$data{'alias'} = {} unless exists($data{'alias'});
}
my $path_rex = "\\$_separator[2]";
sub resolve_alias {
	my $path = shift;
	if ($path) {
		my $href = $data{'alias'};
		for (;;) {
			my @parts = split(/$path_rex/, $path, 2);
			my $name = @parts > 0 ? $parts[0] : '';
			if (@parts < 2) {
				return $href->{$name};
			} elsif (not exists $href->{$name}) {
				last;
			}
			$href = $href->{$name};
			$path = $parts[1]
		}
	}
	''
}
sub update_alias {
	my ($path, $value) = @_;
	my $href = $data{'alias'};
	my $p = $path;
	return unless $p;
	for (;;) {
		my @parts = split(/$path_rex/, $p, 2);
		my $name = $parts[0];
		if (@parts < 2) {
			if ($value) {
				$href->{$name} = $value;
			} else {
				delete $href->{$name};
				if (keys %$href < 1) {
					my $len = length($path) - length($name) - 1;
					update_alias(substr($path, 0, $len)) if $len;
				}
			}
			last;
		}
		unless (_is_hash_ref($href->{$name})) {
			last unless $value;
			my $v = $href->{$name};
			$href->{$name} = {};
			$href->{$name}->{''} = $v if _is_value $v;
		}
		$href = $href->{$name};
		$p = $parts[1]
	}
}
sub visit_alias_tree {
	_visit_sorted_tree $data{'alias'}, shift
}
sub aliases {
	my @aliases;
	_visit_sorted_tree $data{'alias'}, sub {
		push @aliases, $_[0] unless has_dollar($_[0]);
	};
	@aliases
}
sub ask_alias {
	my ($path, $value, $three_buttons)= @_;
	my $modopts = Settings->strings('mod');
	my @modopts = $three_buttons
		? @{$modopts}
		: ('OK',$modopts->[0],$modopts->[1],'Cancel');
	my $dlg = $window->DialogBox(
		-title => "Alias",
		-buttons => \@modopts,
		-default_button => $modopts[$three_buttons ? -1 : 0]);
	$dlg->Label( -text => 'Path' )->grid(-row => 0, -column => 0);
	my ($be,$en);
	$be = $dlg->BrowseEntry(
		-listcmd => sub {
			$be->delete(0,'end');
			visit_alias_tree sub {
				$be->insert('end', $_[0]);
			};
		},
		-browsecmd => sub {
			$value = resolve_alias $path
		},
		-variable => \$path
	)->grid(-row => 0, -column => 1);
	$dlg->Label( -text => 'Value' )->grid(-row => 1, -column => 0);
	my @dim = _dimension($obj,'entry',50);
	$en = $dlg->Entry( 
		-takefocus => 1,
		-width => $dim[0],
		-textvariable => \$value
	)->grid(-row => 1, -column => 1);
	_set_selection($en);
	given($dlg->Show) {
		when ($modopts[$three_buttons ? -1 : 0]) {
			return ($path, $value)
		}
		when ($modopts[$three_buttons? 0 : 1]) {
			update_alias $path, $value;
			ask_alias($path, $value)
		}
		when ($modopts[$three_buttons ? 1 : 2]) {
			update_alias $path;
			ask_alias($path, $value)
		}
	}
	()
}
sub cascades {
	my( $menu, $name, $func, $href )= @_;
	my @parts = split(/$path_rex/, $name);
	$menu = $menu->cascade(
		-label   => $parts[$#parts],
		-tearoff => 0
	) if $name;
	my %hash = $href ? %{$href} : %{$data{'alias'}};
	foreach my $key (sort keys(%hash)) {
		my $path = $href ? join($_separator[2],$name,$key) : $key;
		my $value = $hash{$key};
		if (is_dollar $key) {
			my $a = dollar_amount($key);
			my $val = make_value($a,'');
			if ($val) {
				given ($a->[0]) {
					when ('*') {
						for (split(/$path_rex/, $val)) {
							my $p = join($_separator[2],$name,$_);
							my $v = place_inputs($value, $_);
							$menu->command(
								-label   => $_,
								-command => [ $func, $p, $v ]
							)
						}
					}
				}
			}
			next;
		}
		if (_is_hash_ref($value)) {
			cascades($menu, $path, $func, $value) 
		} else {
			$menu->command(
				-label   => $key,
				-command => [ $func, $path, $value ]
			)
		}
	};
}
my $popup = undef;
sub cancel_popup {
	undef $popup if $popup; 
}
my $modify = 0;
sub create_alias_menu {
	my( $menu, $name, $func, $modcheck )= @_;
	if ($modcheck) {
		$menu->add('checkbutton', 
			-label => 'modify', 
			-onvalue => 1, -offvalue => 0, 
			-variable => \$modify,
			-command => sub { 
				if ($modify) {
					ask_alias();
				}
				cancel_popup; 
			}
		);
		$menu->separator;
	}
	cascades $menu, $name, sub { 
		my ($path, $value) = @_;
		if ($modify) {
			($path, $value) = ask_alias $path, $value;
		}
		$func->($path, $value);
		cancel_popup;
	};
}
sub install_alias_button {
	my ($menu, $label, $func) = @_;
	my $btn;
	$btn = $menu->Menubutton(
		-text => $label, 
		-tearoff => 0,
		-postcommand => sub {
			$btn->menu->delete(0, 'end');
			create_alias_menu $btn->menu, '', $func
		}
	);
	$btn
}
sub toggle_popup {
	my ($widget, $func) = @_;
	if (defined $popup) {
		$popup->unpost;
		cancel_popup;
	} else {
		$popup = $window->Menu(-tearoff => 0);
		create_alias_menu $popup, '', $func, 1;
		$popup->post($window->x() + $widget->x(), $window->y() + $widget->y() + $widget->height)
	}
}
sub install_alias_popup_button {
	my ($label, $func) = @_;
	my $btn;
	$btn = $window->Button(
		-text   => $label,
		-command => sub {toggle_popup($btn, $func)}
	);
	$btn
}
given (_getenv_once('__test', 0)) {
	when (_gt 2) {
		tie %data, "PersistHash", $_entries;
		$window = _tkinit(0);
		install_alias_popup_button('Alias', sub { say pp @_ })->pack;
		_center_window $window, 1;
	}
	when (_gt 1) {
		my $file = "/tmp/.entries";
		_make_sure_file $file;
		tie %data, "PersistHash", $file;
		inject(%data);
		$window = _tkinit(0);
		install_alias_button(_menu($window), 'Alias', sub { say pp @_ });
		_center_window $window, 1;
		dump \%data;
	}
	when (_gt 0) {
		%data = (
			alias => {
				ant   => "bash /home/lotharla/work/bin/ant-or-make.sh \"\$1\"",
				bash  => "bash \"\$1\"",
				chmod => {
						   "chmod a+x" => "chmod a+x \"\$1\"",
						   "chmod a-x" => "chmod a-x \"\$1\"",
						 },
			},
		);
#		%data = ( alias => {} );
		$window = _tkinit(0);
		cascades _menu($window), 'Alias', sub { 
			say pp ask_alias(@_);
		};
		_center_window $window, 1;
		dump \%data;
	}
	default {
		1
	}
}
