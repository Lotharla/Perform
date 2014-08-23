package EntryComposite;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::BrowseEntry;
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_gt _lt _eq _ne
	_value_or_else
	_index_of
	_getenv_once
	_now
	_call
	_index_of
	_tkinit
	_center_window
	_set_selection
	_message
	_question
	_create_popup_menu
	_install_menu
	$_entries $_history
);
use Manage::PersistHash;
use Manage::Composite;
our @ISA = qw(Composite);
sub new {
	my $class = shift;
    return $class->SUPER::new(@_);
}
sub data {
	my $self = shift;
	my $func = shift;
	return $self->SUPER::data(sub {
		$_[0]->{'options'} = _value_or_else({}, 'options', $_[0]);
		_call [$func, $_[0]];
	});
}
sub use_history {
	$_[0]->{history_db} && length($_[0]->{history_db}) > 0
}
sub listmode {
	my ($self,$listmode) = @_;
	if ($self->{data}) {
		my %data = $self->{data}->();
		$data{options}->{"list-mode"} = $listmode if $listmode;
		$listmode = $data{options}->{"list-mode"};
	}
	_value_or_else 1, $listmode
}
sub initialize {
	my $self = shift;
    $self->SUPER::initialize();
    $self->{options} = $self->{options} ? $self->{options} : {};
	$self->{mode} = $self->mode();
	$self->{listmode} = $self->listmode();
	if ($self->{options}->{"list-multiple"}) {
		$self->{mode} = 1;
		$self->{listmode} = 1;
	}
	($self->{width}, $self->{height}) = $self->dimension('list');
	$self->top($self->{listmode});
	$self->{window}->bind('<KeyPress-Return>', sub {$self->commit});
	$self->{window}->bind('<KeyPress-Up>', sub {$self->move_entry(-1)});
	$self->{window}->bind('<KeyPress-Down>', sub {$self->move_entry(+1)});
	if ($self->use_history) {
		$self->{window}->bind('<Control-KeyPress-Down>', sub {$self->move_point_in_time(+1)});
		$self->{window}->bind('<Control-KeyPress-Up>', sub {$self->move_point_in_time(-1)});
		$self->history_menu;
	} else {
		$self->options_menu;
	}
	$self->bottom;
	$self->{entry}->configure(
		-font => $self->{window}->fontCreate(-size => 12)
	);
	_center_window($self->{window});
	_set_selection($self->{entry});
}
sub top {
	my $self = shift;
	my $listmode = shift;
	$self->{top} = 
		$self->{window}->Frame->pack(-side => 'top', -padx=>1, -pady=>5, -fill=>'x', -expand=>1);
	if ($listmode == 0) {
		my $widget = $self->{top}->LabEntry(
			-label => $self->{label}, -labelPack => [ -side => "left" ],
			-width => $self->{width},
			-takefocus => 1,
			-textvariable => \$self->{item}
		)->pack(-fill=>'x', -expand=>1);
		$self->{entry} = $widget->Subwidget("entry");
		$self->{listbox} = undef;
	} else {
		$self->{top}->Label(-text => $self->{label})->pack(-side => "left");
		if ($listmode > 0) {
			my $widget = $self->{top}->Frame()->pack(-side => 'top', -fill=>'x', -expand=>1);
			$self->{entry} = $widget->Entry(
				-width =>  $self->{width},
				-takefocus => 1,
				-textvariable => \$self->{item}
			)->pack(-side => 'top', -fill=>'x', -expand=>1);
			$self->{listbox} = $widget->Scrolled("Listbox", 
				-height => $self->{height},
				-selectmode => 'multiple', 
				-scrollbars => 'osoe'
			)->pack(-side => 'bottom', -fill=>'both', -expand=>1);
		} else {
			my $widget = $self->{top}->BrowseEntry(
				-width => $self->{width},
				-takefocus => 1,
				-variable => \$self->{item}
			)->pack(-fill=>'x', -expand=>1);
			$self->{listbox} = $widget->Subwidget('slistbox')->Subwidget('scrolled');
			$self->{entry} = $widget->Subwidget("entry")->Subwidget("entry");
			$self->{arrow} = $widget->Subwidget("arrow");
		}
	}
	$self->populate($self->{mode});
	if ($self->{listbox}) {
		$self->{listbox}->bind('<<ListboxSelect>>' => sub { 
			$self->item($self->selected) if $self->permanent_list;
			$self->change_history if $self->use_history;
		});
	}
	$self->{entry}->bind('<Any-KeyPress>', sub {
#		$self->{listbox}->selectionClear(0,'end') if $self->permanent_list;
	});
}
sub bottom {
	my $self = shift;
	my $bottom = $self->{window}->Frame->pack(-side => 'bottom');
	my %buttons = (
		ok => $bottom->
			Button(-text => 'OK', -command => sub { $self->commit })->
				grid(-row => 0, -column => 0, -padx => 10, -pady => 5),
		cancel => $bottom->
			Button(-text => 'Cancel', -command => sub { $self->cancel })->
				grid(-row => 0, -column => 1, -padx => 10, -pady => 5),
	);
	$self->{window}->bind('<Alt-Return>', sub { $self->{modifier} = 'Alt'; $buttons{'ok'}->invoke });
	$self->{window}->bind('<Control-Return>', sub { $self->{modifier} = 'Control'; $buttons{'ok'}->invoke });
}
sub history_menu {
	my $self = shift;
	my $menu = shift;
	my $popup = !defined($menu);
	$menu = _install_menu(
		$popup ? $self->{window} : $menu, 
		sub {
			my $differs = $self->is_new_entry($self->item);
			my $hasNoPoint = $self->{point} < 0;
			my $hasNoHistory = $self->{point} < -1;
			$menu->entryconfigure(0, -state => $hasNoHistory ? 'disabled' : 'normal');
			$menu->entryconfigure(1, -state => $hasNoHistory ? 'disabled' : 'normal');
			$menu->entryconfigure(3, -state => $differs ? 'normal' : 'disabled');
			$menu->entryconfigure(4, -state => $self->selection && !$differs? 'normal' : 'disabled');
			$menu->entryconfigure(5, -state => !$hasNoPoint && $differs ? 'normal' : 'disabled');
		}, 
		'go to next', sub {$self->move_point_in_time(+1)}, 
		'go to previous', sub {$self->move_point_in_time(-1)}, 
		'-', sub{}, 
		'add to history', sub{ $self->change_history('add') }, 
		'remove from history', sub{ $self->change_history('remove') }, 
		'update history', sub{ $self->change_history('update') },
		$popup ? undef : 'History'
	);
	$self->options_menu($menu);
}
sub permanent_list {
	$_[0]->{listmode} > 0
}
sub options_menu {
	my $self = shift;
	my $menu = shift;
	my $popup = !defined($menu);
	$menu->add('separator') unless $popup;
	$menu = _install_menu(
		$popup ? $self->{window} : $menu, 
		sub {
			$menu->entryconfigure(0, -state => 'normal');
		}, 
		$popup ? undef : 'Options'
	);
	$menu->add('checkbutton', 
		-label => 'permanent list', 
		-onvalue => 1, -offvalue => -1, 
		-variable => \$self->{listmode},
		-command => sub {
			$self->listmode($self->{listmode});
			$self->cancel(1);
		}
	);
	$menu->add('command', 
		-label => 'list dimension', 
		-command => sub {
			if ($self->ask_dimension('list')) {
				$self->cancel(1);
			}
		}
	);
	$menu->add('command', 
		-label => 'text dimension', 
		-command => sub {
			if ($self->ask_dimension('text')) {
				$self->save;
			}
		}
	);
}
sub item { 
	$_[0]->{item}=$_[1] if defined $_[1]; $_[0]->{item} 
}
sub give {
	my $self = shift;
	my $item = shift;
	$self->item($item);
	if ($self->use_history) {
		$self->set_point_in_time($item);
		$self->update_list;
	}
}
sub populate {
	my $self = shift;
    my $mode = shift;
    return unless $mode;
	tie my @items,'Tk::Listbox', $self->{listbox};
	$self->{items} = sub {
		if ($_[0]) {
			pop @items while @items;
			push @items, @{$_[0]};
		}
		@items
	};
	if ($self->use_history) {
		tie my %data, "PersistHash", $self->{history_db}, 1;
		$self->{hist} = sub { %data };
		$self->history('');
		$self->set_point_in_time($self->item);
	} else {
		$self->{items}->($self->{params});
	}
}
sub history {
    my $self = shift;
	my $key = shift;
	my $value = shift;
	my %data = $self->{hist}->();
	if (defined $key) {
		if ($key) {
			if (!defined $value) {
				return $data{hash}->{$key};
			} elsif ($value) {
				$data{hash}->{$key} = $value;
			} else {
				delete $data{hash}->{$key};
			}
		}
		my %history = %{$data{hash}};
		my @history = sort values %history;
		$self->{items}->(\@history);
	}
	return %{$data{hash}};
}
sub selection {
    my $self = shift;
	$self->{listbox}->curselection
}
sub selected {
    my $self = shift;
	my $sel = $self->selection;
    return undef unless $sel;
    my @sel = sort {$a<=>$b} @{$sel};
    return undef if @sel < 1;
	my @items = $self->{items}->();
	if ($self->{options}->{"list-multiple"}) {
		join " ", @items[@sel];
	} else {
		$sel = shift(@sel);
		$items[$sel];
	}
}
sub update_list {
	my $self = shift;
	my $item = _value_or_else $self->item(), shift;
	my $i = _index_of($item, $self->{items}->());
	if ($i > -1) {
		my $sel = $self->selection;
		$self->{listbox}->selectionClear(0,'end') if $sel;
		$self->{listbox}->selectionSet($i);
		$self->{listbox}->see($i)
	}
}
sub move_entry {
    my $self = shift;
	my $direct = shift;
	return unless $self->{items};
	my @items = $self->{items}->();
    my $ptr = _index_of(_value_or_else('', $self->item), @items);
	$ptr += $direct;
    $ptr++ if $ptr < -1;
	$ptr %= @items;
	$self->item($items[$ptr]);
	$self->update_list();
}
sub timeline {
    my $self = shift;
	my %history = $self->history;
	return sort {$a <=> $b} keys %history
}
sub get_index_on_timeline {
    my $self = shift;
	my $item = shift;
	if ($item) {
		my %history = $self->history;
		my $index = 0;
		foreach (@_) {
			my $it = $history{$_};
			if ($it eq $item) {
				return $index;
			}
			$index++;
		}
	}
	-1
}
sub get_point_in_time {
    my $self = shift;
	my @timeline = $self->timeline;
	return -2 if @timeline < 1;
	my $index = $self->get_index_on_timeline(shift, @timeline);
	$index > -1 ? 
		$timeline[$index] : 
		-1
}
sub set_point_in_time {
    my $self = shift;
	$self->{point} = $self->get_point_in_time(shift);
}
sub is_new_entry {
    my $self = shift;
	my $item = shift;
	return undef unless $item;
	$self->get_point_in_time($item) < 0
}
sub move_point_in_time {
    my $self = shift;
	my $direct = shift;
	my %history = $self->history;
	if (%history) {
		my @timeline = $self->timeline;
		my $ptr = $self->{point} < 0 ? @timeline : _index_of($self->{point}, @timeline);
		my $bottom = 0;
		if ($ptr < $bottom) {
			$ptr = $#timeline - ($direct < 0 ? $direct : 0)
		}
		$ptr -= $bottom;
		$ptr += $direct;
		$ptr %= @timeline - $bottom;
		$ptr += $bottom;
		$self->{point} = $timeline[$ptr];
		$self->item($history{$self->{point}});
	}
	_set_selection($self->{entry});
	$self->update_list();
}
sub change_history {
    my $self = shift;
	my $oper = shift;
	my $confirm = shift;
	given ($oper) {
		when ('remove') {
			my @sel = @{$self->selection};
			my $message = sprintf("Are you sure about removing\n'%s'", 
				(@sel > 1 ? @sel . " items" : $self->item));
			if ( $confirm || _question($self->{window}, $message, "Change history") eq 'yes' ) {
    			if (@sel > 1) {
					my @items = $self->{items}->();
					foreach (@sel) {
						my $point = $self->get_point_in_time($items[$_]);
						$self->history($point, '');
					}
    			} else {
					my $point = $self->get_point_in_time($self->item);
					$self->history($point, '');
					$self->item('');
    			}
				$self->{point} = -1;
			}
		}
		when ('update') {
			my $message = sprintf("Are you sure about updating\n'%s'", $self->history($self->{point}));
			if ( $confirm || _question($self->{window}, $message, "Change history") eq 'yes' ) {
				$self->history($self->{point}, $self->item);
			}
		}
		when ('add') {
			my $item = _value_or_else $self->item, $confirm;
			if ($confirm) {
				my $point = $self->get_point_in_time($confirm);
			    $self->history($point, '') if $point > 0;
			}
			$self->history(_now(), $item);
		}
		default {
			$self->set_point_in_time($self->selected);
			$self->{entry}->icursor(0);
		}
		$self->update_list;
	}
}
sub save {
	my $self = shift;
	if ($self->{hist}) {
		my %data = $self->{hist}->();
		PersistHash::DESTROY \%data;     
	}
    $self->SUPER::save();
}
sub commit {
	my $self = shift;
	my $item = $self->item;
	if ($self->use_history && $item) {
	    $self->change_history('add', $item);
	}
	my $output = _value_or_else '', $item;
	print $output;
    $self->SUPER::commit();
}
given (_getenv_once('test', 0)) {
	when (_gt 1) {
		my $ec = new EntryComposite('file', $_entries, 'history_db', $_history, 'label', '<<--History-->>');
		relaunch $ec;
	}
	when (_gt 0) {
		my @paths = sort split( /:/, $ENV{PATH});
		my $ec = new EntryComposite('title', 'Environment', 'label', 'PATH', 'params', \@paths, 
			'options', {"list-multiple" => 1});
		$ec->give(cwd());
		relaunch $ec;
	}
	when (_lt 0) {
		my $ec = new EntryComposite('title', 'Environment', 'label', 'Current');
		$ec->give(cwd());
		relaunch $ec;
	}
	when (_lt -1) {
		my @paths = sort split( /:/, $ENV{PATH});
		my $ec = new EntryComposite('title', 'Environment', 'label', 'path', 'params', \@paths);
		$ec->give(cwd());
		relaunch $ec;
	}
	when (_lt -2) {
		my $ec = new EntryComposite('file', $_entries, 'history_db', $_history, 'label', '<<--History-->>');
		relaunch $ec;
	}
	default {
		1
	}
}
