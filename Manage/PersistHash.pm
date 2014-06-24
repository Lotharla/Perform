package PersistHash;
use strict;
use warnings;
use Tie::Hash;
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path $0);
use Manage::Utils qw(
	dump pp
	_blessed
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
		open my $in, '<:encoding(UTF-8)', $file or die "Can't open file \"$file\" : $!\n";
		{
			local $/;    # slurp mode
			$self = eval <$in>;
		}
		close $in;
	}
	return $self;
}
sub store {
	my $self = shift;
	my $file = shift;
	if ($file && -f $file) {
		open my $out, '>:encoding(UTF-8)', $file or die "Can't open file \"$file\" : $!\n";
		my $blessed = _blessed($self);
		print {$out} dump($blessed ? { %$self } : $self);
		close $out;
	}
}
sub DESTROY {
	my $self = shift;
	my $file = $self->{__file__};
	delete $self->{__file__};
	store($self, $file);
}
1;
