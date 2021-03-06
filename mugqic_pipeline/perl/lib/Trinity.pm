#!/usr/bin/env perl

=head1 NAME

I<Trinity>

=head1 SYNOPSIS

Trinity::sub(args)

=head1 DESCRIPTION

B<Trinity> is a library to use the
transcriptome assembly package Trinity.

=head1 AUTHOR

David Morais dmorais@cs.bris.ac.uk
Joel Fillon joel.fillon@mcgill.ca

=cut

package Trinity;

# Strict Pragmas
#--------------------------
use strict;
use warnings;

#--------------------------

# Add the mugqic_pipeline/lib/ path relative to this Perl script to @INC library search variable
use FindBin;
use lib $FindBin::Bin;

# Dependencies
#-----------------------
use File::Basename;
use LoadConfig;
use Job;

#-------------------
# SUB
#-------------------

sub insilico_read_normalization {
  my $rH_cfg = shift;
  my $rA_leftReadFiles = shift;
  my $rA_rightReadFiles = shift;
  my $rA_singleReadFiles = shift;
  my $outputDirectory = shift;
  my $jellyfishMemory = shift;
  my $cpu = shift;

  # Find out if reads are paired or single-end
  my $readType;
  if (defined($rA_leftReadFiles) and defined($rA_rightReadFiles) and not(defined($rA_singleReadFiles))) {
    $readType = "paired";
  } elsif (not(defined($rA_leftReadFiles)) and not(defined($rA_rightReadFiles)) and defined($rA_singleReadFiles)) {
    $readType = "single";
  } else {
    die "Error in insilico_read_normalization: mixed or undefined paired/single reads!\n";
  }

  my $maxCoverage = LoadConfig::getParam($rH_cfg, 'normalization', 'maxCoverage', 1, 'int');
  my $kmerSize = LoadConfig::getParam($rH_cfg, 'normalization', 'kmerSize', 1, 'int');
  my $maxPctStdev = LoadConfig::getParam($rH_cfg, 'normalization', 'maxPctStdev', 1, 'float');

  my $leftList;
  my $rightList;
  my $singleCat;
  my $rA_inputs;
  my $rA_outputs;
  my $readFileOptions;

  if ($readType eq "paired") {    # Paired reads
    $leftList = "$outputDirectory/left";
    $rightList = "$outputDirectory/right";

    $rA_inputs = [@$rA_leftReadFiles, @$rA_rightReadFiles];
    $rA_outputs = [$leftList . ".norm.fq", $rightList . ".norm.fq"];
  } else {    # Single reads
    $singleCat = "$outputDirectory/single";
    $rA_inputs = [@$rA_singleReadFiles];
    $rA_outputs = [$singleCat . ".norm.fq"];
  }

  my $rO_job = new Job();
  $rO_job->testInputOutputs($rA_inputs, $rA_outputs);

  my $command = "mkdir -p $outputDirectory && \\\n";

  # Create sorted left/right lists of fastq.gz files
  if ($readType eq "paired") {    # Paired reads
    # Check if same number of left and right reads
    @$rA_leftReadFiles == @$rA_rightReadFiles or die "Error in normalization: left and right files numbers differ!"; 

    $command .= "rm -f $leftList $rightList && \\\n";
    foreach my $leftReadFile (@$rA_leftReadFiles) {
      $command .= "echo $leftReadFile >> $leftList && \\\n";
    }
    foreach my $rightReadFile (@$rA_rightReadFiles) {
      $command .= "echo $rightReadFile >> $rightList && \\\n";
    }
    $readFileOptions = " --left_list $leftList --right_list $rightList ";
  } else {    # Single reads
    $command .= "rm -f $singleCat && \\\n";
    # Check if fastq are compressed or not
    my $catCmd;
    if ($$rA_singleReadFiles[0] =~ /\.gz$/) {$catCmd = "zcat"} else {$catCmd = "cat"};
    # Merge all single fastq in one file since trinityrnaseq_r20131110 does not support --single_list!
    $command .= "$catCmd " . join(" ", @$rA_singleReadFiles) . " > $singleCat && \\\n";
    $readFileOptions = " --single $singleCat ";
  }

  # Load modules and run Trinity normalization
  $command .= LoadConfig::moduleLoad($rH_cfg, [['trinity', 'moduleVersion.trinity']]) . " && \\\n";
  $command .= "insilico_read_normalization.pl \\
$readFileOptions \\
 --output $outputDirectory \\\n";
  $command .= " --JM " . $jellyfishMemory . " \\\n";
  $command .= " --CPU " . $cpu . " \\\n";
  $command .= " --max_cov $maxCoverage \\\n";
  $command .= " --KMER_SIZE $kmerSize \\\n";
  $command .= " --max_pct_stdev $maxPctStdev \\\n";
  $command .= " " . LoadConfig::getParam($rH_cfg, 'normalization', 'normalizationOptions', 1) . " && \\\n";

  # Count normalized reads for stats
  $command .= "wc -l " . @$rA_outputs[0] . " | awk '{print \\\"# normalized $readType reads\\t\\\"\\\$1 / 4}' > $outputDirectory/normalization.stats.tsv";

  $rO_job->addCommand($command);

  return $rO_job;
}

