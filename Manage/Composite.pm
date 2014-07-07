package Composite;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_value_or_else
	_getenv
	_now
	_file_exists
	_tkinit
);
use Manage::PersistHash;
sub new {
	my $class = shift;
	my $self = {@_};
	bless($self, $class);
	$self->initialize;
	return $self;
}
sub initialize {
	my $self = shift;
	my $title = _value_or_else('', $self->{title});
	$self->{window} = _value_or_else(sub{_tkinit(0, $title)}, $self->{window});
	$self->{width} = _value_or_else(50, $self->{width});
	$self->{height} = _value_or_else(10, $self->{height});
	$self->{window}->bind('<KeyPress-Escape>', sub {$self->cancel});
	$self->{window}->bind('<KeyPress-Return>', sub {$self->commit});
}
sub file { $_[0]->{file}=$_[1] if defined $_[1]; $_[0]->{file} }
sub mode {
	my $self = shift;
	my $mode = shift;
	$mode = (defined $mode ? $mode : -1) <=> 0;
	my $file = $self->file;
	$mode *= exists $self->{params} ? 
		1 : 
		(_file_exists($file) ? 2 : 0);
	return (abs($mode), $mode <=> 0)
}
sub data {
	my $self = shift;
	tie my %data, "PersistHash", $self->file;
	return sub {
		%data = @_ if defined $_[0];
		%data
	};
}
sub commit {
	my $self = shift;
	$self->cancel
}
sub finalize {
	my $self = shift;
}
sub cancel {
	my $self = shift;
	$self->finalize;
	$self->{window}->destroy();
	$self->{window} = undef;
}
sub relaunch {
	my $self = shift;
	MainLoop();
	if ($self->{relaunch}) {
		$self->{relaunch} = 0;
		my $class = ref $self;
		relaunch($class->new(%$self)); 
	}
}
1;
