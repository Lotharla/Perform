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
	_is_value
	_value_or_else 
	_getenv
	_set_selection
	_text_dialog
	_menu
	_install_menu
	@_separator
	_clipboard
);
use Manage::Resolver qw(
	has_dollar
	@given 
	given_title
	place_given
	given_meet_dollars
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
sub initialize {
    my( $self ) = @_;
    $self->SUPER::initialize();
	my %data = $self->{data}->();
	$self->{immediate} = $data{options}->{"immediate"} ? 1 : 0;
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
			my $given = @given > 0;
			$submenu->entryconfigure(3, -state => $given ? 'normal' : 'disabled');
			$submenu->entryconfigure(4, -state => $given && $dollar ? 'normal' : 'disabled');
			$submenu->entryconfigure(5, -state => $dollar ? 'normal' : 'disabled');
		}, 
		"Organize aliases ...", sub {
			my ($path, $value) = ask_alias(undef,$self->item);
			$self->item($value) if $path;
		}, 
		"Organize favorites ...", sub {
			organize_favor(undef,0,'',$self->item);
		}, 
		'-' => '',
		"Given ...", sub {
			my @dim = $self->dimension("text");
			if (_text_dialog $self->{window}, \@dim, "Given", \@given) {
				my @parts = split /$_separator[0]/, $self->{window}->title;
				$self->{window}->title(given_title $parts[0]);
			}
		}, 
		'Place given', sub {
			$self->item(place_given($self->item));
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
		$self->history_menu($menu);
	} else {
		$self->options_menu($menu);
	}
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
sub history_menu {
	my $self = shift;
	my $menu = shift;
	$self->SUPER::history_menu($menu) if defined($menu);
}
sub options_menu {
	my $self = shift;
	my $menu = shift;
	$self->SUPER::options_menu($menu) if defined($menu);
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
	$self->pre_select($given[0]);
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
				$found = place_given($found);
				$self->give($found);
			}
		}
	}
}
sub pre_commit {
	my $self = shift;
	my $name = shift;
	my $output = $self->item;
	if (has_dollar($output)) {
		if ($name) {
			my $result = place_given($output);
			if (given_meet_dollars) {
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
1;
