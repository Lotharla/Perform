package ViewComposite;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::NoteBook;
use Clipboard;
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
	_getenv
	_file_exists
	_fileparse
	_files_in_dir
	_clipdir
	_contents_of_file
	_contents_to_file
	_center_window
	_ask_file
	_question
);
use Manage::Composite;
our @ISA = qw(Composite);
sub new {
	my $class = shift;
    my $self = $class->SUPER::new(@_);
	return bless($self, $class);
}
sub initialize {
    my( $self ) = @_;
    $self->SUPER::initialize();
	$self->{book} = $self->{window}->NoteBook()->pack( -fill=>'both', -expand=>1 );
	$self->populate($self->mode);
	_center_window($self->{window});
}
sub populate {
	my $self = shift;
    my $mode = shift;
	my @params = @{$self->{params}};
    if (@params) {
		foreach (@params) {
			$self->page($_)
		}
	} else {
		$self->page()
	}
}
sub next_clip {
	my $self = shift;
	my $d = 1;
	foreach ($self->{book}->pages) {
		my $label = $self->{book}->pagecget($_, -label);
		if ($label =~ /^_(\d+)$/) {
			$d = _max $d, $1 + 1;
		}
	}
	"_$d"
}
sub cliptext {
	my $self = shift;
	my $str = $self->{window}->clipboardGet;
	$str
}
sub page {
	my $self = shift;
	my $file = shift;
	my ($name,$label);
	if (_file_exists($file)) {
		my(@parts) = _fileparse($file);
		$label = $parts[0].$parts[2];
		$name = $file;
	} else {
		$label = $self->next_clip;
		$name = catfile _clipdir, $label;
		$file = $name;
	};
	my $page = $self->{book}->add($name, 
		-label => $label, 
		-raisecmd => sub{} 
	);
	my $widget = $page->Scrolled("Text", 
		-background => '#ffffff', 
		-scrollbars => 'osoe'
	);
	my $text_widget = $widget->Subwidget('scrolled');
	my $menu = $text_widget->menu;
	$menu->separator;
	$label = 'Save page';
	$menu->add('command', 
		-label => $label, 
		-command => sub { 
			$file = _ask_file($self->{window}, $label, $file, [], 1);
			_contents_to_file $file, $text_widget->Contents if $file; 
		}
	);
	$label = 'Remove page';
	$menu->add('command', 
		-label => $label, 
		-command => sub { 
			my $msg = $self->{book}->pagecget($name, -label);
			$msg = sprintf "Are you sure about removing\n'%s'", $msg;
			$self->{book}->delete($name) if _question($self->{window}, $msg, $label) eq 'yes'
		}
	);
	$menu->add('command', 
		-label => 'New page', 
		-command => sub { 
			$self->page() 
		}
	);
	$widget->pack(-fill => 'both', -expand => 1);
	my $text = _file_exists($file) ? 
		_contents_of_file $file : 
		$self->cliptext;
	$widget->insert('end', $text);
	$self->{book}->raise($name);
}
given (_value_or_else(0, _getenv('testing'))) {
	when (_gt 0) {
		my $dir = _clipdir;
		my @files = _files_in_dir($dir, 1);
		(new ViewComposite('title', $dir, 'params', \@files))->relaunch;
	}
	default {
		1
	}
}
