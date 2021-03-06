#!/usr/bin/env perl

=head1 NAME

I<SubmitToCluster>

=head1 SYNOPSIS

SubmitToCluster->printSubmitCmd()

=head1 DESCRIPTION

B<SubmitToCluster> is a library that reads from a config file and 
submits jobs to a cluster.

=head1 AUTHOR

B<Louis Letourneau> - I<louis.letourneau@mail.mcgill.ca>

=head1 DEPENDENCY

=cut

package SubmitToCluster;

# Strict Pragmas
#---------------------
use strict;
use warnings;

#---------------------

# Add the mugqic_pipeline/lib/ path relative to this Perl script to @INC library search variable
use FindBin;
use lib $FindBin::Bin;

# Dependencies
#--------------------
use Cwd 'abs_path';
use File::Basename;
use LoadConfig;

#--------------------

# SUB
#--------------------
sub initPipeline {
  my $workDir = shift;

  # Check working directory and set it to current one if not defined
  if (defined $workDir) {
    if (-d $workDir) {
      $workDir = abs_path($workDir);
    } else {
      die "Error: $workDir does not exist or is not a directory";
    }
  } else {
    $workDir = "`pwd`";
  }

  # Add script name (without suffix) as job list filename prefix (in practice, identical to pipeline name)
  my $jobListPrefix = fileparse($0, qr/\.[^.]*/) . "_";

  # Set environment work dir for further file path resolutions
  $ENV{'WORK_DIR'}=$workDir;

  # Set pipeline header and global variables
  print <<END;
#!/bin/bash

WORK_DIR=$workDir
JOB_OUTPUT_ROOT=\$WORK_DIR/job_output
TIMESTAMP=`date +%FT%H.%M.%S`
JOB_LIST=\$JOB_OUTPUT_ROOT/${jobListPrefix}job_list_\$TIMESTAMP
cd \$WORK_DIR

END
}

sub printSubmitCmd {
  my $rH_cfg = shift;
  my $stepName = shift;
  my $jobNameSuffix = shift;
  my $jobIdPrefix = shift;
  my $dependencies = shift;
  my $sampleName = shift;
  my $rO_job = shift;
  my $commandIdx = shift;

  if($rO_job->isUp2Date()) {
    return undef;
  }

  if(!defined($commandIdx)) {
    $commandIdx = 0;
  }
  my $command = $rO_job->getCommand($commandIdx);

  # Set Job ID
  my $jobId = uc($jobIdPrefix) . "_JOB_ID";
  $jobId =~ s/\W/_/g;

  # Set job name and job output directory depending on a global or sample-based step
  my $jobName = $stepName;
  my $jobOutputDir;
  if (defined($sampleName) and $sampleName ne "") {
    $jobName .= ".$sampleName";
    $jobOutputDir .= $sampleName;
  } else {
    $jobOutputDir .= "global";
  }
  if (defined($jobNameSuffix) and $jobNameSuffix ne "") {
    $jobName .= ".$jobNameSuffix";
  }

  # Check if $dependencies is initialized
  unless (defined($dependencies)) {
    $dependencies = "";
  }

  # Print out job header and settings nicely
  my $separatorLine = "#" . "-" x 79 . "\n";
  print $separatorLine;
  print "# $jobId $jobName\n";
  print $separatorLine;
  print "JOB_NAME=$jobName\n";
  print "JOB_DEPENDENCIES=$dependencies\n";
  # Set job output filename based on job name and timestamp
  print "JOB_OUTPUT_RELATIVE_PATH=$jobOutputDir/\${JOB_NAME}_\$TIMESTAMP.o\n";
  print "JOB_OUTPUT=\$JOB_OUTPUT_ROOT/\$JOB_OUTPUT_RELATIVE_PATH\n";
  print "mkdir -p `dirname \$JOB_OUTPUT`\n";

  # Assign job number to job ID if any
  if (LoadConfig::getParam($rH_cfg, $stepName, 'clusterCmdProducesJobId') eq "true") {
    print $jobId . '=$(';
  }

  my $rA_FilesToTest = $rO_job->getFilesToTest();
  # Erase dones, on all jobs of the series
  if (defined($rA_FilesToTest) && @{$rA_FilesToTest} > 0) {
    print "echo \"rm -f \\\n  " . join(" \\\n  ", @{$rA_FilesToTest}) . " && \\\n";
  } else {
    print 'echo "';
  }

  # Print out job command
  print $command;
  print " && \\\n" . 'MUGQIC_STATE=\${PIPESTATUS} &&  echo \"MUGQICexitStatus:\${MUGQIC_STATE}\" ';
  # Only add if it's the last job of the series.
  if (defined($rA_FilesToTest) && @{$rA_FilesToTest} > 0 && $commandIdx == $rO_job->getNbCommands() - 1) {
    print ' && if  [ \"\$MUGQIC_STATE\" == \"0\" ] ; then touch ' . "\\\n  " . join(" \\\n  ", @{$rA_FilesToTest}) . " ; fi \\\n";
  }
  print ' && exit \${MUGQIC_STATE} ';
  print '"';
  print ' | ' . LoadConfig::getParam($rH_cfg, $stepName, 'clusterSubmitCmd');
  print " " . LoadConfig::getParam($rH_cfg, $stepName, 'clusterOtherArg');
  print " " . LoadConfig::getParam($rH_cfg, $stepName, 'clusterWorkDirArg') . " \$WORK_DIR";
  print " " . LoadConfig::getParam($rH_cfg, $stepName, 'clusterOutputDirArg') . " \$JOB_OUTPUT";
  print " " . LoadConfig::getParam($rH_cfg, $stepName, 'clusterJobNameArg') . " \$JOB_NAME";
  print " " . LoadConfig::getParam($rH_cfg, $stepName, 'clusterWalltime');
  print " " . LoadConfig::getParam($rH_cfg, $stepName, 'clusterQueue');
  print " " . LoadConfig::getParam($rH_cfg, $stepName, 'clusterCPU');
  if ($dependencies ne "") {
    print " " . LoadConfig::getParam($rH_cfg, $stepName, 'clusterDependencyArg') . "\$JOB_DEPENDENCIES";
  }
  print " " . LoadConfig::getParam($rH_cfg, $stepName, 'clusterSubmitCmdSuffix');
  if (LoadConfig::getParam($rH_cfg, $stepName, 'clusterCmdProducesJobId') eq "true") {
    print ")";
  }
  print "\n";

  if (LoadConfig::getParam($rH_cfg, $stepName, 'clusterCmdProducesJobId') eq "false") {
    print "$jobId=$jobName\n";
  }

  $rO_job->setCommandJobId($commandIdx, '$' . $jobId);

  # Write job parameters in job list file
  print "echo \"\$$jobId\t\$JOB_NAME\t\$JOB_DEPENDENCIES\t\$JOB_OUTPUT_RELATIVE_PATH\" >> \$JOB_LIST\n\n"; 
  return $jobId;
}

1;
