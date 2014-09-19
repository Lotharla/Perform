package Settings;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::NoteBook;
use Tk::MListbox;
use Tk::BrowseEntry;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	tmpdir
	catfile
	catdir
	_gt _lt
	_is_hash_ref
	_value_or_else 
	_getenv_once
	_setenv
	_file_exists
	_fileparse
	_files_in_dir
	_contents_of_file
	_contents_to_file
	_center_window
	_ask_file
	_question
	_rndstr
	_button
	_set_selection
	_create_popup_menu
	_delete_popup_menu
	$_entries
	_flip_hash
	_text_info
	_visit_sorted_tree
	_find_widget
);
use Manage::Resolver qw(
	clipdir
	next_clip
	get_clip
	has_dollar
);
use Manage::Composite;
our @ISA = qw(Composite);
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
	});
}
sub initialize {
    my( $self ) = @_;
    $self->{data} = $self->data() unless $self->{data};
    $self->SUPER::initialize();
	$self->{book} = $self->{window}->NoteBook(
	)->grid(-row => 0, -column => 0, -columnspan => 2);
	$self->populate($self->mode);
	$self->bottom;
	_center_window($self->{window});
}
sub bottom {
	my $self = shift;
	my $bottom = $self->{window}->Frame->grid(-row => 2, -column => 0, -columnspan => 2);
	my @modopts = @{strings('Settings', 'mod')};
	_button($bottom, $modopts[0], sub {
		my $name = $self->{name};
		$self->modify($name, $self->{key}, $self->{value});
		$self->refill($name);
	}, 0, 0);
	_button($bottom, $modopts[1], sub {
		my $name = $self->{name};
		$self->modify($name, $self->{key});
		$self->refill($name);
	}, 0, 1);
	_button($bottom, $modopts[2], sub { $self->cancel }, 0, 2);
}
sub populate {
	my $self = shift;
    my $mode = shift;
    $self->{names} = {};
	my @params = @{$self->{params}};
	foreach (@params) {
		$self->page($_);
	}
}
sub page {
	my $self = shift;
	my $name = shift;
	my $frm;
	my $page = $self->{book}->add($name, 
		-label => $name, 
		-raisecmd => sub {
			if ($self->{name}) {
				@{$self->{names}->{$self->{name}}}[1,2] = ($self->{key}, $self->{value});
			}
			$self->{name} = $self->{book}->raised;
			($self->{key}, $self->{value}) = @{$self->{names}->{$self->{name}}}[1,2];
			_set_selection(_find_widget($frm, 'entry'));
		} 
	);
	$frm = $page->Frame->pack(-side => 'bottom', -fill => 'x', -expand => 1);
	my $widget = $page->Scrolled('MListbox',
		-selectmode => 'browse', 
		-scrollbars => 'oe',
	    -bd => 2,
	    -relief => 'sunken'
	)->pack(-side => 'top', -fill => 'x', -expand => 1);
	my %data = $self->{data}->();
	given ($name) {
		when ('Associations') {
			$self->{names}->{$name} = [$data{'assoc'},'','',$widget];
			$widget->columnInsert('end', -text => "Glob", -width => 30);
			$widget->columnInsert('end', -text => "Alias", -width => 20);
		}
		when ('Environment') {
			$self->{names}->{$name} = [$data{'environ'},'','',$widget];
			$widget->columnInsert('end', -text => "Name", -width => 20);
			$widget->columnInsert('end', -text => "Value", -width => 30);
		}
	}
	$widget->bindRows("<Button-1>", sub {
	    my @sel = $widget->curselection;
	    if (@sel == 1) {
			($self->{key}, $self->{value}) = $widget->getRow($sel[0]);
	    }
	});
	$self->refill($name);
	my ($en,$be);
	$en = $frm->Entry( 
		-width => 25,
		-textvariable => \$self->{key}
	)->grid(-row => 1, -column => 0, -padx => 5);
	given ($name) {
		when ('Associations') {
			$be = $frm->BrowseEntry(
				-width => 25,
				-listcmd => sub {
					$be->delete(0,'end');
					my %data = $self->{data}->();
					_visit_sorted_tree $data{'alias'}, sub {
						$be->insert('end', $_[0]) unless has_dollar $_[0];
					};
				},
				-variable => \$self->{value}
			)->grid(-row => 1, -column => 1, -padx => 5);
		}
		default {
			$en = $frm->Entry( 
				-width => 25,
				-textvariable => \$self->{value}
			)->grid(-row => 1, -column => 1, -padx => 5);
		}
	}
	$self->{book}->raise($name);
}
sub refill {
	my $self = shift;
	my $name = shift;
	my $widget = $self->{names}->{$name}->[3];
	$widget->delete(0, 'end');
	my %hash = %{$self->{names}->{$name}->[0]};
	foreach (keys %hash) {
		$widget->insert('end', [$_, $hash{$_}])
	}
}
sub modify {
	my $self = shift;
	my $name = shift;
	my $href = $self->{names}->{$name}->[0];
	Settings->modify_setting($href, @_);
	Settings->apply($name, $name=>$href)
}
sub modify_setting {
	my $class = shift;
	my $href = shift;
	my $key = shift;
	my $value = shift;
	if ($value) {
		$href->{$key} = $value;
	} else {
		delete $href->{$key};
	}
}
sub find_assoc {
	my $class = shift;
	my $href = shift;
	my $glob = shift;
	my @parts = _fileparse($glob);
	$parts[1] = $parts[0] . $parts[2];
	sub _is_glob {
		shift =~ m/\*|\?/
	}
	sub _glob_match {
		my $glob = shift;
		$glob =~ s/\./\\./g;
		$glob =~ s/\*/.*/g;
		$glob =~ s/\?/.?/g;
		my $str = shift;
		return $str =~ /$glob/;
	}
	foreach my $key (keys %$href) {
		if (_is_glob($key)) {
			return $href->{$key} if _glob_match $key, $parts[1];
		}
	}
	_value_or_else( _value_or_else('', $parts[2], $href), $parts[1], $href);
}
my @assoc_file_types;
my %environ_settings;
sub apply {
	my $class = shift;
	my $name = shift;
	my %data = @_;
	given ($name) {
		when ('Associations') {
			my $href = $data{'assoc'};
			if (_is_hash_ref($href)) {
				my %flip = _flip_hash($href);
				push(@assoc_file_types, [$_, $flip{$_}]) foreach (keys %flip);
			}
			\@assoc_file_types
		}
		when ('Environment') {
			my $href = $data{'environ'};
			if (_is_hash_ref($href)) {
				%environ_settings = %{$href};
			} else {
				_setenv $_, $environ_settings{$_} foreach keys %environ_settings;
			}
			\%environ_settings
		}
		default {
			{}
		}
	}
}
sub to_string {
	my $class = shift;
	my $name = shift;
	my $sep = _value_or_else ' ', shift;
	given ($name) {
		when ('Environment') {
			my @strings = map { sprintf("%s=%s", $_, $environ_settings{$_}) } keys( %environ_settings );
			join $sep, @strings
		}
		default {
			''
		}
	}
}
sub strings {
	my $class = shift;
	given (shift) {
		when ('run') { return ["Run","Run in terminal","Run and capture output"] }
		when ('mod') { return ['Add/Update','Remove','Close'] }
	}
	[]
}
given (_getenv_once('_test', 0)) {
	when (_gt 1) {
		(new Settings(
			title => 'Settings',
			file => $_entries, 
			params => ['Associations','Environment']))->relaunch;
	}
	when (_gt 0) {
		tie my %data, "PersistHash", $_entries;
		_text_info undef, "file types", pp(Settings->apply('Associations', %data));
		_text_info undef, "Environment", pp(Settings->apply('Environment', %data));
	}
	default {
		1
	}
}
