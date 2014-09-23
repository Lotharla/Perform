package Manage::SuggestBox;
use strict;
use warnings;
use feature qw(say switch);
use Tk;
use base qw(Tk::BrowseEntry);
use File::Basename qw(dirname);
use Cwd qw(abs_path cwd);
use lib dirname(dirname abs_path __FILE__);
use Manage::Utils qw(
	dump pp
	_widget_info
	$_history
);
use Exporter::Easy (
	OK => [ qw(
	)],
);
Construct Tk::Widget 'SuggestBox';
sub ClassInit {
	my $package = shift;
	$package->SUPER::ClassInit(@_)
}
sub Populate {
    my ($widget) = shift;
	$widget->SUPER::Populate(@_);
	my $signature = _widget_info $widget, 'signature';
	$widget->Subwidget("entry")->Subwidget("entry")->bind('<Any-KeyPress>', sub {
		tie my %data, "PersistHash", $_history, 1;
		$widget->PopupChoices;
	});
}