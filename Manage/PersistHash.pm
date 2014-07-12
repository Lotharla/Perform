package PersistHash;
use strict;
use warnings;
use Tie::Hash;
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	_blessed
	_persist
);
our @ISA = qw(Tie::StdHash);
sub TIEHASH {
	my $class = shift;
	my $file = shift;
	my $self = fetch({}, $file);
	$self->{__file__} = $file;
	return bless $self, $class;
}
sub fetch {
	my $self = shift;
	my $file = shift;
	if ($file && -f $file) {
		$self = _persist $file;
	}
	return $self;
}
sub store {
	my $self = shift;
	my $file = shift;
	if ($file && -f $file) {
		my $blessed = _blessed($self);
		_persist $file, $blessed ? { %$self } : $self;
	}
}
sub DESTROY {
	my $self = shift;
	my $file = $self->{__file__};
	delete $self->{__file__};
	store($self, $file);
}
1;