sub trinity {
  my $rH_cfg  = shift;
  my $rA_leftReadFiles = shift;
  my $rA_rightReadFiles = shift;
  my $rA_singleReadFiles = shift;
  my $outputDirectory = shift;

  defined($outputDirectory) or die "Error in trinity: outputDirectory is not defined!";

  # Find out if reads are paired or single-end
  my $readType;
  if (defined($rA_leftReadFiles) and defined($rA_rightReadFiles) and not(defined($rA_singleReadFiles))) {
    $readType = "paired";
  } elsif (not(defined($rA_leftReadFiles)) and not(defined($rA_rightReadFiles)) and defined($rA_singleReadFiles)) {
    $readType = "single";
  } else {
    die "Error in trinity: mixed or undefined paired/single reads!\n";
  }

  my $rA_inputs;
  my $readFileOptions;

  if ($readType eq "paired") {    # Paired reads
    $rA_inputs = [@$rA_leftReadFiles, @$rA_rightReadFiles];
    $readFileOptions = " --left " . join(" ", @$rA_leftReadFiles) . " --right " . join(" ", @$rA_rightReadFiles);
  } else {    # Single reads
    $rA_inputs = [@$rA_singleReadFiles];
    $readFileOptions = " --single " . join(" ", @$rA_singleReadFiles);
  }

  my $rO_job = new Job();
  $rO_job->testInputOutputs($rA_inputs, ["$outputDirectory/Trinity.fasta"]);

  my $command = LoadConfig::moduleLoad($rH_cfg, [
    ['trinity', 'moduleVersion.java'],
    ['trinity', 'moduleVersion.trinity'],
    ['trinity', 'moduleVersion.bowtie'],
    ['trinity', 'moduleVersion.samtools'],
    ['trinity', 'moduleVersion.cranR']
  ]) . " && \\\n";

  $command .= "Trinity \\
$readFileOptions \\
 --output $outputDirectory \\\n";
  $command .= " --JM " . LoadConfig::getParam($rH_cfg, 'trinity', 'jellyfishMemory', 1) . " \\\n";
  $command .= " --CPU " . LoadConfig::getParam($rH_cfg, 'trinity', 'CPU', 1, 'int') . " \\\n";
  $command .= " --bflyCPU " . LoadConfig::getParam($rH_cfg, 'trinity', 'bflyCPU', 1, 'int') . " \\\n";
  $command .= " " . LoadConfig::getParam($rH_cfg, 'trinity', 'trinityOptions', 1) . " && \\\n";

  # Create Trinity FASTA ZIP file for future deliverables
  $command .= "zip -j $outputDirectory/Trinity.fasta.zip $outputDirectory/Trinity.fasta && \\\n";

  # Compute assembly stats
  $command .= "Rscript -e 'library(gqSeqUtils); dnaFastaStats(filename = \\\"$outputDirectory/Trinity.fasta\\\", type = \\\"trinity\\\", output.prefix = \\\"$outputDirectory/Trinity.stats\\\")'";

  $rO_job->addCommand($command);

  return $rO_job;
}

sub transdecoder {
  my $rH_cfg = shift;
  my $transcripts = shift;
  my $outputDirectory = shift;

  my $rO_job = new Job();

  $rO_job->testInputOutputs([$transcripts], ["$outputDirectory/Trinity.fasta.transdecoder.pep", "$outputDirectory/Trinity.fasta.transdecoder.pfam.dat.domtbl"]);

  my $command = LoadConfig::moduleLoad($rH_cfg, [
    ['transdecoder', 'moduleVersion.cd-hit'],
    ['transdecoder', 'moduleVersion.hmmer'],
    ['transdecoder', 'moduleVersion.trinity']
  ]) . " && \\\n";

  $command .= "mkdir -p $outputDirectory && cd $outputDirectory && \\\n";
  # Remove previous symlink if any to avoid transdecoder error "ln: creating symbolic link `Trinity.fasta.transdecoder.pfam.dat.domtbl': File exists" (transdecoder should do by itself!)
  $command .= "rm -f Trinity.fasta.transdecoder.pfam.dat.domtbl && \\\n";
  $command .= "\\\$TRINITY_HOME/trinity-plugins/transdecoder/TransDecoder \\
  --t $transcripts \\\n";
  $command .= "  --search_pfam " . LoadConfig::getParam($rH_cfg, 'transdecoder', 'pfamDb', 1, 'filepath') . " \\\n";
  $command .= "  --CPU " . LoadConfig::getParam($rH_cfg, 'transdecoder', 'CPU', 1, 'int') . " \\\n";
  $command .= "  " . LoadConfig::getParam($rH_cfg, 'transdecoder', 'transdecoderOptions', 0);

  $rO_job->addCommand($command);

  return $rO_job;
}

