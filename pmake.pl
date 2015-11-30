#!/usr/bin/perl
# $Id: cat.perl,v 1.1 2014-10-13 14:16:07-07 - - $

#
# NAME
#    cat.perl - cat files to the terminal
#
# SYNOPSIS
#    cat.perl [-nm] [filename...]
#
# DESCRIPTION
#    Cat files to the terminal.  If no files are given, cat STDIN.
#
# OPTIONS
#    -n  Number each line for output.
#    -m  Print titles in the style of more(1).
#

use strict;
use warnings;
use Getopt::Std;

$0 =~ s|.*/||;
my $status = 0;
END { exit $status; }
$SIG{__WARN__} = sub {print STDERR "$0: @_"; $status = 1};
$SIG{__DIE__} = sub {warn @_; $status = 1; exit};

my %opts;
getopts "nm", \%opts;

push @ARGV, "-" unless @ARGV;

for my $filename (@ARGV) {
   open my $file, "<$filename" or warn "$filename: $!\n" and next;
   print ":"x32, "\n", "$filename\n", ":"x32, "\n" if $opts{'m'};
   while (defined (my $line = <$file>)) {
      chomp $line;
      printf "%6d  ", $. if $opts{'n'};
      printf "%s\n", $line;
   }
   close $file;
}
