package ViewComposite;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::NoteBook;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use lib dirname(dirname abs_path $0);
use Manage::Utils qw(
	dump pp
	_chomp
	_combine
	_value_or_else 
	_getenv
	_fileparse
	_files_in_dir
	_contents_of_file
	_contents_to_file
	_center_window
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
    if ($mode == 1 && $self->{params}) {
		my @params = @{$self->{params}};
		foreach my $file (@params) {
			my(@parts) = _fileparse($file);
			my $tab = $self->{book}->add( $file, -label=>$parts[0].$parts[2], -raisecmd=>sub{} );
			my $widget = $tab->Scrolled("Text", -background => '#fffafa', -scrollbars => 'osoe');
			my $text_widget = $widget->Subwidget('scrolled');
			my $menu = $text_widget->menu;
			$menu->separator;
			$menu->add('command', 
				-label => 'Save', 
				-command => sub { 
					_contents_to_file $file, $text_widget->Contents; 
				}
			);
			$widget->pack(-fill => 'both', -expand => 1);
			my $text = _contents_of_file $file;
			$widget->insert('end', $text);
		}
	}
}
given (_value_or_else(0, _getenv('test'))) {
	when ($_ > 0) {
		my $dir = "/tmp/diag";
		my @files = _files_in_dir($dir, 1);
		new ViewComposite('title', $dir, 'params', \@files);
		MainLoop();
	}
	default {
		1
	}
}
