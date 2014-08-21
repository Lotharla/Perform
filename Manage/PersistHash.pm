package PersistHash;
use strict;
use warnings;
use feature 'say';
use Tie::Hash;
use Array::Utils qw(:all);
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	_is_blessed
	_index_of
	_persist
	_is_sqlite_file
	_make_sure_file
);
use Manage::SQLite;
our @ISA = qw(Tie::StdHash);
sub connect {
	my $class = shift;
	my $file = shift;
	SQLite->connect("dbi:SQLite:dbname=$file", '', '',
	    {
	        RaiseError  => 1,
	        PrintError  => 0,
	    }
	);
}
sub make_sure_db {
	my $class = shift;
	my $file = shift;
	my $dbh = &connect($class, $file);
	$dbh->do('CREATE TABLE IF NOT EXISTS hash (key TEXT, value TEXT)');
	$dbh->disconnect;
}
sub remove_key {
	my $class = shift;
	my $file = shift;
	my $key = shift;
	if (_is_sqlite_file $file) {
		my $dbh = &connect('PersistHash', $file);
		my $del = $dbh->prepare('DELETE FROM hash WHERE key == ?');
		$del->execute($key) or die $dbh->errstr;
		$dbh->disconnect;
	}
}
sub TIEHASH {
	my $class = shift;
	my $file = shift;
	if (shift) {
		make_sure_db($class, $file);
	} else {
		_make_sure_file $file;
	}
	my $self = fetch({}, $file);
	$self->{__file__} = $file;
	return bless $self, $class;
}
sub fetch {
	my $self = shift;
	my $file = shift;
	if ($file && -f $file) {
		if (_is_sqlite_file $file) {
			my $dbh = &connect('PersistHash', $file);
			my $sql = 'SELECT key,value FROM hash';
			my @result = @{ $dbh->selectall_arrayref($sql) };
			$self->{hash} = {};
			$self->{hash}->{$_->[0]} = $_->[1] foreach @result;
			$dbh->disconnect;
		} else {
			$self = _persist $file;
		}
	}
	return $self;
}
sub store {
	my $self = shift;
	my $file = shift;
	if ($file && -f $file) {
		if (_is_sqlite_file $file) {
			my %hash = %{$self->{hash}};
			my @keys = keys %hash;
			my $stored = fetch({}, $file);
			my %stored = %{$stored->{hash}};
			my @stored = keys %stored;
			my $dbh = &connect('PersistHash', $file);
			my $insert = $dbh->prepare('INSERT INTO hash (key,value) VALUES (?,?)');
			my $delete = $dbh->prepare('DELETE FROM hash WHERE key == ?');
			for my $key (array_diff(@stored, @keys)) {
				if (_index_of($key, @keys) > -1) {
					my $value = $hash{$key};
					$insert->execute($key, $value) or die $dbh->errstr;
				} else {
					$delete->execute($key) or die $dbh->errstr;
				}
			}
			my $update = $dbh->prepare('UPDATE hash SET value = ? WHERE key == ?');
			for my $key (intersect(@stored, @keys)) {
				my $value = $hash{$key};
				if ($stored{$key} ne $value) {
					$update->execute($value, $key) or die $dbh->errstr;
				}
			}
			$dbh->disconnect;
		} else {
			my $blessed = _is_blessed($self);
			_persist $file, $blessed ? { %$self } : $self;
		}
	}
}
sub DESTROY {
	my $self = shift;
	my $file = $self->{__file__};
	delete $self->{__file__};
	store($self, $file);
}
1;
