package Manage::SuggestEntry;
use strict;
use warnings;
use feature qw(say switch);
use Tk;
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_value_or_else
	_widget_info
	$_history
	_connect
	_make_sure_table
);
use base qw(Tk::BrowseEntry);
Construct Tk::Widget 'SuggestEntry';
sub ClassInit {
	my $package = shift;
	$package->SUPER::ClassInit(@_)
}
sub init_texts {
    my $dbfile = shift;
	_make_sure_table($dbfile, 'texts', 
		signature => "TEXT",
		date => "INTEGER",
		text => "TEXT",
	);
}
sub Populate {
    my $widget = shift;
	$widget->ConfigSpecs(-history_db => ['PASSIVE']);
	$widget->configure('-history_db', _value_or_else($_history, '-history_db', $_[0]));
	$widget->SUPER::Populate(@_);
	$widget->{signature} = _widget_info $widget, 'signature';
    my $dbfile = $widget->cget('-history_db');
	init_texts $dbfile;
	$widget->Subwidget("entry")->Subwidget("entry")->bind('<Any-KeyPress>', sub {
		$widget->delete(0,'end');
		my $dbh = _connect $dbfile;
		my $sql = "SELECT text FROM texts WHERE signature=? ORDER BY date DESC";
		my $result = $dbh->selectall_arrayref($sql, { Slice => {} }, $widget->{signature});
		foreach (@$result) {
			$widget->insert('end', $_->{text});
		}
		$dbh->disconnect;
		$widget->PopupChoices;
	});
}