sub rnammerTranscriptome {
  my $rH_cfg = shift;
  my $transcripts = shift;
  my $outputDirectory = shift;

  my $rO_job = new Job();

  $rO_job->testInputOutputs([$transcripts], ["$outputDirectory/Trinity.fasta.rnammer.gff"]);

  my $command = "module load mugqic/hmmer/2.3.2 && \\\n";

  $command .= LoadConfig::moduleLoad($rH_cfg, [
    ['rnammerTranscriptome', 'moduleVersion.rnammer'],
    ['rnammerTranscriptome', 'moduleVersion.trinity'],
    ['rnammerTranscriptome', 'moduleVersion.trinotate']
  ]) . " && \\\n";

  $command .= "mkdir -p $outputDirectory && cd $outputDirectory && \\\n";
  $command .= "\\\$TRINOTATE_HOME/util/rnammer_support/RnammerTranscriptome.pl \\
  --transcriptome $transcripts \\
  --path_to_rnammer \\\`which rnammer\\\` \\\n";
  $command .= "  " . LoadConfig::getParam($rH_cfg, 'rnammerTranscriptome', 'rnammerTranscriptomeOptions', 0);

  $rO_job->addCommand($command);

  return $rO_job;
}

sub signalp {
  my $rH_cfg = shift;
  my $input = shift;
  my $output = shift;

  my $rO_job = new Job();

  $rO_job->testInputOutputs([$input], [$output]);

  my $command = LoadConfig::moduleLoad($rH_cfg, [
    ['signalp', 'moduleVersion.signalp']
  ]) . " && \\\n";

  my $outputDirectory = dirname($output);

  $command .= "signalp \\\n";
  $command .= "  -T $outputDirectory/tmp \\\n";
  $command .= "  -n $output \\\n";
  $command .= "  " . LoadConfig::getParam($rH_cfg, 'signalp', 'signalpOptions', 0) . " \\\n";
  $command .= "  $input";

  $rO_job->addCommand($command);

  return $rO_job;
}

sub tmhmm {
  my $rH_cfg = shift;
  my $input = shift;
  my $output = shift;

  my $rO_job = new Job();

  $rO_job->testInputOutputs([$input], [$output]);

  my $command = LoadConfig::moduleLoad($rH_cfg, [
    ['tmhmm', 'moduleVersion.tmhmm']
  ]) . " && \\\n";

  my $outputDirectory = dirname($output);

  $command .= "mkdir -p $outputDirectory && cd $outputDirectory && \\\n";
  $command .= "tmhmm --short < $input > $output";

  $rO_job->addCommand($command);

  return $rO_job;
}

sub alignEstimateAbundancePrepareReference {
  my $rH_cfg = shift;
  my $transcripts = shift;

  my $rO_job = new Job();

  $rO_job->testInputOutputs([$transcripts], ["$transcripts.RSEM.transcripts.fa", "$transcripts.RSEM.idx.fa"]);

  my $command = LoadConfig::moduleLoad($rH_cfg, [
    ['alignEstimateAbundance', 'moduleVersion.bowtie'],
    ['alignEstimateAbundance', 'moduleVersion.rsem'],
    ['alignEstimateAbundance', 'moduleVersion.samtools'],
    ['alignEstimateAbundance', 'moduleVersion.trinity']
  ]) . " && \\\n";

  $command .= "align_and_estimate_abundance.pl \\
  --transcripts $transcripts \\
  --seqType fa \\
  --est_method RSEM \\
  --aln_method bowtie \\
  --trinity_mode \\
  --prep_reference";

  $rO_job->addCommand($command);

  return $rO_job;
}

sub alignEstimateAbundance {
  my $rH_cfg = shift;
  my $transcripts = shift;
  my $sample = shift;

  my $rO_job = new Job();

  $rO_job->testInputOutputs(
    [$transcripts],
    ["\$WORK_DIR/alignEstimateAbundance/$sample/$sample.genes.results",
     "\$WORK_DIR/alignEstimateAbundance/$sample/$sample.isoforms.results"]
  );

  my $command = LoadConfig::moduleLoad($rH_cfg, [
    ['alignEstimateAbundance', 'moduleVersion.bowtie'],
    ['alignEstimateAbundance', 'moduleVersion.rsem'],
    ['alignEstimateAbundance', 'moduleVersion.samtools'],
    ['alignEstimateAbundance', 'moduleVersion.trinity']
  ]) . " && \\\n";

  my $left  = "\\`find \$WORK_DIR/reads -name $sample*pair1*.fastq.gz | sort | paste -s -d,\\`";
  my $right  = "\\`find \$WORK_DIR/reads -name $sample*pair2*.fastq.gz | sort | paste -s -d,\\`";

  $command .= "align_and_estimate_abundance.pl \\
  --transcripts $transcripts \\
  --seqType fa \\
  --left $left \\
  --right $right \\
  --seqType fq \\
  --est_method RSEM \\
  --aln_method bowtie \\
  --trinity_mode \\
  --SS_lib_type RF \\
  --output_prefix $sample \\
  --output_dir \$WORK_DIR/alignEstimateAbundance/$sample \\
  --thread_count " . LoadConfig::getParam($rH_cfg, 'alignEstimateAbundance', 'CPU', 1, 'int');

  $rO_job->addCommand($command);

  return $rO_job;
}

1;
