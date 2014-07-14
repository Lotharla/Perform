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
	_menu
	_install_menu
);
use Manage::Resolver qw(
	has_dollar
	@given 
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
			my $possible = has_dollar($self->item);
			$submenu->entryconfigure(0, -state => $possible ? 'normal' : 'disabled');
			$submenu->entryconfigure(1, -state => $possible ? 'normal' : 'disabled');
		}, 
		"Resolve '\$...'", sub{$self->pre_commit}, 
		'Place given', sub {
			$self->item(place_given($self->item));
			_set_selection($self->{entry});
		},
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
sub data {
	my $self = shift;
	tie my %data, "PersistHash", $self->file;
	$data{'alias'} = _value_or_else({}, 'alias', \%data);
	$data{'assoc'} = _value_or_else({}, 'assoc', \%data);
	$data{'history'} = _value_or_else({}, 'history', \%data);
	return sub {
		%data = @_ if defined $_[0];
		%data
	};
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
sub save {
	my $self = shift;
	if ($self->{data}) {
		my %data = $self->{data}->();
		PersistHash::DESTROY \%data;     
	}
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
				$self->item($found);
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
sub finalize {
	my $self = shift;
	$self->save
}
1;
