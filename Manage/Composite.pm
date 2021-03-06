package Composite;
use strict;
use warnings;
no warnings 'experimental';
use feature qw(say switch);
use Tk;
use Tk::DialogBox;
use Tk::NumEntry;
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	looks_like_number
	_value_or_else
	_getenv
	_now
	_call
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
	$self->{window}->bind('<KeyPress-Escape>', sub {$self->cancel});
}
sub file { $_[0]->{file}=$_[1] if defined $_[1]; $_[0]->{file} }
sub data {
	my $self = shift;
	tie my %data, "PersistHash", $self->file;
	_call [shift, \%data];
	return sub {
		return $data{$_[0]} if defined $_[0];
		%data
	};
}
sub use_file {
	$_[0]->{file} && length($_[0]->{file}) > 0
}
sub mode {
	my $self = shift;
	my $mode = 0;
	if ($self->use_file) {
		$self->{data} = $self->data();
		$mode = 2
	} elsif (exists $self->{params}) {
		$mode = 1;
	}
	$mode
}
sub modifier { 
	return $_[0]->{modifier} unless @_ > 1;
	my @modifiers = ('','Alt','Control');
	return $modifiers[$_[2]] if defined $_[2];
	my $mod = $_[1];
	$_[0]->{modifier} = looks_like_number($mod) 
		? $modifiers[$mod]
		: $mod
}
sub dimension {
	my ($self,$name,$width,$height) = @_;
	if ($self->{data}) {
		my %data = $self->{data}->();
		my $key = join "-",$name,'width';
		if ($width) {
			$data{options}->{$key} = $width;
		} else {
			$width = $data{options}->{$key};
		}
		$key = join "-",$name,'height';
		if ($height) {
			$data{options}->{$key} = $height;
		} else {
			$height = $data{options}->{$key};
		}
	}
	(_value_or_else(50, $width),_value_or_else(10, $height))
}
sub ask_dimension {
	my $self = shift;
	my $name = shift;
	my ($width,$height) = $self->dimension($name);
	my $dlg = $self->{window}->DialogBox(
		-title => "$name dimension",
		-buttons => ['OK', 'Cancel'],
		-default_button => 'Cancel');
	$dlg->Label( -text => 'Width' )->grid(-row => 0, -column => 0);
	$dlg->NumEntry(-textvariable => \$width,
		-minvalue => 10,
		-maxvalue => $self->{window}->screenwidth
	)->grid(-row => 0, -column => 1);
	$dlg->Label( -text => 'Height' )->grid(-row => 1, -column => 0);
	$dlg->NumEntry(-textvariable => \$height,
		-minvalue => 2,
		-maxvalue => $self->{window}->screenheight
	)->grid(-row => 1, -column => 1);
	given ($dlg->Show) {
		when ('OK') {
			$self->dimension($name, $width, $height);
			1
		}
		default {
			0
		}
	}
}
sub save {
	my $self = shift;
	if ($self->{data}) {
		my %data = $self->{data}->();
		PersistHash::DESTROY \%data;     
	}
}
sub finalize {
	my $self = shift;
	$self->save
}
sub commit {
	my $self = shift;
	$self->cancel
}
sub cancel {
	my $self = shift;
	$self->{relaunch} = shift;
	$self->finalize;
	if ($self->{window}) {
		$self->{window}->destroy();
		$self->{window} = undef;
	}
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
