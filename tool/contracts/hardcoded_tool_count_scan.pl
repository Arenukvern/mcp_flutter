#!/usr/bin/env perl
# Scan one file (path in $ARGV) for hard-coded tool totals adjacent to tool(s).
# Skip lines containing tool-count-allow (intentional prose).
use strict;
use warnings;

my $file = $ARGV[0];
open my $fh, '<', $file or die "open $file: $!\n";

sub normalize_line {
  my ($raw) = @_;
  return '' if $raw =~ /tool-count-allow/i;
  my $line = $raw;
  $line =~ s/^\s*\d+\.\s+//;
  $line =~ s/<[^>]+>//g;
  $line =~ s/&nbsp;/ /gi;
  return $line;
}

sub strip_benign_fragments {
  my ($blob) = @_;
  $blob =~ s/\b\d{1,3}\s*-(?:second|minute|hour|day|week|month|year)\b//gi;
  $blob =~ s/\bin\s+a\s+\d{1,3}\s*-(?:second|minute|hour|day)\s+setup\b//gi;
  unless ($blob =~ /\b\d{1,3}\s+tools\/call\b/i) {
    $blob =~ s/\btools\/call\b//gi;
  }
  $blob =~ s/\band\s+\d{1,3}\s+skills\b//gi;
  $blob =~ s/(?<=\s)\d{1,3}\s+skills\b(?!\s+and)//gi;
  $blob =~ s/\bfor\s+[\w-]*-tools\s+users\b//gi;
  $blob =~ s/`[^`]*custom-tools[^`]*`//gi;
  $blob =~ s/\/custom-tools\b//gi;
  $blob =~ s/custom-tools\.mdx//gi;
  $blob =~ s/"tools"\s*:\s*\[\s*\]//gi;
  return $blob;
}

sub scan_text {
  my ($blob, $line_no, $raw_for_print) = @_;
  $blob = strip_benign_fragments($blob);
  return if $blob =~ /^\s*$/;
  return unless $blob =~ /(?<![\w-])\btools\b/i
    || $blob =~ /\b\d{1,3}\s+custom-tools\b/i
    || $blob =~ /\btoolset\b/i
    || $blob =~ /\d+\s*[-–]\s*tool\b/i
    || $blob =~ /\bfmt_/i
    || $blob =~ /tool\s+count\s*:/i
    || $blob =~ /tool(?:s)?\s+surface/i;
  my $hit = 0;
  $hit = 1 if $blob =~ /
    (?:
      \b\d{1,3}\+?\b
      | \b(?:twenty|thirty|forty|twenty[\s-]?(?:nine|eight|seven|six|five|four|three|two|one)|thirty[\s-]?(?:nine|eight|seven|six|five|four|three|two|one)|forty|thirty[\s-]?four|twenty[\s-]?nine)\b
    )
    [\s\S]{0,72}
    \btools\b
  /xi;
  $hit = 1 if !$hit && $blob =~ /\btools\b[\s\S]{0,40}\b\d{1,3}\+?\b/i;
  $hit = 1 if !$hit && $blob =~ /\btools\s*:\s*\d{1,3}\b/i;
  $hit = 1 if !$hit && $blob =~ /\b\d{1,3}\+?\s*[-–]\s*tool\b/i;
  $hit = 1 if !$hit && $blob =~ /\bover\s+\d{1,3}\s+(?:\w+\s+){0,6}tools\b/i;
  $hit = 1 if !$hit && $blob =~ /tool\s+count\s*:\s*\d{1,3}\b/i;
  $hit = 1 if !$hit && $blob =~ /\b\d{1,3}\s*[-–]\s*strong\s+tool\s+surface\b/i;
  $hit = 1 if !$hit && $blob =~ /\btoolset\s+of\s+(?:\d{1,3}|thirty[\s-]?four|twenty[\s-]?nine)\b/i;
  $hit = 1 if !$hit && $blob =~ /\b(?:the\s+)?\d{1,3}\s+fmt_[a-z][\w_]*/i;
  $hit = 1 if !$hit && $blob =~ /\b(?:the\s+)?\d{1,3}\s+fmt_\*/i;
  $hit = 1 if !$hit && $blob =~ /\b(?:thirty|twenty)[\s-]?(?:four|nine)\b[\s\S]{0,48}\btools\b/i;
  $hit = 1 if !$hit && $blob =~ /\bcore\s+\d{1,3}\s+plus\s+\d{1,3}\s+extra\s+tools\b/i;
  $hit = 1 if !$hit && $blob =~ /\b\d{1,3}\s+custom-tools\b/i;
  if ($hit) {
    print "$file:$line_no:$raw_for_print";
  }
}

my @paragraph;
my $para_start = 1;
my $line_no = 0;

while (my $raw = <$fh>) {
  $line_no++;
  if ($raw =~ /^\s*$/ || $raw =~ /^\s*\d+\.\s/) {
    if (@paragraph) {
      my $joined = join ' ', map { normalize_line($_) } @paragraph;
      scan_text($joined, $para_start, $paragraph[0]) if $joined ne '';
      @paragraph = ();
    }
    if ($raw =~ /^\s*\d+\.\s/) {
      my $one = normalize_line($raw);
      scan_text($one, $line_no, $raw) if $one ne '';
    }
    next if $raw =~ /^\s*$/;
    next;
  }
  my $one = normalize_line($raw);
  scan_text($one, $line_no, $raw) if $one ne '';
  $para_start = $line_no if !@paragraph;
  push @paragraph, $raw;
}

if (@paragraph) {
  my $joined = join ' ', map { normalize_line($_) } @paragraph;
  scan_text($joined, $para_start, $paragraph[0]) if $joined ne '';
}

close $fh;