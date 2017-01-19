# -*- perl -*-

use strict;
use warnings;

use Test::More;

BEGIN { use_ok 'DBI'; }

require "t/lib.pl";

$SIG{__WARN__} = sub {
    if ($_[0] =~ /^Attempt to free unreferenced scalar: SV 0x[0-9a-f]+ during global destruction\.$/) {
	fail('there was an attempt to free unreferenced scalar');
    }
    diag "@_";
};

my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
    f_schema         => undef,
    f_dir            => 't',
    f_dir_search     => [],
    f_ext            => ".csv/r",
    f_lock           => 2,
    f_encoding       => "utf8",

    csv_tables => { tmp => { f_file => 'tmp.csv'} },

    csv_callbacks => {
	after_parse => \&new_world_monkeys,
    },


    RaiseError       => 1,
    PrintError       => 1,
    FetchHashKeyName => "NAME_lc",
    }) 
    or die "$DBI::errstr\n";

my %tbl = map { $_ => 1 } $dbh->tables (undef, undef, undef, undef);

is ($tbl{$_}, 1, "Table $_ found") for qw( tmp );

my %data = (
    tmp => {		# t/tmp.csv
	1 => "ape",
	2 => 'monkey',
	2 => "new world monkey",
	3 => "gorilla",
	},
    );

foreach my $tbl(sort keys %data) {
    my $sth = $dbh->prepare ("select * from $tbl");
    $sth->execute;
    while (my $row = $sth->fetch) {
	is ($row->[1], $data{$tbl}{$row->[0]}, "$tbl ($row->[0], ...)");
    }
    $sth->finish();
}

$dbh->disconnect;

sub new_world_monkeys {
    my ($csv, $data) = @_;

    $data->[1] =~ s/^monkey$/new world monkey/;

    return;
}

done_testing();
