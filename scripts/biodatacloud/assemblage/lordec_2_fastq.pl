#!/usr/bin/perl -w

use strict;
use Getopt::Long;

###########################
my $what = "
	Script qui recupere les valeurs de qualite de fichiers fastq en entree
	et les adapte aux fichiers fasta corriges en sortie de LoRDEC.";
my $version =
	# "1.0 (24/11/15; emeric.sevin\@u-bordeaux.fr)";	# Cree pour les besoins du pipe BioDataCloud ("out-of-the-box")
	# "2.0 (30/11/15; emeric.sevin\@u-bordeaux.fr)";	# Modifie le format de la structure des reads corriges en parsing de Lordec pour optimisation
	"2.1 (15/02/16; emeric.sevin\@u-bordeaux.fr)";		# Version nettoyee et commentee pour eventuel partage
###########################

my $DEBUG = 0;
my ($infil, $iqual, $lordecfil, $newLordec, $help, $in);
my $inflate = 3;
my $otype = 1;
my ($corrBases, $totalBases, $ambigQualMatch, $badReads, $written) = (0,0,0,0,0);

my $shortmsg = "Try option '-help' for tool description and full list of options\n";
my @usage = (
	"perl $0 -c <lordec_corrected.fasta> -i <original.fastq>\n",
	"perl $0 -corr <FILE> -init <FILE> [options]\n".
	"Options:
	-corr FILE\t: LoRDEC-corrected reads FILE.
	-init FILE\t: Original reads FILE (can be fastq or fasta).
	-qual FILE\t: Quality values FILE. Required if '-init FILE' is fasta.
	-format INT\t: Specify output FORMAT: fastq (1; default) or fasta+qual (2).
	-out FILE\t: Specify output FILE name.
	-help\t\t: Display this description and exit
");

GetOptions(	"init=s"		=> \$infil,		# Sequences input file
			"qual=s"		=> \$iqual,		# Quality values file if seq input file not a fastq
			"corr=s"		=> \$lordecfil,	# Fasta file corrected by LoRDEC
			"format=i"		=> \$otype,		# Output file type (fastq or fasta+qual)
			"out=s"			=> \$newLordec,	# Output file type (fastq or fasta+qual)
			"debug=i"		=> \$DEBUG,		# Debug option to print milestones (1:mid verbosity; 2:max verbosity)
			"help|?"		=> \$help 		)
or die "\n\t$shortmsg\n";
exit print "$what\n\t# v$version\n\nUsage:\n\t$usage[1]\n" if defined $help;
die "\nMinimal usage: $usage[0]\n\t$shortmsg\n" unless (defined $infil && defined $lordecfil);
if (!defined $newLordec) {
	my $suff = $otype == 1 ? '_l2q.fastq' : '_l2q.qual';
	($newLordec = $lordecfil) =~ s/\.f(ast)?a$/$suff/;
}
else {
	warn "~!~ Funny output filename: I expected a ".($otype == 1 ? '.f[ast]q' : '.qual')." suffix (but you're the boss!)\n" unless $newLordec =~ /\.f(ast)?q$|\.qual$/;
}

print "\n";
## --------------
## Load initial sequences and quality values
## --------------
my %inireads = ();
if ($infil =~ /\.f(ast)?a$/) {
	die "Input seq file is fasta, please use option '-qual' to specify the corresponding quality values file.\n" unless (defined $iqual);
###################
die "~!~\tInput format 'fasta+qual' not supported yet.\n";
###################
	fetch_sequences($infil, \%inireads);
	fetch_qual($iqual,\%inireads);
}
else { 
	parse_fastq($infil,\%inireads);
	print "Loaded ".scalar(keys %inireads)." sequence+qv's\n"; $| = 1;
}

## --------------
## Load LoRDEC corrected sequences structure
## --------------
my %loreads = sieve($lordecfil);
my $nreads = scalar(keys %loreads);
print "Loaded $nreads LoRDEC corrected sequence structures\n"; $| = 1;

## --------------
## Combine Lordec corrected sequences with initial and adapted quality values
## and write new seq+qual (if outformat=fq) or just qual (if outformat=fa+qu) to output file
## --------------
open (OUT , ">$newLordec") or die " Couldn't create ouput file $newLordec: $!\n";
foreach my $id (sort keys %loreads) {
print "\n$id\n" if $DEBUG;
	if (!defined $inireads{$id}) {
		warn "### $id:\n\tAbsent from original set of sequences, skipping...\n";
		next;
	}
	else {
		if (defined $loreads{$id}{'noModif'}) {
			$badReads++;
			$loreads{$id}{'newQ'} = $inireads{$id}{'qual'};
		}
		else {
			my @chunks = split '_', $loreads{$id}{'struct'};
			foreach my $chunk (@chunks) {
			## This will loop only once if the read was fully corrected (thus producing only one chunk)
print "$chunk\n" if $DEBUG;
				my $ckl = length $chunk;
				if ($chunk eq uc($chunk)) {
				## Chunk is a corrected one
					$corrBases += $ckl;
					## Possibly infer a growing factor for QV depending on corrected fraction of the read? on length of corrected chunk?
					## 0-24% | 25-49% | 50-74% | 75-99% | 100%
					##   1   |   2    |    3   |   4    |  5
					$loreads{$id}{'newQ'} .= chr($inireads{$id}{'maxq'} + 33 + $inflate) x $ckl;
				}
				else {
				## Chunk is an original one
					## Holding count of short chunks likely to match another part of the sequence by chance
					if ($ckl <= 4) { $ambigQualMatch++; print "(ambig)" if $DEBUG; }
					## Using '/cg' modifiers so that ambiguous matches might be done closer to real position (and not a random match anywhere in the seq)
					## This doesn't mean ambiguous matches are removed, only that the span of false positives is reduced
					$inireads{$id}{'seq'} =~ /$chunk/cgi;
					my ($sta, $end) = (@-, @+);
print "\tsta=$sta / end = $end\n" if $DEBUG;
					if (!defined $sta || !defined $end) {
						warn "### $id:\n\tUncorrected chunk not found in original read, problem with LoRDEC output\n";
						warn "\tAssigning near minimal QV to whole $ckl bases of chunk\n";
						$loreads{$id}{'newQ'} .= chr(1 + 33) x $ckl;			# Assign near minimal (1) QV to chunk
					}
					else {
						$loreads{$id}{'newQ'} .= substr $inireads{$id}{'qual'}, $sta, $end-$sta;
					}

				}
			}
		}
		my ($slen, $qlen) = (length $loreads{$id}{'seq'}, length $loreads{$id}{'newQ'});
		if ($slen != $qlen) {
			warn "### $id:\n\tSequence and quality lengths didn't match ($slen != $qlen), skipping!! ###\n";
		}
		else {
			print OUT formatted_seq($otype, $id, $loreads{$id});
			$written++;
		}
	}
}
close (OUT);
print "\n";
print "Wrote $written ".($otype == 1 ? "sequences and qualities" : "qualities")." to $newLordec\n";
print "\n$ambigQualMatch ambiguous quality assignments (short chunks [< 5 nt] likely to match the wrong position)\n";
print sprintf("%.2f", 100*$corrBases/$totalBases)."% of bases in LoRDEC file are corrected bases\n";
print sprintf("%.2f", 100*$badReads/$nreads)." % ($badReads) of the reads were not corrected by LoRDEC at all\n";
print "\n";


######################################
## SUBS ##############################
######################################

## Load sequences and qualities from fastq file
sub parse_fastq {
	my ($fi, $href) = @_;
	my $id;
	open(FQ, "<$fi") or die "Couldn't open input file $fi: $!\n";
	for (my $i = 1; <FQ>; $i++) {
		chomp;
		if ($i == 1) {
			/^\@(.+)/ or die "$fi: Unrecognized format [header]\n";
			$id = $1;
		}
		elsif ($i == 2) { $$href{$id}{'seq'} = $_; }
		elsif ($i == 3) { die "$fi (line $.): Unrecognized seq-qual separator, quitting\n" unless /\+/; }
		elsif ($i == 4) {
			$$href{$id}{'qual'} = $_;
			$$href{$id}{'maxq'} = max_qual($$href{$id}{'qual'});
			$i = 0;
		}
	}
	close(FQ);
}

## Compute maximum quality value from ascii qualities vector
sub max_qual {
	my @qvec = fq2qual(shift);
	my $max = 0;
	foreach my $qv (@qvec) {
		if ($qv > $max) { $max = $qv; }
	}
	return $max;
}

## Convert ascii qualities (PacBio) to phred33 (numerical)
sub fq2qual {
	my $qvec = shift;
	my @ascii = split '', $qvec;
	my @phred33 = map {ord($_) - 33} @ascii;
	return @phred33;
}

## Load sequences from fasta file (NOT IMPLEMENTED YET)
sub fetch_sequences {
	my ($fi, $hsh);
	open(IN, "<$fi") or die "Couldn't open input file $fi: $!\n";
	# Parse INFA to fill $hsh
	close(IN);
}

## Load quality values from qual file (NOT IMPLEMENTED YET)
sub fetch_qual {
	my ($fi, $hsh);
	open(IN, "<$fi") or die "Couldn't open input file $fi: $!\n";
	# Parse INQV to fill $hsh
	close(IN);
}

## Parse LoRDEC corrected reads to extract sequence structure
sub sieve {
	my $fi = shift;
	my %struct = ();
	my ($seqID,$seq) = ('','');

	open(COR, "<$fi") or die "Couldn't open LoRDEC corrected file $fi: $!\n";
	while (<COR>) {
		next if /^$/;
		chomp;
		if (/^>(.*)/) {
			my $tmp = $1;
print "\n$seqID:\n[$seq]\n" if $DEBUG==2;
			$struct{$seqID}{'seq'} = $seq;
			my $seqlen = length $seq;
			$totalBases += $seqlen;
			if ($seq =~ s/([ACGT]+)/_$1\_/g ) { 
				$seq =~ s/(^_)|(_$)//g;		## Get rid of possible heading or trailing '_'
			}
			else { $struct{$seqID}{'noModif'}++; }
			$struct{$seqID}{'struct'} = $seq;
print "struct:[$seq]\n" if $DEBUG==2;
			$seqID = $tmp;
			$seq = '';
		}
		else {
			$seq .= $_;
		}
	}
	$struct{$seqID}{'seq'} = $seq;
	my $seqlen = length $seq;
	$totalBases += $seqlen;
	if ($seq =~ s/([ACGT]+)/_$1\_/g ) { 
		$seq =~ s/(^_)|(_$)//g;		## Get rid of possible heading or trailing '_'
	}
	else { $struct{$seqID}{'noModif'}++; }
	$struct{$seqID}{'struct'} = $seq;
print "struct:[$seq]\n" if $DEBUG==2;

	delete $struct{''};
	close(COR);
	return %struct;
}

sub sum {
	my $sum = 0;
	foreach my $t (@_) { $sum += $t; }
	return $sum;
}

sub formatted_seq {
	my ($ouf, $sid, $h) = @_;
	my @c = ('','@','>');
	my $block = $c[$ouf]."$sid\n";
	$block .= $ouf == 1 ? $$h{'seq'}."\n+\n".$$h{'newQ'} : join(' ', fq2qual($$h{'newQ'}));
	return "$block\n";
}