package PersistHash;
use strict;
use warnings;
use Data::Dump qw(dump pp);
use Tie::Hash;
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
	}
	return $self;
}
sub store {
	my $self = shift;
	my $file = shift;
	if ($file && -f $file) {
		open my $out, '>:encoding(UTF-8)', $file or die "Can't open file \"$file\" : $!\n";
		print {$out} dump $self;
		close $out;
	}
}
sub DESTROY {
	my $self = shift;
	my $file = $self->{__file__};
	delete $self->{__file__};
	use Data::Structure::Util qw( unbless );
	unbless $self;
	store($self, $file);
}
1;