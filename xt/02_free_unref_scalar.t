# -*- perl -*-

use strict;
use warnings;

use Devel::Peek qw{Dump};
use Test::More;

BEGIN { use_ok 'DBI'; }

require "t/lib.pl";

$SIG{__WARN__} = sub {
    if ($_[0] =~ /^Attempt to free unreferenced scalar: SV (0x[0-9a-f]+)(, \<\w+\> line \d+)? during global destruction\.$/) {
	fail('there was an attempt to free unreferenced scalar');
    }
    diag "@_";
};

sub DBD::CSV::Table::DESTROY {
    my $self = shift;
    my $csv = $self->{csv_csv_in};
    my $dbg = $self->{csv_csv_in}{auto_diag};

    if ($dbg) {
	Dump $csv, 1;
    } else {
	#diag sprintf '0x%x', refaddr $csv;
    }

#    $self->{csv_csv_out} = $self->{meta}{csv_out} = undef;
#    $self->{csv_csv_in} = $self->{meta}{csv_in} = undef;
}

sub test_with_options {
    my (%opts) = @_;
    my $csv_tables = delete( $opts{csv_tables} ) || {};
    my $dbh = DBI->connect ("dbi:CSV:", undef, undef, {
	f_schema         => undef,
	f_dir            => 't',
	f_dir_search     => [],
	f_ext            => ".csv/r",
	f_lock           => 2,
	f_encoding       => "utf8",

	%opts,

	RaiseError       => 1,
	PrintError       => 1,
	FetchHashKeyName => "NAME_lc",
			    }) or die "$DBI::errstr\n";


    $dbh->{csv_tables} = $csv_tables;

    my %tbl = map { $_ => 1 } $dbh->tables (undef, undef, undef, undef);

    is ($tbl{$_}, 1, "Table $_ found") for qw( tmp );

    my %data = (
	tmp => {		# t/tmp.csv
	    1 => "ape",
	    (grep(/^csv_callbacks$/, keys %opts) ? 
	     (2 => "new world monkey") : (2 => 'monkey')),
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
}

sub new_world_monkeys {
    my ($csv, $data) = @_;

    $data->[1] =~ s/^monkey$/new world monkey/;

    return;
}

my $callbacks = {
    csv_callbacks => {
	after_parse => \&new_world_monkeys,
    },
};

test_with_options(
    csv_tables => { tmp => { f_file => 'tmp.csv'} },
    %$callbacks,
);

test_with_options(
    csv_auto_diag => 0,
    %$callbacks,
    ) for (1 .. 100);

done_testing();
