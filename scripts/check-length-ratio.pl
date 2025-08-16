#!/usr/bin/env perl

$file1 = shift(@ARGV);
$file2 = shift(@ARGV);


open F1,"gzip -dc $file1 |" or die "cannot read from $file1";
open F2,"gzip -dc $file2 |" or die "cannot read from $file2";

my $count = 0;
my $countSuspiciousInARow = 0;
    
while (<F1>){
    my $line2 = <F2>;
    chomp;
    chomp($line2);

    $l1 = length($_);
    $l2 = length($line2);
    $l12 = $l2 > 0 ? $l1/$l2 : 0;
    $l21 = $l1 > 0 ? $l2/$l1 : 0;
    
    $l = $l1 > $l2 ? $l2/$l1 : $l1/$l2;

    # @t1 = split(/\s+/);
    # @t2 = split(/\s+/,$line2);
    # $l = @t1 > @t2 ? @t2/@t1 : @t1/@t2;

    
    if ($l12<0.5 || $l21<0.5){
	$countSuspiciousInARow++;
	print "$count\t$countSuspiciousInARow\t$l12\t$l21\t$_\t$line2\n";
    }
    else{
	$countSuspiciousInARow=0;
    }
    $count++;
}

