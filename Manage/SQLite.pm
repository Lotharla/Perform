use strict;
use warnings;
use DBD::SQLite;
package SQLite;
use base 'DBI';

package SQLite::st;
use base 'DBI::st';

package SQLite::db;
use base 'DBI::db';

sub connected {
    my $dbh = shift;
    # Add regexp function.
    $dbh->func('regexp', 2, sub {
        my ($regex, $string) = @_;
        return $string =~ /$regex/;
    }, 'create_function');
}
1;