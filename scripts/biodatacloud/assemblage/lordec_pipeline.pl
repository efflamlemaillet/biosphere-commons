#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use Cwd 'abs_path';

###########################
my $NAME = 'lordec_pipeline';
my $WHATIS = "
	This is a wrapper script for LoRDEC [Salmela & Rivals, 2014].
	It corrects Long Reads using Short Reads by pipelining the commands
	that (1) create a DeBruijn Graph of the SR, (2) correct the LR, and (3)
	adapt a fitted set of the input quality values to the corrected sequences.";
#-------------------
# 20/01/16:		First dev
# my $VERSION = '0.1';
# 27/01/16:		Added lordec_2_fastq step
# my $VERSION = '0.2';
# 02/02/16:		Optimised code using subs developed for initial pipeline
# my $VERSION = '0.3';
# 08/02/16:		Modified how available cores are taken into account
# my $VERSION = '1.0';
# 15/02/16:		Made resource evaluation with 'time' a CL option
# my $VERSION = '1.1';
# 24/02/16:		Added option to re-use existing DBG for lordec correction
#				Improved interface messenging and log handling
# my $VERSION = '1.2';
# 26/02/16:		Corrected bug in scheduler analyses (available cores)
my $VERSION = '1.2.2';
###########################

my $DEBUG = 0;
my $TIME_CMD = '/usr/bin/time';		# Which time command to use to measure job resources
my $LIB = '/ifb/mytools/lib';		# Path to library
my $JOIN_OE = 1;
my $BIGMEM = 8;
my $PBS_SCRATCH = '/scratch/em/tmpIO';
my ($K, $S) = (19, 3);
my %STX = (
	SGE => {
		submit 	=> 'qsub -S /bin/bash ',
		name 	=> '-N ',
		wd 		=> '-wd ',
		out 	=> '-o ',
		err 	=> '-e ',
		joe 	=> '-j y ',
		depend 	=> '-hold_jid ',
		array 	=> '-t 1-',
		jobid 	=> '$SGE_TASK_ID',
		# proc 	=> '-pe ',
		proc 	=> '-q ',	# Specifie la queue (ie l'hote) ou executer le job
		info 	=> "qstat -f | grep all.q | tr -s ' ' '\t' | cut -f3 | cut -d'/' -f3 | sort | uniq -c", # 'qstat -f | grep all.q | cut -d'/' -f3 | cut -d' ' -f1 | sort | uniq -c',
		# queue	=> 'qconf -sql',	# Toujours 'all.q' d'apres J. Lorenzo (Inge. IFB)
		# scratch => 'unset',
	},
	PBS => {
		submit 	=> 'qsub -S /bin/bash ',
		name 	=> '-N ',
		wd 		=> '-d ',
		out 	=> '-o ',
		err 	=> '-e ',
		joe 	=> '-j oe ',
		depend 	=> '-W depend=afterany:',
		array 	=> '-t 1-',
		jobid 	=> '$PBS_ARRAYID',
		proc 	=> '-l nodes=1:ppn=',
		info 	=> 'pbsnodes -a | grep np | sort | uniq -c',
		scratch => $PBS_SCRATCH,
	},
);

my ($illudir, $pbdir, $outdir, $dbg, $k, $s, $fasta, $occupy, $jobname, $script, $pid);
my $wait = 1;
my ($jSched, $timeit) = ('PBS', '');
my (@path, @subOpts);
my %operations = ();

