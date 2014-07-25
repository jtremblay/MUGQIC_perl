#!/usr/bin/env perl

=head1 NAME

I<Exonerate>

=head1 SYNOPSIS

library for Exonerate

=head1 DESCRIPTION


=head1 AUTHOR

Julien Tremblay - julien.tremblay@mail.mcgill.ca

=head1 DEPENDENCY

B<Pod::Usage> Usage and help output.

B<Data::Dumper> Used to debbug.

=cut

package Exonerate;

# Strict Pragmas
#--------------------------
use strict;
use warnings;

#--------------------------

# Add the mugqic_pipeline/lib/ path relative to this Perl script to @INC library search variable
use FindBin;
use lib "$FindBin::Bin";

# Dependencies
#-----------------------
use Data::Dumper;
use Config::Simple;
use LoadConfig;
use File::Basename;
#-------------------
# SUB
#-------------------
our $rH_cfg;
our $sampleName;
our $rH_laneInfo;
our $fileFasta;


sub fastasplit{
  my $rH_cfg      = shift;
  my $infile      = shift;
  my $prefix      = shift;
  my $outdir      = shift;
  my $n           = shift;

  #$prefix =~ s{\.[^.]+$}{};

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$infile], [$outdir."/flag"]);
    
  if (!$ro_job->isUp2Date()) {
    my $cmd = '';
    $cmd .= LoadConfig::moduleLoad($rH_cfg, [
      ['R', 'moduleVersion.exonerate']
    ]) . ' && ';
    $cmd .= ' fastasplit';
    $cmd .= ' -f ' . $infile;
    $cmd .= ' -c ' . $n;
    $cmd .= ' -o ' . $outdir;
    $cmd .= ' && touch ' . $outdir.'/flag.mugqic.done && touch ' . $outdir . '/flag';

    $ro_job->addCommand($cmd);
  }
  return $ro_job;
}

sub fastasplit2{
  my $rH_cfg      = shift;
  my $infile      = shift;
  my $prefix      = shift;
  my $outdir      = shift;
  my $n           = shift;

  #$prefix =~ s{\.[^.]+$}{};

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$infile], [$outdir."/flag"]);
    
  if (!$ro_job->isUp2Date()) {
    my $cmd = '';
    $cmd .= LoadConfig::moduleLoad($rH_cfg, [
      ['R', 'moduleVersion.mugqictools']
    ]) . ' && ';
    $cmd .= ' splitFastaFile.pl';
    $cmd .= ' --infile ' . $infile;
    $cmd .= ' --n ' . $n;
    $cmd .= ' --outdir ' . $outdir;
    $cmd .= ' && touch ' . $outdir.'/flag.mugqic.done && touch ' . $outdir . '/flag';

    $ro_job->addCommand($cmd);
  }
  return $ro_job;
}

sub cat{
  my $rH_cfg      = shift;
  my $string      = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([""], [""]);
  my $cmd = ""; 
  if (!$ro_job->isUp2Date()) {
    $cmd .= $string;

    $ro_job->addCommand($cmd);
  }
  return $ro_job;
}


1;
