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
);
use Manage::Resolver qw(
	has_dollar
	@given 
	given_title
	place_given
	resolve_dollar
);
use Manage::Alias qw(
	resolve_alias
	install_menu_button
);
use Manage::Assoc qw(
	assoc_file_types 
	find_assoc
	show_assoc
);
use Manage::EntryComposite;
our @ISA = qw(EntryComposite);
sub new {
	my $class = shift;
    my $self = $class->SUPER::new(@_);
	return bless($self, $class);
}
sub data {
	my $self = shift;
	return $self->SUPER::data(sub {
		$_[0]->{'alias'} = _value_or_else({}, 'alias', $_[0]);
		$_[0]->{'assoc'} = _value_or_else({}, 'assoc', $_[0]);
	});
}
sub initialize {
    my( $self ) = @_;
    $self->SUPER::initialize();
	my $menu = _menu($self->{window});
	my $submenu;
	$submenu = install_menu_button($menu, 'Alias', sub { 
		my ($path, $value) = @_; 
		$self->item($value) if $value;
		_set_selection($self->{entry});
	});
	$submenu->configure('-underline', 0);
	$menu->command(-label=>'Associations', -underline=>1, -command => sub{
		$submenu->unpost;
		show_assoc
	});
	$submenu = _install_menu($menu, 
		sub {
			my $dollar = has_dollar($self->item);
			my $given = @given > 0;
			$submenu->entryconfigure(1, -state => $given ? 'normal' : 'disabled');
			$submenu->entryconfigure(2, -state => $given && $dollar ? 'normal' : 'disabled');
			$submenu->entryconfigure(3, -state => $dollar ? 'normal' : 'disabled');
		}, 
		"Clipper ...", sub {
			use Manage::ViewComposite;
			(new ViewComposite(
				title => 'Clipper', 
			))->relaunch;
		}, 
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
		'Edit'
	);
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
		Manage::Assoc::inject($self);
		Manage::Resolver::inject($self);
	}
	$self->pre_select($given[0]);
}
sub pre_select {
	my $self = shift;
	my $expr = shift;
	if (_is_value($expr) && !has_dollar($expr)) {
		my $found = find_assoc($expr);
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
	my $output = $self->item;
	if (has_dollar($output)) {
		$output = resolve_dollar($output, assoc_file_types(), @_);
		return 0 if ! $output;
	}
	$self->item($output);
	1
}
sub commit {
	my $self = shift;
	if (not $self->pre_commit) {
		return
	}
	$self->SUPER::commit();
}
1;
