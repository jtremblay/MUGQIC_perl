#!/usr/bin/env python

# Python Standard Modules
import argparse
import collections
import logging
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(sys.argv[0])))

# MUGQIC Modules
from core.config import *
from core.pipeline import *
from bio.readset import *
from bio.trimmomatic import *

log = logging.getLogger(__name__)

class RnaSeqDeNovoAssembly(Pipeline):

    @property
    def readsets(self):
        return self._readsets

    @property
    def samples(self):
        return self._samples

    def trim(self, readset):
        trim_file_prefix = "trim/" + readset.sample.name + "/" + readset.name + ".trim."
        return trimmomatic(
            readset.fastq1,
            readset.fastq2,
            trim_file_prefix + "pair1.fastq.gz",
            trim_file_prefix + "single1.fastq.gz",
            trim_file_prefix + "pair2.fastq.gz",
            trim_file_prefix + "single2.fastq.gz",
            None,
            readset.quality_offset,
            trim_file_prefix + "out",
            trim_file_prefix + "stats.csv"
        )

    def normalization(self, readset):
        return normalize(readset.name + ".trim", readset.name + ".trim.normalized")

    def trinity(self):
        return trinity([readset.name + ".trim.normalized" for readset in self.readsets])

    def blast(self):
        return blastx("Trinity.fasta")

    def rsem(self, sample):
        return rsem("Trinity.fasta", sample.name)

    def annotate(self):
        return trinotate("Trinity.fasta")

    def deliverable(self):
        return nozzle(["Trinity.fasta", "Trinity_stats.csv", "trinotate.tsv"] + ["rsem_" + sample.name + ".fpkm" for sample in self.samples], "report")

    @property
    def step_dict_map(self):
        return [
            {"name": self.trim, "loop": self.readsets},
            {"name": self.normalization, "loop": self.readsets},
            {"name": self.trinity},
            {"name": self.blast},
            {"name": self.rsem, "loop": self.samples},
            {"name": self.annotate},
            {"name": self.deliverable}
        ]

    def __init__(self):
        # Initialize attributes to avoid AttributeError in default_argparser(self.step_dict_map)
        self._readsets = []
        self._samples = []

        argparser = PipelineArgumentParser(self.step_dict_map)
        # Add pipeline specific arguments
        argparser.add_argument("-r", "--readsets", help="readset file", type=file, required=True)
        argparser.add_argument("-d", "--design", help="design file", type=file)
        args = argparser.parse_args()

        self._readsets = parse_readset_file(args.readsets.name)
        # Retrieve unique samples from their readsets
        self._samples = list(collections.OrderedDict.fromkeys([readset.sample for readset in self._readsets]))

        Pipeline.__init__(self, args)
        
#RnaSeqDeNovoAssembly().show()
RnaSeqDeNovoAssembly().submit_jobs()
