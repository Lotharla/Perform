package Composite;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path $0);
use Manage::Utils qw(
	dump pp
	_value_or_else
	_indexOf
	_getenv
	_now
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
	$self->{window}->bind('<KeyPress-Escape>', sub {cancel($self)});
}
sub file { $_[0]->{file}=$_[1] if defined $_[1]; $_[0]->{file} }
sub mode {
	my $self = shift;
	my $file = $self->file;
	return exists $self->{params} ? 1 : 
		($file && -f $file ? 2 : 0);
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
}
1;
