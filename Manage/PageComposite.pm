package PageComposite;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::NoteBook;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	tmpdir
	catfile
	catdir
	_min _max
	_gt _lt
	_chomp
	_combine
	_value_or_else 
	_getenv_once
	_file_exists
	_fileparse
	_files_in_dir
	_contents_of_file
	_contents_to_file
	_center_window
	_ask_file
	_question
	_rndstr
	_create_popup_menu
	_delete_popup_menu
);
use Manage::Resolver qw(
	clipdir
	next_clip
	get_clip
);
use Manage::Composite;
our @ISA = qw(Composite);
sub new {
	my $class = shift;
    return $class->SUPER::new(@_);
}
sub initialize {
    my( $self ) = @_;
    $self->SUPER::initialize();
    if ($self->{title} eq 'Clipper') {
		my @files = _files_in_dir(clipdir, 1);
		@files = sort @files;
		push @files, '';
		$self->{params} = \@files;
    }
	$self->{book} = $self->{window}->NoteBook();
	$self->{book}->pack(-fill=>'both', -expand=>1);
	$self->populate($self->mode);
	_center_window($self->{window});
}
sub populate {
	my $self = shift;
    my $mode = shift;
    $self->{names} = {};
	my @params = @{$self->{params}};
    if (@params) {
		foreach (@params) {
			$self->page($_)
		}
	} else {
		$self->page()
	}
}
sub page {
	my $self = shift;
	my $file = shift;
	$file = _file_exists($file) ? $file : next_clip;
	my @parts = _fileparse($file);
	my $label = $parts[0].$parts[2];
	my $name = _rndstr;
	$self->{names}->{$name} = $file;
	my $page = $self->{book}->add($name, 
		-label => $label, 
		-raisecmd => sub{} 
	);
	my $widget = $page->Scrolled("Text", 
		-background => '#ffffff', 
		-scrollbars => 'osoe'
	);
	$widget->pack(-fill => 'both', -expand => 1);
	my $text_widget = $widget->Subwidget('scrolled');
	my $menu = $text_widget->menu;
	$menu->separator;
	my @labels = ('Save page','Remove page','Open page','New page');
	$menu->add('command', 
		-label => $labels[0], 
		-command => [sub {
			my ($label,$name) = @_;
			my $file = _ask_file($self->{window}, $label, $self->{names}->{$name}, [], 1);
			if ($file) {
				_contents_to_file $file, $text_widget->Contents;
				$self->{names}->{$name} = $file;
				my @parts = _fileparse($file);
				$self->{book}->pageconfigure($name, -label => $parts[0].$parts[2]);
			}
		}, $labels[0], $name]
	);
	$menu->add('command', 
		-label => $labels[1], 
		-command => [sub { 
			my ($label,$name) = @_;
			$self->{book}->delete($name);
			my $file = $self->{names}->{$name};
			if (-f $file) {;
				my $msg = sprintf "Also delete clip\n'%s'", $file;
				unlink $file if _question($self->{window}, $msg, $_[0]) eq 'yes'
			}
			delete $self->{names}->{$name};
			if (!$self->{book}->pages) {
				$self->{popup} = _create_popup_menu $self->{window};
				$self->{popup}->add('command', 
					-label => $labels[2], 
					-command => sub { 
						_delete_popup_menu $self->{window}, $self->{popup};
						$self->page();
					}
				);
			}
		}, $labels[1], $name]
	);
	$menu->add('command', 
		-label => $labels[2], 
		-command => [sub { 
			my ($label) = @_;
			my $file = _ask_file($self->{window}, $label, '', [], 0);
			if ($file) {
				$self->page($file) 
			}
		}, $labels[2]]
	);
	$menu->add('command', 
		-label => $labels[3], 
		-command => sub { 
			$self->page() 
		}
	);
	my $text = get_clip $self->{window}, $file;
	$widget->insert('end', $text);
	$self->{book}->raise($name);
}
1;