my $cmdline = 'perl '.join(' ', ($0, @ARGV))."\n";
my $helpmsg = "(Try option '-help' for full description of tool usage)";
my @usage = (
	"$0 -short <DIR> -long <DIR> -out <DIR> [options]",
	"-short|sr DIR\t: Short reads directory.
	-long|lr DIR\t: Long reads directory.
	-output DIR\t: Output directory.
	-k INT\t\t: Kmer length to use in LoRDEC (Default = 19).
	-s INT\t\t: Solid kmer abundance threshold to use in LoRDEC (Default = 3).
	-dbg FILE\t: Don't create De Bruijn Graph anew, instead use existing FILE.
	-fasta\t\t: Keep initial Lordec fasta output (Default: remove).

	-submit JSCHED\t: Specify underlying job scheduler to use: PBS (Default) or SGE.
	-maxcores INT\t: Use at most INT cores in cluster (Default: use all available).

	-gauge\t\t: Measure resource usage (time, mem...) for each job (Default: don't).
	-help\t\t: Display this description and exit.
");

GetOptions(	"short|sr=s"	=> \$illudir,	# Illumina reads directory
			"long|lr=s"		=> \$pbdir,		# PacBio reads directory
			"output=s"		=> \$outdir,	# Output Directory
			"dbg=s"			=> \$dbg,		# Specify an existing DBG
			"k=i"			=> \$k,			# Kmer length to use for DBG creation and correction
			"s=i"			=> \$s,			# Solid kmer abundance threshold
			"fasta"			=> \$fasta,		# Keep original Lordec fasta files
			"maxcores=i"	=> \$occupy,		# Limit max core usage
			"submit=s"		=> sub { $jSched = uc($_[1]) },	# Underlying Distributed architecture
			"gauge"			=> sub { $timeit = $TIME_CMD },		# Keep original Lordec fasta files
			# -----------------------------------------------------------------------------------
			"help|?"		=> sub { exit print "\nDescription:$WHATIS\nVersion:\n\tv.$VERSION\nUsage:\n\t$usage[0]\nOptions:\n\t$usage[1]\n"; },		# Get tool description
			"version"		=> sub { exit print "\tThis is $NAME.pl v$VERSION\n"; },		
			"debug"			=> \$DEBUG,		# Debug option: scripts are created but not submitted
) or die "\t$helpmsg\n";

die "\n**MINIMUM USAGE**\n\t$usage[0]\n\n$helpmsg\n\n" unless (defined $illudir && defined $pbdir && defined $outdir);
die "\t(!) Unknown job scheduler \"$jSched\", only SGE or PBS supported\n" unless ($jSched eq 'SGE' || $jSched eq 'PBS');

unless (-d $outdir) { mkdir $outdir, 0775 or die "Couldn't create output directory $outdir: $!\n"; }
@path = split('/', $outdir);
$jobname = $path[$#path];
$outdir = abs_path($outdir);
my ($runfiles, $logs) = ("$outdir/runfiles", "$outdir/logs");
unless (-d $runfiles) { mkdir "$runfiles", 0775 or die "Couldn't create SGE scripts directory $runfiles: $!\n"; }
unless (-d $logs) { mkdir "$logs", 0775 or die "Couldn't create SGE logs directory $logs: $!\n"; }
my $runlog = "$logs/run_".time.'.log';
open(LOG, ">$runlog");
print LOG "$cmdline\n";

## =================================================================
## Identify cluster resources
## ---
## Get report depending on job scheduler and extract system info
my $report = `$STX{$jSched}{'info'}`;
my ($nodes, $cores, $minc, $maxc, $maxhostq, $bigmem) = (0,0,1000,0,'',1);
foreach my $line (split "\n", $report) {
	$line =~ /(\d+)\s+(\d+)/ if $jSched eq 'SGE';
	$line =~ /(\d+)\s+np \= (\d+)/ if $jSched eq 'PBS';
	$nodes += $1;
	$cores += $1*$2;
	$minc = $2 if $2 < $minc;
	$maxc = $2 if $2 > $maxc;
}
die "No nodes/cores detected, please check the job scheduler is indeed $jSched\n" if $nodes == 0;
print LOG  "Found $nodes nodes with $cores CPUs (min=$minc / max=$maxc";
if ($jSched eq 'SGE') {
	$maxhostq = `qstat -f | grep -P '\\d+/\\d+/$maxc' | cut -d' ' -f1`;
	chomp $maxhostq;
	print LOG " on queue $maxhostq)\n";
}
else {
	print LOG ")\n";
}
if (!defined $occupy) {
	print LOG "Using all available cores ($cores).\n";
	$occupy = $cores;

}
elsif ($occupy > $cores) {
	print LOG "#(!)#\tRequired cores ($occupy) is more than cluster holds, using what's available ($cores).\n";
	$occupy = $cores;
}
else {
	print LOG "Will try to optimise submissions to use at most $occupy cores.\n";
}
$bigmem = min($BIGMEM, $occupy, $maxc);
print LOG "Allowed to use $bigmem cores for bigmem jobs\n\n";


## =================================================================
if (defined $dbg) {
	die "Couldn't find DeBruijn Graph '$dbg', please check path...\n" unless (-e $dbg);
	die "Unknown format for DeBruijn Graph '$dbg', must be hdf5 ('<DBG>.h5')\n" unless $dbg =~ s/\.h5$//;
	unless (defined $k && defined $s) {
		$dbg =~ /.+_k(\d+)_s(\d+)/;
		die "Can't make out values of K and S from existing DBG:\n".
		"\tplease set them in command line using options '-k' and '-s'\n" unless (defined $1 && defined $2);
		($k, $s) = ($1, $2);
	}
	$wait = 0;
}
else {
## =================================================================
## Build DBG for LoRDEC
## ---
	## Produce list of illu files
	$k = defined $k ? $k : $K;
	$s = defined $s ? $s : $S;
	print LOG "Using k=$k and s=$s for DBG creation and correction\n\n";
	my $srf = "$runfiles/SRfiles.txt";
	open(IF, ">$srf") or die "Couldn't create short read list file SRfiles.txt in $runfiles: $!\n";
	my $path2illu = abs_path($illudir);
	my $atleast = 0;
	opendir(DIR, $illudir) or die "Couldn't read from directory $illudir: $!\n";
	foreach my $fq (sort readdir(DIR)) {
		next unless ($fq =~ /\.f(ast)?q$/);
		print IF "$path2illu/$fq\n";
		$atleast++;
	}
	close(IF);
	die "No valid short reads file (fastq) found in $illudir\n" unless ($atleast);
	## Prepare script operations
	@path = split('/', $illudir);
	my $illu = $path[$#path];
	$dbg = "$illu\_dbg_k$k\_s$s";
	%operations = (
		'mode'	=> 'single',
		"0_Creating DeBruijn Graph for illumina reads with k=$k and s=$s"
			=> "lordec-build-SR-graph -T $bigmem -2 $srf -k $k -s $s -g $outdir/$dbg.h5"		# => "sleep 5"
	);
	## Write batch script
	$script = "$runfiles/buildDBG_k$k\_s$s.sh";
	write_script($script, $jSched, %operations);
	## Submit script to cluster
	my $wd = $jSched eq 'SGE' ? $outdir : $STX{$jSched}{'scratch'};
	@subOpts = ("name=$jobname.buildDBG_k$k\_s$s","wd=$wd","out=$logs");
	push @subOpts, $jSched eq 'SGE' ? "proc=$maxhostq" : "proc=$BIGMEM";
	$pid = submit_2_cluster($script, $jSched, @subOpts);
## =================================================================
}

## =================================================================
## Correct PB Reads with lordec-correct
## ---
unless ($wait) {
	print LOG "Using k=$k and s=$s for correction\n\n";
}
## Produce list of input files to use for batch array task selection
my $taskindex = "$runfiles/LRfiles.txt";
open(INDEX, ">$taskindex") or die "Couldn't create long read list file $taskindex: $!\n";
my $path2pb = abs_path($pbdir);
my $npb = 0;
opendir(DIR, $pbdir) or die "Couldn't read from directory $pbdir: $!\n";
foreach my $fq (sort readdir(DIR)) {
	next unless ($fq =~ /\.f(ast)?q$/);
	print INDEX ++$npb."\t$path2pb/$fq\n";
}
close(INDEX);
die "No valid long reads file (fastq) found in $pbdir\n" unless ($npb);
## Prepare script operations
unless (-d "$outdir/corrLR") { mkdir "$outdir/corrLR", 0775 or die "Couldn't create Corrected Long Reads directory $outdir/corrLR: $!\n"; }
my $bestalloc = optimize($occupy, $npb, $minc);
%operations = (
	'mode'	=> 'array',
	"0_Correcting PB reads in \$INFILE using GDB $jobname/$dbg"
		=> "lordec-correct -i \$INFILE -2 $outdir/$dbg -k $k -s $s -o $outdir/corrLR/$STX{$jSched}{'jobid'}\\_corr.fasta -T $bestalloc",
	"1_Adding quality values to corrected reads"
		=> "perl $LIB/lordec_2_fastq.pl -corr $outdir/corrLR/$STX{$jSched}{'jobid'}\\_corr.fasta -init \$INFILE"
			.($fasta ? '' : "\nrm -f $outdir/corrLR/$STX{$jSched}{'jobid'}\\_corr.fasta")
);
## Write batch array script
$script = "$runfiles/lordec_k$k\_s$s.sh";
write_script($script, $jSched, %operations);
## Submit script to cluster
@subOpts = ("name=$jobname.lordec_k$k\_s$s","wd=$outdir","out=$logs","array=$npb");
push @subOpts, "depend=$pid" if $wait;
push @subOpts, "proc=$bestalloc" if $jSched eq 'PBS';
$pid = submit_2_cluster($script, $jSched, @subOpts);
## =================================================================

close(LOG);
print `cat $runlog`;


################
# SUB-ROUTINES #
################

## Actually write the scripts with prepared data
sub write_script {
	my $runf = shift;
	my $sys = shift;
	my (%cmds) = @_;
	open(SCRIPT, ">$runf") or die "Couldn't create $jSched script $runf: $!\n";
	## HEADER
	print SCRIPT "#!/bin/bash\n\necho 'Start Date:' `date`\n\n";
	print SCRIPT "module load lordec/0.5\n\n" if $sys eq 'PBS';
	if (delete $cmds{'mode'} eq 'array') {
		print SCRIPT "INFILE=`awk \"NR==$STX{$sys}{'jobid'}\" $taskindex | cut -f 2`\n";
	}
	## OPERATIONS
	foreach my $key (sort keys %cmds) {
		print SCRIPT make_nice($key, $cmds{$key});
	}
	## FOOT
	print SCRIPT "echo 'End Date:' `date`\n";
	close(SCRIPT);
}

## Decorate operation descriptions in script
sub make_nice {
	my ($desc, $op) = @_;
	my $nice = 'echo "'.('#' x 30).'"';
	$desc =~ s/^\d+_/echo \"/;
	return "\n$nice\n$desc: `date`\"\n$nice\n"
		."echo \"$op\"\n"
		.($timeit ? "$TIME_CMD " : '')."$op\n"
		."echo\n\n";
}

## Try infering the best ppn allocation depending on max limit and number of jobs:
## --> Choose N_cores_per_job (x) that optimises compute time estimation:
##		N_cycles necessary / Time_speedup
## with N_cycles necessary = round_above( N_jobs / N_slots_given_x)
##	and Time_speedup = x (linear approximation: each new core speeds up time by as much)
sub optimize {
	my ($usemax, $nj, $nodemax) = @_;
	## Less cores than jobs
	return 1 if $usemax / $nj < 1;
	## The highest whole divider is always the best bet 
	return $usemax / $nj if $usemax % $nj == 0;
	## With above estimator, the best result was near always held within ~1/4th of 
	## all available cores (empirically determined). Beyond, the estimator just cycled.
	## ==> Allow exploration threshold to include at least as many iterations (roundup($usemax/4))
	## unless node limit is inferior, then use that as limit.
	my ($p, $lim) = (-1, min($nodemax, roundup($usemax/4)));
	for (my ($i, $t) = (1, $nj); $i <= $lim; $i++) {
		my $tt = roundup(($nj / int($usemax / $i))) / $i;
# print "(i=$i / p=$p) t=$t, tt = ($nj / int($usemax / $i)) / $i = $tt\n";
		if ($tt < $t) { 
			$p = $i;
			$t = $tt;
		}
	}
	return $p; 
}

## Submit script to cluster
sub submit_2_cluster {
	my $runf =  shift;
	my $sys = shift;
	my $submit = $STX{$sys}{'submit'}.($JOIN_OE ? $STX{$sys}{'joe'} : '');
	foreach my $arg (@_) {
		$arg =~ /(.*)\=(.*)/;
		$submit .= "$STX{$sys}{$1}$2 ";
	}
	print LOG "$submit $runf\n\n";
	my $job;
	if ($DEBUG) {
		if ($sys eq 'SGE') { $job = "Your job ".random_number(2)." (\"<jobname>\") has been submitted"; }
		elsif ($sys eq 'PBS') { $job = random_number(5).'.nodename'; }
	}
	else {
		$job = `$submit $runf`;
		chomp $job;
	}
	print LOG "$job\n\n";
	if ($sys eq 'SGE') {
		$job =~ /Your job (\d+) \(/i;
		$job = $1;
	}
	return $job;
}

sub random_number {
	my $len = shift;
	return join '', map int(rand(10)), 1..$len;
}

sub roundup {
	return int($_[0] + 0.999999999);
}

sub min {
	my $mi = 1000000;
	foreach my $n (@_) {
		$mi = $n if $n < $mi;
	}
	return $mi;
}
