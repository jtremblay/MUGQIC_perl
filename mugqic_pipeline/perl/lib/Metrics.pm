#!/usr/bin/env perl

=head1 NAME

I<Metrics>

=head1 SYNOPSIS

Metrics-> rnaQc()

=head1 DESCRIPTION

B<Metrics> is a library to generate QC, stats and metrics

Input = file_name

Output = array


=head1 AUTHOR
B<Mathieu Bourgey> - I<mbourgey@genomequebec.com>

=head1 DEPENDENCY

B<Pod::Usage> Usage and help output.

=cut

package Metrics;

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
use LoadConfig;
use SAMtools;

# SUB
#-----------------------
sub rnaQc {
  my $rH_cfg       = shift;
  my $inputFile    = shift;
  my $outputFolder = shift;
  my $libraryType  = shift;

  if (!defined($libraryType) || $libraryType eq "") {
    $libraryType= 'unknown';
  }
  my $outputIndexFile= $outputFolder . '/index.html';

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$inputFile], [$outputFolder . '.zip', $outputIndexFile]);
  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['mergeFiles', 'moduleVersion.java'], ['rnaQc', 'moduleVersion.bwa'], ['rnaQc', 'moduleVersion.rnaseqc']]) . ' &&';
    $command .= ' java -Djava.io.tmpdir=' . LoadConfig::getParam($rH_cfg, 'rnaQc', 'tmpDir') . ' ' . LoadConfig::getParam($rH_cfg, 'rnaQc', 'extraJavaFlags') . ' -Xmx' . LoadConfig::getParam($rH_cfg, 'rnaQc', 'metricsRam') . ' -jar \${RNASEQC_JAR}';
    $command .= ' -n ' . LoadConfig::getParam($rH_cfg, 'rnaQc', 'topTranscript', 1, 'int');
    $command .= ' -s ' . $inputFile;
    $command .= ' -t ' . LoadConfig::getParam($rH_cfg, 'rnaQc', 'referenceGtf', 1, 'filepath');
    $command .= ' -r ' . LoadConfig::getParam($rH_cfg, 'rnaQc', 'referenceFasta', 1, 'filepath');
    $command .= ' -o ' . $outputFolder;
    if (defined($libraryType) && $libraryType eq "single") {
      $command .= ' -singleEnd';
    }
    $command .= ' -BWArRNA ' . LoadConfig::getParam($rH_cfg, 'rnaQc', 'ribosomalFasta', 1, 'filepath') . ' &&';
    $command .= ' zip -r ' . $outputFolder . '.zip ' . $outputFolder;

    $ro_job->addCommand($command);
  }

  return $ro_job;
}

sub saturation {
  my $rH_cfg = shift;
  my $countFile = shift;
  my $geneSizeFile = shift;
  my $rpkmDir = shift;
  my $saturationDir = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$countFile], [$saturationDir . '.zip']);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['saturation', 'moduleVersion.cranR'], ['saturation', 'moduleVersion.tools']]) . ' &&';
    $command .= ' Rscript \$R_TOOLS/rpkmSaturation.R ' . $countFile . ' ' . $geneSizeFile . ' ' . $rpkmDir . ' ' . $saturationDir;
    $command .= ' ' . LoadConfig::getParam($rH_cfg, 'saturation', 'threadNum', 1, 'int');
    $command .= ' ' . LoadConfig::getParam($rH_cfg, 'saturation', 'optionR', 0) . ' &&';
    $command .= ' zip -r ' . $saturationDir . '.zip ' . $saturationDir;

    $ro_job->addCommand($command);
  }
  return $ro_job;
}

sub fpkmCor {
  my $rH_cfg         = shift;
  my $patternFile    = shift;
  my $folderFile     = shift;
  my $outputBaseName = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$patternFile], [$outputBaseName]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['metrics', 'moduleVersion.cranR'], ['metrics', 'moduleVersion.tools']]) . ' &&';
    $command .= ' Rscript \$R_TOOLS/fpkmStats.R ' . $patternFile . ' ' . $folderFile . ' ' . $outputBaseName;

    $ro_job->addCommand($command);
  }
  return $ro_job;
}

sub readStats {
  my $rH_cfg = shift;
  my $inputFile = shift;
  my $outputFile = shift;
  my $sampleName = shift;
  my $fileType = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$inputFile], [$outputFile]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    if ((lc $fileType) eq "trim") {
      $command .= 'grep \"Input Read\" ' . $inputFile;
      $command .= ' | awk -F\":\" -v na=' . $sampleName . ' \' BEGIN { OFS=\"\t\" } { split(\$2,a,\" \"); split(\$3,b,\" \"); print na,a[1],b[1]} \'';
      $command .= ' > ' . $outputFile;
    } elsif  ((lc $fileType) eq "bam") {
      ##decrepited
      my $unmapOption = '-F260';
      #Just need the command
      my $rO_viewFilterJob = SAMtools::viewFilter($rH_cfg, $inputFile, $unmapOption, undef);

      $command .= $rO_viewFilterJob->getCommand(0);
      $command .= ' | awk \' { print \$1} \'';
      #---- flefebvr Tue 16 Apr 13:47:53 2013
      #$command .= ' | sort -u | wc -l  > ' . $outputFile;
      $command .= ' | sort -u -T ' . LoadConfig::getParam($rH_cfg, 'metrics', 'tmpDir');
      $command .= ' | wc -l  > ' . $outputFile;
      #----
    }

    $ro_job->addCommand($command);
  }

  return $ro_job;
}


