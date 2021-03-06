package Composer;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_chomp
	_boolean
	_is_value
	_value_or_else 
	_getenv
	_setenv
	_set_selection
	_text_dialog
	_menu
	_install_menu
	@_separator
	_clipboard
	_button
	@_inputs 
	_set_inputs
	_inputs_title
);
use Manage::Resolver qw(
	has_dollar
	place_inputs
	inputs_meet_dollars
	resolve_dollar
);
use Manage::Alias qw(
	ask_alias
	resolve_alias
	install_alias_button
);
use Manage::Favor qw(
	organize_favor
	install_favor_button
	find_favorite
	inc_favor
);
use Manage::Settings;
use Manage::EntryComposite;
our @ISA = qw(EntryComposite);
sub new {
	my $class = shift;
    return $class->SUPER::new(@_);
}
sub data {
	my $self = shift;
	return $self->SUPER::data(sub {
		$_[0]->{'alias'} = _value_or_else({}, 'alias', $_[0]);
		$_[0]->{'assoc'} = _value_or_else({}, 'assoc', $_[0]);
		$_[0]->{'environ'} = _value_or_else({}, 'environ', $_[0]);
		$_[0]->{'favor'} = _value_or_else({}, 'favor', $_[0]);
	});
}
sub bottom {
	my $self = shift;
	my $bottom = $self->{window}->Frame->pack(-side => 'bottom');
	my @runopts = @{Settings->strings('run')};
	my $i = 0;
	_button($bottom, 
		[$_,join('-',$self->modifier('',$i),'Enter')], 
		[sub { $self->mod_commit($_[0]) }, $i], 
		0, ++$i) foreach @runopts;
	_button($bottom, 'Cancel', sub { $self->cancel }, 0, ++$i);
	$self->modifier(0);
	$self->{window}->bind('<Alt-Return>', sub { $self->mod_commit(1) });
	$self->{window}->bind('<Control-Return>', sub { $self->mod_commit(2) });
}
sub initialize {
    my( $self ) = @_;
    $self->SUPER::initialize();
	my %data = $self->{data}->();
	$self->{immediate} = _boolean $data{options}->{"immediate"};
    Settings->apply('Associations', %data);
    Settings->apply('Environment', %data);
    my $menu = _menu($self->{window});
	my $submenu;
	$submenu = install_alias_button($menu, 'Alias', sub { 
		my ($path, $value) = @_; 
		$self->item($value) if $value;
		$self->commit if $self->{immediate};
		_set_selection($self->{entry});
	});
	$submenu->configure('-underline', 0);
	$submenu = install_favor_button($menu, 'Favorites', sub { 
		my $f = shift;
		my @fave = find_favorite($f);
		if (@fave > 2) {
			$self->item($fave[2]);
			$self->modifier($fave[3]);
			$self->commit($f);
		} else {
			_set_selection($self->{entry});
		}
	});
	$submenu->configure('-underline', 0);
	$submenu = _install_menu($menu, 
		sub {
			my $dollar = has_dollar($self->item);
			my $inputs = @_inputs > 0;
			$submenu->entryconfigure(4, -state => $inputs ? 'normal' : 'disabled');
			$submenu->entryconfigure(5, -state => $inputs && $dollar ? 'normal' : 'disabled');
			$submenu->entryconfigure(6, -state => $dollar ? 'normal' : 'disabled');
		}, 
		"Organize aliases ...", sub {
			my ($path, $value) = ask_alias(undef,$self->item);
			$self->item($value) if $path;
		}, 
		"Organize favorites ...", sub {
			organize_favor(undef,0,'',$self->item);
		}, 
		'-' => '',
		"Input from clipboard", sub {
			my @dim = $self->dimension("text");
			my $text = _text_dialog $self->{window}, \@dim, "Input from clipboard", '';
			if ($text) {
				_setenv('inputs', _value_or_else($text,1,$text));
				_set_inputs();
				$self->update_title;
			}
		},
		"Input ...", sub {
			my @dim = $self->dimension("text");
			if (_text_dialog $self->{window}, \@dim, 'Inputs', \@_inputs) {
				$self->update_title;
			}
		}, 
		'Place input', sub {
			$self->item(place_inputs($self->item));
			_set_selection($self->{entry});
		},
		"Resolve '\$...'", sub{$self->pre_commit}, 
		'-' => '',
		"Clipper ...", sub {
			use Manage::PageComposite;
			(new PageComposite(title => 'Clipper'))->relaunch;
		}, 
		'Edit'
	);
	$menu->command(-label=>'Settings', -underline=>0, -command => sub{
		$submenu->unpost;
		$self->show_settings;
	});
	if ($self->use_history) {
		$menu = $self->history_menu($menu);
	}
	$menu = $self->options_menu($menu);
	if ($self->{extendMenu}) {
		$self->{extendMenu}($self, $menu);
	}
	$self->update_list;
}
sub show_settings {
	my $self = shift;
	(new Settings(
		title => 'Settings',
		data => $self->{data}, 
		params => ['Associations','Environment']
	))->relaunch;
}
sub options_menu {
	my $self = shift;
	my $menu = $self->SUPER::options_menu(shift);
	$menu->separator;
	$menu->checkbutton(-label=>"immediately", -onvalue => 1, -offvalue => 0, 
		-variable => \$self->{immediate}, 
		-command => sub{
			my %data = $self->{data}->();
			$data{options}->{"immediate"} = $self->{immediate};
		});
	$menu
}
sub update_title {
	my $self = shift;
	my @parts = split /$_separator[0]/, $self->{window}->title;
	$self->{window}->title(_inputs_title _getenv('title', $parts[0]));
}
sub populate {
	my $self = shift;
    my $mode = shift;
    $self->SUPER::populate($mode);
	if ($mode > 1) {
		Manage::Alias::inject($self);
		Manage::Favor::inject($self);
		Manage::Resolver::inject($self);
	}
	$self->pre_select($_inputs[0]);
}
sub pre_select {
	my $self = shift;
	my $expr = shift;
	if (_is_value($expr) && !has_dollar($expr)) {
		my %data = $self->{data}->();
		my $found = Settings->find_assoc($data{'assoc'}, $expr);
		if ($found) {
			$found = resolve_alias($found);
			if ($found) {
				$found = place_inputs($found);
				$self->give($found);
			}
		} else {
			$self->give("\$0");
		}
	}
}
sub pre_commit {
	my $self = shift;
	my $name = shift;
	my $output = $self->item;
	if (has_dollar($output)) {
		if ($name) {
			my $result = place_inputs($output);
			if (inputs_meet_dollars) {
				$self->item($result);
				inc_favor $name, 1;
				return 1;
			}
		}
		$output = resolve_dollar($output);
		return 0 unless $output;
	}
	$self->item($output);
	inc_favor $name, 1 if $name;
	1
}
sub commit {
	my $self = shift;
	if (not $self->pre_commit(@_)) {
		return
	}
	$self->SUPER::commit();
}
sub mod_commit {
	my $self = shift;
	$self->modifier(shift);
	$self->commit
}
1;
