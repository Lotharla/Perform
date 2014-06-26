package Composer;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0);
use Manage::Utils qw(
	dump pp
	_chomp
	_combine
	_value_or_else 
	_getenv
	_set_selection
);
use Manage::Given qw(
	hasDollar
	place_given
	@given 
	replace_dollar
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
	if ($self->mode > 1) {
		$self->{window}->configure(-menu => my $menu = $self->{window}->Menu());
		my @menus;
		push @menus, install_menu_button($menu, 'Alias', sub { 
			my $value = shift; 
			$self->item($value) if $value;
			_set_selection($self->{entry});
		});
		$menus[0]->configure('-underline', 0);
		my $submenu;
		push @menus, $menu->command(-label=>'Associations', -underline=>1, -command => sub{
			$submenu->unpost;
			show_assoc
		});
		$submenu = $menu->cascade(-label=>'Edit', -underline=>0, -tearoff => 'no',
			-postcommand => sub{
				my $possible = hasDollar($self->item);
				$submenu->entryconfigure(0, -state => $possible ? 'normal' : 'disabled');
				$submenu->entryconfigure(1, -state => $possible ? 'normal' : 'disabled');
			}
		)->cget('-menu');
		$submenu->command(-label=>'Place given', -command => sub{
			$self->item(place_given($self->item));
			_set_selection($self->{entry});
		});
		$submenu->command(-label=>"Replace '\$...'", -command => sub{$self->prepare_output});
		push @menus, $submenu;
		if ($self->{extendMenu}) {
			$self->{extendMenu}($self, $menu);
		}
	}
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
		Manage::Given::inject($self);
	}
	@given = _getenv('given');
	$self->pre_select($given[0]);
}
sub save {
	my $self = shift;
	my %data = $self->{data}->();
	PersistHash::DESTROY \%data;     
}
sub pre_select {
	my $self = shift;
	my $entry = shift;
	if (length($entry) > 0 && !hasDollar($entry)) {
		my $found = find_assoc($entry);
		if ($found) {
			$found = resolve_alias($found);
			if ($found) {
				$found = place_given($found);
				$self->item($found);
			}
		}
	}
}
sub prepare_output {
	my $self = shift;
	my $output = $self->item;
	if (hasDollar($output)) {
		$output = place_given($self->item);
		$output = replace_dollar($output, assoc_file_types(), @_) if hasDollar($output);
		return 0 if not $output;
	}
	$self->item($output);
	1
}
sub commit {
	my $self = shift;
	if (not $self->prepare_output) {
		return
	}
	$self->SUPER::commit();
}
sub finalize {
	my $self = shift;
	$self->save
}
1;