##Deprecated everything should be in the report
sub mergeIndvidualReadStats {
  my $rH_cfg = shift;
  my $sampleName = shift;
  my $rawFile  = shift;
  my $filterFile = shift;
  my $alignFile = shift;
  my $outputFile =shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$alignFile], [$outputFile]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= 'echo \"' . $sampleName . '\"';
    $command .= ' | cat - ' . $rawFile . ' ' . $filterFile . ' ' . $alignFile;
    $command .= ' | tr \'\n\' \',\' ';
    $command .= ' | awk \' BEGIN {FS=\",\"} { print \$1 \",\" \$2 \",\" \$3 \",\" \$4}\'';
    $command .= ' > ' . $outputFile . ' &&';
    $command .= ' rm  ' . $rawFile . ' ' . $filterFile . ' ' . $alignFile;

    $ro_job->addCommand($command);
  }

  return $ro_job;
}

sub mergeReadStats {
  my $rH_cfg      = shift;
  my $patternFile = shift;
  my $folderFile  = shift;
  my $outputFile  = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$patternFile], [$outputFile]);

  if (!$ro_job->isUp2Date()) {
  my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['metrics', 'moduleVersion.cranR'], ['metrics', 'moduleVersion.tools']]) . ' &&';
    $command .= ' Rscript \$R_TOOLS/mergeReadStat.R ' . $patternFile . ' ' . $folderFile . ' ' . $outputFile . ' &&';
    $command .= ' rm ' . $folderFile . '/*' . $patternFile;

    $ro_job->addCommand($command);
  }
  return $ro_job;
}


sub mergeTrimmomaticStats {
  my $rH_cfg      = shift;
  my $libraryType = shift;
  my $patternFile = shift;
  my $folderFile  = shift;
  my $outputFile  = shift;

  if (!defined($libraryType) || $libraryType eq "") {
    $libraryType= 'unknown';
  }

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$patternFile], [$outputFile]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['metrics', 'moduleVersion.cranR'], ['metrics', 'moduleVersion.tools']]) . ' &&';
    $command .= ' Rscript \$R_TOOLS/mergeTrimmomaticStat.R ' . $patternFile . ' ' . $folderFile . ' ' . $outputFile . ' ' . $libraryType;

    $ro_job->addCommand($command);
  }

  return $ro_job;
}

sub mergeSampleDnaStats {
  my $rH_cfg         = shift;
  my $experimentType = shift;
  my $folderFile     = shift;
  my $outputFile     = shift;

  if (!defined($experimentType) || $experimentType eq "") {
    $experimentType= 'unknown';
  }
  my $ro_job = new Job();
  $ro_job->testInputOutputs([$folderFile], [$outputFile]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['metrics', 'moduleVersion.cranR'], ['metrics', 'moduleVersion.tools']]) . ' &&';
    $command .= ' Rscript \$R_TOOLS/DNAsampleMetrics.R ' . $folderFile . ' ' . $outputFile . ' ' . $experimentType;
    $ro_job->addCommand($command);
  }

  return $ro_job;
}

sub svnStatsChangeRate {
  my $rH_cfg     = shift;
  my $inputVCF   = shift;
  my $outputFile = shift;
  my $listFile   = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$inputVCF], [$outputFile]);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command = LoadConfig::moduleLoad($rH_cfg, [['metricsSNV', 'moduleVersion.python'], ['metricsSNV', 'moduleVersion.tools']]) . ' &&';
    $command .= ' python \$PYTHON_TOOLS/vcfStats.py -v ' . $inputVCF;
    $command .= ' -d ' . LoadConfig::getParam($rH_cfg, 'metricsSNV', 'referenceSequenceDictionary', 1, 'filepath');
    $command .= ' -o ' . $outputFile;
    $command .= ' -f ' . $listFile;

    $ro_job->addCommand($command);
  }

  return $ro_job;
}


sub svnStatsGetGraph {
  my $rH_cfg          = shift;
  my $listFile        = shift;
  my $outputBaseName  = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$listFile], [$outputBaseName . 'snvGraphMetrics_listFiles.txt']);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command = LoadConfig::moduleLoad($rH_cfg, [['metricsSNV', 'moduleVersion.cranR'], ['metricsSNV', 'moduleVersion.tools']]) . ' &&';
    $command .= ' Rscript \$R_TOOLS/snvGraphMetrics.R ' . $listFile . ' ' . $outputBaseName;
    $ro_job->addCommand($command);
  }

  return $ro_job;
}


sub mergePrintReadStats {
  my $rH_cfg         = shift;
  my $sampleName     = shift;
  my $trimOutputFile = shift;
  my $flagStatsFile  = shift;
  my $outputFile     = shift;
  my $command        = undef;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$flagStatsFile], [$outputFile]);

  if (!$ro_job->isUp2Date()) {
    $command .= LoadConfig::moduleLoad($rH_cfg, [['metrics', 'moduleVersion.tools']]) . ' &&';
    $command .= ' perl -MReadMetrics -e \' ReadMetrics::mergeStats(\"' . $sampleName . '\",';
    $command .= ' \"' . $outputFile . '\", ReadMetrics::parseTrimOutput(\"' . $sampleName . '\",';
    $command .= ' \"' . $trimOutputFile . '\"), ReadMetrics::parseFlagstats(\"' . $sampleName . '\",';
    $command .= ' \"' . $flagStatsFile . '\"));\'';

    $ro_job->addCommand($command);
  }
  return $ro_job;
}

1;
