package Performer;
use strict;
use warnings;
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0);
use Manage::utils qw(
	dump pp
	_value_or_else 
	_set_selection
);
use Manage::dollar qw(
	isDollar hasDollar dollar_amount make_Dollar 
	get_dollars set_dollars detect_dollar 
	place_given
	@given %dollars
);
use Manage::alias qw(
	%alias 
	install_menu_button
);
use Manage::assoc qw(
	%assoc 
	assoc_file_types 
	find_assoc
	show_assoc
);
use Manage::EntryComposite;
our @ISA = qw(EntryComposite);    # inherits from
sub new {
	my $class = shift;
    my $self = $class->SUPER::new(@_);
	return bless($self, $class);
}
my @menus;
my %buttons;
sub initialize {
    my( $self ) = @_;
    $self->SUPER::initialize();
	if ($self->mode > 1) {
		$self->{window}->configure(-menu => my $menu = $self->{window}->Menu());
		push @menus, install_menu_button($menu, 'Alias', sub { 
			my $value = shift; 
			$self->item($value) if $value 
		});
		push @menus, $menu->command(-label=>'Associations', -command => \&show_assoc);
		push @menus, $menu->command(-label=>'Help');
	}
	my $bottom = $self->{window}->Frame->pack(-side => 'bottom');
	$buttons{'ok'} = $bottom->Button(-text => 'OK',
	            	-command => sub {$self->commit()})->pack(-side => "left", -expand=>1);
	$buttons{'cancel'} = $bottom->Button(-text => 'Cancel',
	            	-command => sub {cancel($self)})->pack(-side => "left", -expand=>1);
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
    $self->SUPER::populate();
	if ($mode > 1) {
		my %data = $self->{data}->();
		%alias = %{$data{"alias"}};
		%assoc = %{$data{"assoc"}};
	}
	$self->pre_select($given[0]);
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
				$self->{_item} = $found;
			}
		}
	}
}
sub commit {
    my( $self ) = @_;
    $self->SUPER::commit();
}
1;