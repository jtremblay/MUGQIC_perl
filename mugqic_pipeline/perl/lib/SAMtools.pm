#!/usr/bin/env perl

=head1 NAME

I<SAMtools>

=head1 SYNOPSIS

SAMtools->mpileup()

=head1 DESCRIPTION

B<SAMtools> is a library to manipulate and compute stats off of BAMs and to call variants

Input = file_name

Output = array

=head1 AUTHOR

=head1 DEPENDENCY

B<Pod::Usage> Usage and help output.

B<Data::Dumper> Used to debbug

=cut

package SAMtools;

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
use Job;
use LoadConfig;

# SUB
#-----------------------
sub mpileupPaired {
  my $rH_cfg      = shift;
  my $sampleName  = shift;
  my $normalBam   = shift;
  my $tumorBam    = shift;
  my $seqName     = shift;
  my $outputDir   = shift;

  my @bams = ($normalBam, $tumorBam);

  return mpileupBuilder($rH_cfg, $seqName, $outputDir, $sampleName, \@bams, 1);
}

sub mpileup {
  my $rH_cfg      = shift;
  my $sampleName  = shift;
  my $rA_bams     = shift;
  my $seqName     = shift;
  my $outputDir   = shift;

  return mpileupBuilder($rH_cfg, $seqName, $outputDir, $sampleName, $rA_bams);
}

sub mpileupBuilder {
  my $rH_cfg      = shift;
  my $seqName     = shift;
  my $outputDir   = shift;
  my $sampleName  = shift;
  my $rA_bams     = shift;
  my $isPaired    = shift;

  if (defined($isPaired) && $isPaired == 1 && @{$rA_bams} != 2) {
    die("Paired was asked but there aren't 2 bams given\n");
  }

  my $refGenome = LoadConfig::getParam($rH_cfg, 'default', 'referenceFasta', 1, 'filepath');
  my $outputBCF = $outputDir . $sampleName . '.bcf';

  my $regionCmd = ' ';
  if (defined($seqName)) {
    $regionCmd =' -r ' . $seqName;
    $outputBCF = $outputDir . $sampleName . '.' . $seqName . '.bcf';
  }

  my $ro_job = new Job();
  $ro_job->testInputOutputs($rA_bams, [$outputBCF]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['mpileup', 'moduleVersion.samtools']]) . ' &&';
    $command .= ' samtools mpileup';
    $command .= ' ' . LoadConfig::getParam($rH_cfg, 'mpileup', 'mpileupExtraFlags');
    $command .= ' -f ' . $refGenome;
    $command .= $regionCmd;
    for my $bamFiles (@{$rA_bams}) {
      $command .= ' ' . $bamFiles;
    }
    if (defined($isPaired) && $isPaired == 1) {
      $command .= ' | bcftools view -T pair -bvcg - > ' . $outputBCF;
    } else {
      $command .= ' | bcftools view -bvcg - > ' . $outputBCF;
    }

    $ro_job->addCommand($command);
  }

  return $ro_job;
}

sub mergeFilterBCF {
  my $rH_cfg      = shift;
  my $sampleName  = shift;
  my $bcfDir      = shift;
  my $outputDir   = shift;
  my $rA_seqNames = shift;

  my $refGenome = LoadConfig::getParam($rH_cfg, 'default', 'referenceFasta', 1, 'filepath');
  my $outputBCF = $outputDir . $sampleName . '.merged.bcf';
  my $outputVCF = $outputDir . $sampleName . '.merged.flt.vcf';

  my $bcfInputs = "";
  my @inputs;
  for my $seqName (@$rA_seqNames) {
    my $bcfFile = $bcfDir . $sampleName . '.' . $seqName . '.bcf';
    push(@inputs, $bcfFile);

    $bcfInputs .= $bcfFile . ' ';
  }

  my $ro_job = new Job();
  $ro_job->testInputOutputs(\@inputs, [$outputBCF, $outputVCF]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['mergeFilterBCF', 'moduleVersion.samtools']]) . ' &&';
    $command .= ' bcftools cat';
    $command .= ' ' . $bcfInputs;
    $command .= ' > ' . $outputBCF;
    $command .= ' && bcftools view ' . $outputBCF;
    $command .= ' > ' . $outputVCF;

    $ro_job->addCommand($command);
  }

  return $ro_job;
}

sub flagstat {
  my $rH_cfg     = shift;
  my $bamFile    = shift;
  my $output     = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$bamFile], [$output]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['flagstat', 'moduleVersion.samtools']]) . ' &&';
    $command .= ' samtools flagstat';
    $command .= ' ' . $bamFile;
    $command .= ' > ' . $output;

    $ro_job->addCommand($command);
  }

  return $ro_job;
}

sub idxstats {
  my $rH_cfg     = shift;
  my $bamFile    = shift;
  my $output     = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$bamFile], [$output]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['idxstats', 'moduleVersion.samtools']]) . ' &&';
    $command .= ' samtools idxstats';
    $command .= ' ' . $bamFile;
    $command .= ' > ' . $output;

    $ro_job->addCommand($command);
  }
  return $ro_job;
}

sub rawmpileup {
  my $rH_cfg      = shift;
  my $sampleName  = shift;
  my $bamFile     = shift;
  my $seqName     = shift;
  my $output      = shift;

  my $refGenome = LoadConfig::getParam($rH_cfg, 'default', 'referenceFasta', 1, 'filepath');

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$bamFile], [$output]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['rawmpileup', 'moduleVersion.samtools']]) . ' &&';
    $command .= ' samtools mpileup';
    $command .= ' ' . LoadConfig::getParam($rH_cfg, 'rawmpileup', 'mpileupExtraFlags');
    $command .= ' -f ' . $refGenome;
    $command .= ' -r ' . $seqName;
    $command .= ' ' . $bamFile;
    $command .= ' | gzip -1 -c > ' . $output;

    $ro_job->addCommand($command);
  }
  return $ro_job;
}

sub sort {
  my $rH_cfg      = shift;
  my $sampleName  = shift;
  my $option      = shift;
  my $bamFile     = shift;
  my $output      = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$bamFile], [$output]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['default', 'moduleVersion.samtools']]) . ' &&';
    $command .= ' samtools sort';
    $command .= ' ' . $option;
    $command .= ' ' . $bamFile;
    $command .= ' ' . $output;

    $ro_job->addCommand($command);
  }

  return $ro_job;
}

sub viewFilter {
  my $rH_cfg      = shift;
  my $bamFile     = shift;
  my $option      = shift;
  my $output      = shift;

  my $returnOutput = '';
  if (defined($output)) {
    $returnOutput = ' > ' . $output;
  }
  if (!(defined($option))) {
    $option = '';
  }

  my $ro_job = new Job();
  if (defined($output)) {
    $ro_job->testInputOutputs([$bamFile], [$output]);
  } else {
    $ro_job->testInputOutputs([$bamFile], undef);
  }

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['default', 'moduleVersion.samtools']]) . ' &&';
    $command .= ' samtools view';
    $command .= ' ' . $option;
    $command .= ' ' . $bamFile;
    $command .= $returnOutput;

    $ro_job->addCommand($command);
  }

  return $ro_job;
}

1;
