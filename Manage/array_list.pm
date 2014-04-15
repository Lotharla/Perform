package array_list;
use strict;
use warnings;
use Tk;
sub new {
	my $class = shift;
	my $self = {@_};
	bless($self, $class);
	$self-> _init;
	return $self;
}
sub _init {
	my $self = shift;
	$self->{listbox} = $self->{window}->Listbox(
	   -height     =>  0,
	   -width      =>  0,
	   -selectmode => 'multiple'
	)->pack;
	if (exists $self->{array}) {
		my @array = @{$self->{array}};
		$self->items(@array);
	}
}
sub items {
	my $self = shift;
	tie my @items,'Tk::Listbox', $self->{listbox};
	sub {
		@items = @_ if defined $_[0];
		@items
	}
}
my $la = new array_list('window', MainWindow->new(), 'array', []);
my $items = $la->items();
$items->(split( /:/, $ENV{PATH}));
MainLoop();