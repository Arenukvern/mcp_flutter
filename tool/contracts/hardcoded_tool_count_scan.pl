#!/usr/bin/env perl
# Scan one file (path in $ARGV) for hard-coded tool totals adjacent to tool(s).
# Skip lines containing tool-count-allow (intentional prose).
use strict;
use warnings;

my $file = $ARGV[0];
open my $fh, '<', $file or die "open $file: $!\n";
my $line_no = 0;
while (my $raw = <$fh>) {
  $line_no++;
  next if $raw =~ /tool-count-allow/i;
  next if $raw =~ /^\s*\d+\.\s/;    # ordered-list lead-in, not a tool total
  my $line = $raw;
  $line =~ s/<[^>]+>//g;
  $line =~ s/&nbsp;/ /gi;
  next unless $line =~ /(?<![\w-])\btools\b/i || $line =~ /\d+\s*[-–]\s*tool\b/i;
  my $hit = 0;
  $hit = 1 if $line =~ /
    (?:
      \b\d{1,3}\+?\b
      | \b(?:twenty|thirty|forty|twenty[\s-]?(?:nine|eight|seven|six|five|four|three|two|one)|thirty[\s-]?(?:nine|eight|seven|six|five|four|three|two|one)|forty)\b
    )
    [\s\S]{0,56}
    \btools\b
  /xi;
  $hit = 1 if !$hit && $line =~ /\btools\b[\s\S]{0,32}\b\d{1,3}\+?\b/i;
  $hit = 1 if !$hit && $line =~ /\btools\s*:\s*\d{1,3}\b/i;
  $hit = 1 if !$hit && $line =~ /\b\d{1,3}\+?\s*[-–]\s*tool\b/i;
  $hit = 1 if !$hit && $line =~ /\bover\s+\d{1,3}\s+(?:\w+\s+){0,4}tools\b/i;
  if ($hit) {
    print "$file:$line_no:$raw";
  }
}
close $fh;