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
	_blessed
	_getenv 
	_value_or_else 
	_make_sure_file
	_tkinit 
	_menu
	_set_selection 
	_replace_text 
	_center_window
	$_entries
	@_separator
);
use Manage::PersistHash;
use Exporter::Easy (
	OK => [ qw(
		resolve_alias
		update_alias
		ask_alias
		install_menu_button
		install_popup_button
	)],
);
my ($obj, $window, %data);
sub inject {
	$obj = $_[0];
	if (_blessed $obj) {
		$window = $obj->{window};
		%data = $obj->{data}->();
	} else {
		undef $obj;
		undef $window;
		%data = @_;
	}
	$data{'alias'} = {} if !exists($data{'alias'});
}
my $path_rex = "\\$_separator[2]";
sub resolve_alias {
	my $path = shift;
	if ($path) {
		my $href = $data{'alias'};
		for (;;) {
			my @parts = split(/$path_rex/, $path, 2);
			my $name = $parts[0];
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
	return if ! $p;
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
		unless (ref($href->{$name}) eq 'HASH') {
			last if ! $value;
			$href->{$name} = {};
		}
		$href = $href->{$name};
		$p = $parts[1]
	}
}
sub iterate_paths {
	my $func = shift;
	my $prefix = _value_or_else '', shift;
	my %hash = _value_or_else sub{%{$data{'alias'}}}, shift;
	foreach my $key (sort keys %hash) {
		my $path = $prefix ? join($_separator[2],$prefix,$key) : $key;
		my $value = $hash{$key};
		given (ref($value)) {
			when ('HASH') {
				iterate_paths($func, $path, $value) 
			}
			default {
				$func->($path)
			}
		}
	}
}
sub ask_alias {
	my ($path, $value)= @_;
	my @buttons = $path ? 
		('OK','Add/Update','Remove','Cancel') :
		('Add/Update','Remove','Close');
	if (! $path && UNIVERSAL::can($obj,'item')) {
		$value = $obj->item;
	}
	my $dlg = $window->DialogBox(
		-title => "Alias",
		-buttons => \@buttons,
		-default_button => $buttons[@buttons > 3 ? 0 : -1]);
	$dlg->Label( -text => 'Path' )->grid(-row => 0, -column => 0);
	my ($be,$en);
	$be = $dlg->BrowseEntry(
		-listcmd => sub {
			$be->delete(0,'end');
			iterate_paths sub {
				$be->insert('end', $_[0]);
			};
		},
		-browsecmd => sub {
			$value = resolve_alias $path
		},
		-variable => \$path
	)->grid(-row => 0, -column => 1);
	$dlg->Label( -text => 'Value' )->grid(-row => 1, -column => 0);
	$en = $dlg->Entry( 
		-takefocus => 1,
		-width => 50,
		-textvariable => \$value
	)->grid(-row => 1, -column => 1);
	_set_selection($en);
ask:
	given($dlg->Show) {
		when ($buttons[@buttons > 3 ? 0 : -1]) {
			return ($path, $value)
		}
		when ($buttons[@buttons > 3 ? 1 : 0]) {
			update_alias $path, $value;
			goto ask;
		}
		when ($buttons[@buttons > 3 ? 2 : 1]) {
			update_alias $path;
			goto ask;
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
		given (ref($value)) {
			when ('HASH') {
				cascades($menu, $path, $func, $value) 
			}
			default {
				$menu->command(
					-label   => $key,
					-command => [ $func, $path, $value ]
				)
			}
		}
	};
}
my $popup = undef;
sub cancel_popup {
	undef $popup if $popup; 
}
my $modify = 0;
sub create_menu {
	my( $menu, $name, $func )= @_;
	$menu->add('checkbutton', 
		-label => 'modify', 
		-onvalue => 1, -offvalue => 0, 
		-variable => \$modify,
		-command => sub { 
			if ($modify) {
				ask_alias "", "";
			}
			cancel_popup; 
		}
	);
	$menu->separator;
	cascades $menu, $name, sub { 
		my ($path, $value) = @_;
		if ($modify) {
			($path, $value) = ask_alias $path, $value;
		}
		$func->($path, $value);
		cancel_popup;
	};
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
sub toggle_popup {
	my ($widget, $func) = @_;
	if (defined $popup) {
		$popup->unpost;
		cancel_popup;
	} else {
		$popup = $window->Menu(-tearoff => 0);
		create_menu $popup, '', $func;
		$popup->post($window->x() + $widget->x(), $window->y() + $widget->y() + $widget->height)
	}
}
sub install_popup_button {
	my ($label, $func) = @_;
	my $btn;
	$btn = $window->Button(
		-text   => $label,
		-command => sub {toggle_popup($btn, $func)}
	);
	$btn
}
given (_value_or_else(0, _getenv('test'))) {
	when (_gt 1) {
		tie %data, "PersistHash", $_entries;
		$window = _tkinit(0);
		install_popup_button('Alias', sub { say pp @_ })->pack;
		_center_window ($window);
		MainLoop();
	}
	when (_gt 0) {
		my $file = "/tmp/.entries";
		_make_sure_file $file;
		tie %data, "PersistHash", $file;
		inject(%data);
		$window = _tkinit(0);
		install_menu_button(_menu($window), 'Alias', sub { say pp @_ });
		_center_window ($window);
		MainLoop();
		dump \%data;
	}
	when (_lt 0) {
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
		_center_window ($window);
		MainLoop();
		dump \%data;
	}
	default {
		1
	}
}
