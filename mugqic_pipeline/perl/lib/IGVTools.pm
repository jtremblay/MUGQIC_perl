#!/usr/bin/env perl

=head1 NAME

I<IGVTools>

=head1 SYNOPSIS

IGVTools::computeTDF

=head1 DESCRIPTION

B<IGVTools> is a library used to generate tiled files for IGV

Input = file_name

Output = array

=head1 AUTHOR


=head1 DEPENDENCY

B<Pod::Usage> Usage and help output.

B<Data::Dumper> Used to debbug

=cut

package IGVTools;

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

# SUB
#-----------------------
sub computeTDF {
  my $rH_cfg   = shift;
  my $inputBAM = shift;

  my $ro_job = new Job();
  $ro_job->testInputOutputs([$inputBAM], [$inputBAM . '.tdf']);

  if (!$ro_job->isUp2Date()) {
    my $command;
    $command .= LoadConfig::moduleLoad($rH_cfg, [['igvtools', 'moduleVersion.java'], ['igvtools', 'moduleVersion.igvtools']]) . ' &&';
    $command .= ' igvtools count -f min,max,mean ';
    $command .= $inputBAM . ' ' . $inputBAM . '.tdf';
    $command .= ' ' . LoadConfig::getParam($rH_cfg, 'computeTDF', 'igvGenome');

    $ro_job->addCommand($command);
  }
  return $ro_job;
}

1;
