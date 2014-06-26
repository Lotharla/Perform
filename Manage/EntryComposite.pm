package EntryComposite;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::BrowseEntry;
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path $0);
use Manage::Utils qw(
	dump pp
	_value_or_else
	_indexOf
	_getenv
	_now
	_index_of
	_tkinit
	_center_window
	_set_selection
	_message
	_question
	_popup_menu
);
use Manage::PersistHash;
use Manage::Composite;
our @ISA = qw(Composite);
sub new {
	my $class = shift;
    my $self = $class->SUPER::new(@_);
	return bless($self, $class);
}
sub initialize {
	my $self = shift;
    $self->SUPER::initialize();
	my $mode = $self->mode;
	if ($mode == 0) {
		$self->{widget} = $self->{window}->LabEntry(
			-label => $self->{label}, -labelPack => [ -side => "left" ],
			-width => $self->{width},
			-takefocus => 1,
			-textvariable => \$self->{item});
		$self->{entry} = $self->{widget}->Subwidget("entry");
	} else {
		my $top = $self->{window}->Frame->pack(-side => 'top', -fill=>'x', -expand=>1);
		$top->Label(-text => $self->{label})->pack(-side => "left");
		$self->{widget} = $top->BrowseEntry(
			-width => $self->{width},
			-takefocus => 1,
			-variable => \$self->{item});
		$self->{listbox} = $self->{widget}->Subwidget('slistbox')->Subwidget('scrolled');
		$self->{entry} = $self->{widget}->Subwidget("entry")->Subwidget("entry");
		$self->{arrow} = $self->{widget}->Subwidget("arrow");
		$self->populate($mode);
		$self->{listbox}->bind('<<ListboxSelect>>' => sub{ $self->change_history }) if $mode > 1;
	}
	$self->{widget}->pack(-fill=>'x', -expand=>1);
	$self->{window}->bind('<KeyPress-Return>', sub {$self->commit()});
	$self->{window}->bind('<Control-KeyPress-Up>', sub {$self->move_entry(-1)});
	$self->{window}->bind('<Control-KeyPress-Down>', sub {$self->move_entry(+1)});
	if ($mode > 0) {
		$self->{window}->bind('<KeyPress-Down>', sub {$self->move_point_in_time(+1)});
		$self->{window}->bind('<KeyPress-Up>', sub {$self->move_point_in_time(-1)});
		$self->{popup} = _popup_menu($self->{window}, 
			sub {
				my $differs = $self->new_entry($self->item);
				my $hasNoPoint = $self->{point} < 0;
				$self->{popup}->entryconfigure(0, -state => $differs ? 'normal' : 'disabled');
				$self->{popup}->entryconfigure(1, -state => $differs || $hasNoPoint ? 'disabled' : 'normal');
				$self->{popup}->entryconfigure(2, -state => $hasNoPoint || !$differs ? 'disabled' : 'normal');
			}, 
			'add', sub{ $self->change_history('add') }, 
			'remove', sub{ $self->change_history('remove') }, 
			'update', sub{ $self->change_history('update') }
		) if $mode > 1;
	}
	$self->bottom;
	$self->{entry}->configure(
		-font => $self->{window}->fontCreate(-size => 12)
	);
	_center_window($self->{window});
	_set_selection($self->{entry});
}
sub bottom {
	my $self = shift;
	my $bottom = $self->{window}->Frame->pack(-side => 'bottom');
	my %buttons = (
		ok => $bottom->
			Button(-text => 'OK', -command => sub { $self->commit })->
				pack(-side => "left", -expand=>1),
		cancel => $bottom->
			Button(-text => 'Cancel', -command => sub { $self->cancel })->
				pack(-side => "left", -expand=>1),
	);
	$self->{window}->bind('<Alt-Return>', sub { $self->{modifier} = 'Alt'; $buttons{'ok'}->invoke });
	$self->{window}->bind('<Control-Return>', sub { $self->{modifier} = 'Control'; $buttons{'ok'}->invoke });
}
sub item { $_[0]->{item}=$_[1] if defined $_[1]; $_[0]->{item} }
sub give {
	my $self = shift;
	my $item = shift;
	$self->item($item);
	$self->set_point_in_time($item) if $self->mode > 1;
}
sub data {
	my $self = shift;
	tie my %data, "PersistHash", $self->file;
	$data{'history'} = _value_or_else({}, 'history', \%data);
	return sub {
		%data = @_ if defined $_[0];
		%data
	};
}
sub populate {
	my $self = shift;
    my $mode = shift;
	tie my @items,'Tk::Listbox', $self->{listbox};
	$self->{items} = sub {
		@items = @{$_[0]} if defined $_[0];
		@items
	};
	if ($mode == 1) {
		$self->{items}->($self->{params});
	} else {
		$self->{data} = $self->data();
		$self->history('');
		$self->set_point_in_time($self->item);
	}
}
sub history {
    my $self = shift;
	my $key = shift;
	my $value = shift;
	my %data = $self->{data}->();
	if (defined $key) {
		if ($key) {
			if (!defined $value) {
				return $data{'history'}->{$key};
			} elsif ($value) {
				$data{'history'}->{$key} = $value;
			} else {
				delete $data{'history'}->{$key};
			}
		}
		my %history = %{$data{'history'}};
		my @history = sort values %history;
		$self->{items}->(\@history);
	}
	return %{$data{'history'}};
}
sub selected {
    my $self = shift;
	my $sel = $self->{listbox}->curselection;
    return undef if ! $sel;
	my $i = pop($sel);
	my @items = $self->{items}->();
	$items[$i];
}
sub update_list {
	my $self = shift;
	my $i = _index_of($self->item(), $self->{items}->());
	if ($i > -1) {
		my $sel = $self->{listbox}->curselection;
		$self->{listbox}->selectionClear(pop $sel) if $sel;
		$self->{listbox}->selectionSet($i);
		$self->{listbox}->see($i)
	}
}
sub move_entry {
    my $self = shift;
	my $direct = shift;
	my @items = $self->{items}->();
    my $ptr = _indexOf(_value_or_else('', $self->item), \@items);
	$ptr += $direct;
    $ptr++ if $ptr < -1;
	$ptr %= scalar(@items);
	$self->item($items[$ptr]);
	$self->update_list();
}
sub timeline {
    my $self = shift;
	my %history = $self->history;
	return sort {$a <=> $b} keys %history
}
sub get_point_in_time {
    my $self = shift;
	my $item = shift;
	my %history = $self->history;
	my @timeline = $self->timeline;
	my $ptr = 0;
	foreach (@timeline) {
		last if $item && $history{$_} eq $item;
		$ptr++;
	}
	$ptr < scalar(@timeline) ? $timeline[$ptr] : -1
}
sub set_point_in_time {
    my $self = shift;
	$self->{point} = $self->get_point_in_time(shift);
}
sub new_entry {
    my $self = shift;
	$self->get_point_in_time(@_) < 0
}
sub move_point_in_time {
    my $self = shift;
	my $direct = shift;
	my %history = $self->history;
	my @timeline = $self->timeline;
	if (%history) {
		my $ptr = $self->{point} < 0 ? scalar(@timeline) :_indexOf($self->{point}, \@timeline);
		my $bottom = 0;
		if ($ptr < $bottom) {
			$ptr = $#timeline - ($direct < 0 ? $direct : 0)
		}
		$ptr -= $bottom;
		$ptr += $direct;
		$ptr %= scalar(@timeline) - $bottom;
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
			my $message = sprintf("Are you sure about removing\n'%s'", $self->item);
			if ( $confirm || _question($self->{window}, $message, "Update entry") eq 'yes' ) {
				my $point = $self->get_point_in_time($self->item);
				$self->history($point, '');
				$self->item('');
				$self->{point} = -1;
			}
		}
		when ('update') {
			my $message = sprintf("Are you sure about updating\n'%s'", $self->history($self->{point}));
			if ( $confirm || _question($self->{window}, $message, "Update entry") eq 'yes' ) {
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
	}
}
sub historize {
	my $self = shift;
	my $item = shift;
	if ($self->mode > 1 && $item) {
	    $self->change_history('add', $item);
	}
}
sub commit {
	my $self = shift;
	$self->historize($self->item);
	my $output = _value_or_else '', $self->item;
	print $output;
    $self->SUPER::commit();
}
given (_value_or_else(0, _getenv('test'))) {
	no warnings 'numeric';
	when ($_ > 2) {
		my $file = dirname(dirname abs_path $0) . '/.entries';
		my $ec = new EntryComposite('file', $file, 'label', '<<--History-->>');
		MainLoop();
	}
	when ($_ > 1) {
		my @paths = sort split( /:/, $ENV{PATH});
		my $ec = new EntryComposite('title', 'Environment', 'label', 'Path', 'params', \@paths);
		$ec->give(cwd());
		MainLoop();
	}
	when ($_ > 0) {
		my $ec = new EntryComposite('title', 'Environment', 'label', 'Current');
		$ec->give(cwd());
		MainLoop();
	}
	default {
		1
	}
}
