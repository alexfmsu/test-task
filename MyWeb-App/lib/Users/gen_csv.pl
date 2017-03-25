use 5.16.0;
use strict;
use warnings;

use Text::CSV;

my $csv = Text::CSV->new({
    binary => 1,
    eol => "\r\n"
}) or die "Cannot create CSV object: " . Text::CSV->error_diag();

die("Usage: perl gen_csv.pl [filename] [count]\n
Example: perl gen_csv.pl data.csv 100000\n"
) unless scalar @ARGV > 1;  

my $filename = $ARGV[0];
my $count = $ARGV[1];

open(my $fh, ">:encoding(utf8)", $filename) or die "$filename: $!";

for(1..$count){
    my $name = join '', map{('a'..'z')[rand 26]} 1..12;
    $name = ucfirst($name);
    
    my $phone = join '', map{('0'..'9')[rand 10]} 1..11;
    
    $csv->print($fh, [$name, $phone]);
}

close $fh or die "$filename: $!";