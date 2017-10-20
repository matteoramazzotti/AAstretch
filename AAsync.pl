#! /usr/bin/perl -w
#      #############
#        AAsync
#      #############
#   (c) Matteo Ramazzotti
# matteo.ramazzotti@unifi.it
#
#@cods = qw /GCC AGT TGT CGA ATC AAC AGC TAC TCG ACA CCG CTG GCA AAG GTG CAC GTT AGA ACC CCA TGG CTC CGC TTG CAG ACG AAA ATG GTA CTT GGA GTC TGC TCA ATT TAT AAT ACT GAC CAA GGT TCC TTT AGG CGT ATA CGG CAT GGG CCC GAG TTA GAT CTA TCT TTC GCG GGC GAA GCT CCT TAA TAG TGA/;
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime time;

print STDERR "\n------ The AAstretch Project -------\n------------- AAsync ---------------\n---- PloS ONE 2012, 7(2):e30824 ----\n---- matteo.ramazzotti\@unifi.it ----\n--- Session ",sprintf("%02d",$mday),"-",sprintf("%02d",$mon+1),"-",$year+1900,"\t",sprintf("%02d",$hour+2),":",sprintf("%02d",$min),":",sprintf("%02d",$sec)," ---\n------------------------------------\n"  if (!$ARGV[0]);

print STDERR "\n------------- AAsync ------------\n(c) matteo.ramazzotti\@unifi.it 10\n\n" if (!$ARGV[0]);
@cods_lab = sort qw /A-GCC S-AGT C-TGT R-CGA I-ATC N-AAC S-AGC Y-TAC S-TCG T-ACA P-CCG L-CTG A-GCA K-AAG V-GTG H-CAC V-GTT R-AGA T-ACC P-CCA W-TGG L-CTC R-CGC L-TTG Q-CAG T-ACG K-AAA M-ATG V-GTA L-CTT G-GGA V-GTC C-TGC S-TCA I-ATT Y-TAT N-AAT T-ACT D-GAC Q-CAA G-GGT S-TCC F-TTT R-AGG R-CGT I-ATA R-CGG H-CAT G-GGG P-CCC E-GAG L-TTA D-GAT L-CTA S-TCT F-TTC A-GCG G-GGC E-GAA A-GCT P-CCT _-TAA _-TAG _-TGA/;
foreach (@cods_lab) {
	$cod = $_;
	$cod =~ s/.-//;
	push (@cods,$cod);
}

$seqfile = $ARGV[0];
$resfile = $ARGV[1];
$out5 = $resfile;
$out1 = 'stretches-cod.txt';
$out2 = 'flanks-cod.txt';
$out3 = 'left_flanks-cod.txt';
$out4 = 'right_flanks-cod.txt';
$out5 =~ s/\.txt/-cod.txt/;
open (OUT1,">$out1") or die "Cannot open $out1";
open (OUT2,">$out2") or die "Cannot open $out2";
open (OUT3,">$out3") or die "Cannot open $out3";
open (OUT4,">$out4") or die "Cannot open $out4";
open (OUT5,">$out5") or die "Cannot open $out5";

$| = 0;
print STDERR "\n\n> Synchronizing with codons < ";

&load_avail;
&load_seq;
&load_head;
&compute_globals;
#&build_new_head;
&write_new_head;
&write_new_data;
&write_new_fasta;

sub load_avail {
	print STDERR "\n";
	 $| = 1;
	if (-e "avail_seq.txt") {
		$/ = undef;
		open (FILE, "avail_seq.txt") or die "cannot open avail_seq.txt";
		$avail = <FILE>;
		close (FILE);
		@avail = split (/(?:\015{1,2}\012|\015|\012)/, $avail);
		$/ = "\n";
		$ava = 0;
		foreach (@avail) {
			$ava++;
			print STDERR "\r  Loading available protein $ava"; 
			chomp $_;
			$passed{$_} = 1;
		}
	} else {
		print "\n Something went wrong with AAstretch, cannot find the avail_seq.txt file\n";
		exit;
	}
}	

sub load_seq {
	print STDERR "\n";
	$| = 1;
	$/ = undef;
	open (FILE, "$seqfile") or die "cannot open $seqfile";
	$lines = <FILE>;
	close (FILE);
	@lines = split (/(?:\015{1,2}\012|\015|\012)/, $lines);
	$/ = "\n";
	$cnt = -1;
	$ign = 0;
	$acc = 0;
	$line = '';
	$| = 1;
	foreach $line (@lines) { #load coding sequences
		chomp $line;
		if ($line =~ />/) {
			$cnt++;
#			@tmp = split (/\t/,$line);
			@tmp = split (/\|go_fun\|/,$line);
			if ($passed{$line}) {
				$acc++;
				$name{$cnt} = $tmp[0]; # the name in AAsync is given with the cds code, not withthe cds code as in aastretch, but the annotation is the same
				$revname{$tmp[0]} = $cnt; #this is for getting the correct sequence when prot-out file is read
	#			$idname{$tmp[1]} = $cnt;
			} 
			else {
				$ign++;
				$name{$cnt} = 'dumb';
			}
		} else {
			$cseq{$cnt} .= $line;
		}
			print "\r  Loading sequence $cnt, $acc found, $ign ignored";
	}
}

sub load_head {
	$/ = undef;
	open (FILE, "$resfile") or die "cannot open $resfile";
	$lines = <FILE>;
	close (FILE);
	@lines = split (/(?:\015{1,2}\012|\015|\012)/, $lines);
	$/ = "\n";
	$tuple = 0;
	foreach $line (@lines) {
		chomp $line;
		if ($line =~ /residue/i) {
			$residue = $line;
			$residue =~ s/residue\t//i;
		}
		if ($line =~ /flank_length/i) {
			$flen = $line;
			$flen =~ s/flank_length\t//i;
		}
		if ($line =~ /flank_start/i) {
			$fst = $line; 
			$fst =~ s/flank_start\t//i;
		}
		if ($line =~ /global_stat/i) {
			$line =~ /global_stat_tup_(\d+)\t/i;
#			$tup = $1; 
#			$tuple = $1 if ($tup > $tuple);
			$tuple = 1; # in an ideal world the tuple counts for codons should function, but in real world, single codon analysis is used
		}
		if ($line =~ /Name\tLen/i) {
			$headline = $line;
		}
		last if ($line =~ /Name\tLen/);
	}
	@headline = split (/\t/,$headline);
	foreach(0..$#headline) {
		$start = $_ if ($headline[$_] eq 'start');
		$stop = $_ if ($headline[$_] eq 'stop');
		$lfseq = $_ if ($headline[$_] eq 'lf_seq');
		$rfseq = $_ if ($headline[$_] eq 'rf_seq');
#		$res_perc = $_ if ($headline[$_] eq $residue.'%');
		$stretches_tot = $_ if ($headline[$_] eq 'Stretches_tot');
		$name = $_ if ($headline[$_] eq 'Name');
		$pos_perc = $_ if ($headline[$_] eq 'Position%');
		$go_f = $_ if ($headline[$_] eq 'go_func');
		$go_p = $_ if ($headline[$_] eq 'go_proc');
		$go_c = $_ if ($headline[$_] eq 'go_comp');
		$mim = $_ if ($headline[$_] eq 'omim');
	}	

}

sub compute_globals {
	foreach (keys %name) {
		delete $cseq{$_} if ($name{$_} eq 'dumb'); #the dumb sequences are those discarded by filters of AAstretch, i.e. that are not present in avail_seq.txt
		delete $name{$_} if ($name{$_} eq 'dumb'); #the dumb sequences are those discarded by filters of AAstretch, i.e. that are not present in avail_seq.txt
	}
	print STDERR "\n  Computing globals on ",scalar keys %cseq," sequences";
	$full_for_glob = join "-", values %cseq;
	$global_stat = count_new($full_for_glob);
	undef $full_for_glob;
	$global_stat =~ s/ /\t/g; #this is a global variable
	my @glob_list = split (/\t/,$global_stat);
	$total_COD_count = 0;
	foreach my $stat (@glob_list) {
		$total_COD_count += $stat; #this is a global variable
	}
}

sub count_new {
	my $seq = shift;
	@seqs = split (/-/,$seq); #when globals are supplied, this is used to identify different coding sequences, in case of stretches etc only $seq[0] will be present
	undef %cod_cnt;
	$cnt_ = 0;
	$tlen = 0;
	foreach $cseq (@seqs) {
		$cnt_++;
		$tlen += length($cseq);
		while ($cseq =~ /(...)/g) {
			$cod_cnt{$1}++;
		}
	}
	my $list = '';
	my @list = ();
	foreach (@cods) { #an array is created to respect codon order
		push(@list, $cod_cnt{$_}) if ($cod_cnt{$_});
		push(@list, 0) if (!$cod_cnt{$_});
#		print "$_ -> $list[$#list]\n";
	}
	$list = join " ",@list;
#	<STDIN>;
	return ($list);
}


sub write_new_head {
#	$newhead = "Name\tLen\tStretches_tot\tStretch_seq\tStretch_len\tpure_cod\tpure_cod_len\tpure_homo\tstart\tstop\tPosition%\tlf_seq\trf_seq\tgo_func\tgo_proc\tgo_comp\tst_tup1\tlf_tup1\trf_tup1\tff_tup1\n";
	$newhead = "Name\tLen\tStretches_tot\tStretch_seq\tStretch_len\tpure_cod\tpure_cod_len\tpure_homo\tstart\tstop\tPosition%\tlf_seq\trf_seq\tgo_func\tgo_proc\tgo_comp\tomim\n";
	$/ = undef;
	open (FILE, "$resfile") or die "cannot open $resfile";
	$lines = <FILE>;
	close (FILE);
	@lines = split (/(?:\015{1,2}\012|\015|\012)/, $lines);
	$/ = "\n";
	foreach $line (@lines) {
		print OUT5 $line,"\n" if ($line !~ />/ && $line !~ /Global_stat/ && $line !~ /Name\tLen/ && $line !~ /Total AA count/);
		print OUT5 "Total COD count\t$total_COD_count\n" if ($line =~ /Total AA count/);
		print OUT5 "Global_stat_tup_1\t$global_stat\n" if ($line =~ /Global_stat_tup_1/);
		print OUT5 $newhead if ($line =~ /Name\tLen/);
		last if ($line =~ />/);
	}
}

sub write_new_data {
	print STDERR "\n";
	$| = 1;
	$cnt = 1;
	foreach $line (@lines) { #@lines is loaded in the write_new_head sub
		next if ($line !~ />/);
		print STDERR "\r  Extracting data from sequence $cnt";
		$cnt++;
		@tmp = split (/\t/,$line);
		$rname = $tmp[$name];
		$rpos_perc = $tmp[$pos_perc];
		undef @codons;
		while ($cseq{$revname{$rname}} =~ /(...)/g) {
			push @codons, $1;
		}
		$stretch = '';	$lflank = '';	$rflank = '';
		$sst = $tmp[$start]-1;
		$sen = $tmp[$stop]-1;
		$lfst = $sst-length($tmp[$lfseq])-$fst; # length instead of flen because some flank may be incomplete
		$lfen = $lfst+length($tmp[$lfseq])-1;
		$rfst = $sen+$fst+1;
		$rfen = $rfst+length($tmp[$rfseq])-1;
		undef %index;
		$old = 'X';
		$best = 0;
		for($i=$sst;$i<=$sen;$i++) {
			$stretch .= $codons[$i] if ($codons[$i]);
			$index{$codons[$i]}++ if ($codons[$i] eq $old);
			$index{$codons[$i]} = 1 if ($codons[$i] ne $old);
			if ($index{$codons[$i]} > $best) {
				$best_val = $index{$codons[$i]};
				$best_cod = $codons[$i];
				$best = $index{$codons[$i]};
			}
			$old = $codons[$i];
		}
		$homo = ($best_val/(length($stretch)/3))*100;
		for($i=$lfst;$i<=$lfen;$i++) {
			$lflank .= $codons[$i] if ($codons[$i]);
		}
		for($i=$rfst;$i<=$rfen;$i++) {
			$rflank .= $codons[$i] if ($codons[$i]);
		}
#		@tmp2 = split (/\|/,$rname);
#		$outname = $tmp2[3].'|'.$tmp2[5];
		print OUT1 $rname,"\n",$stretch,"\n";
		print OUT2 $rname,"\n",$lflank,"-",$rflank,"\n";
		print OUT3 $rname,"\n",$lflank,"\n";
		print OUT4 $rname,"\n",$rflank,"\n";
		print OUT5 $rname,"\t",length($cseq{$revname{$rname}}),"\t",$tmp[$stretches_tot],"\t",$stretch,"\t",length($stretch),"\t",$best_cod,"\t",$best_val,"\t",$homo,"\t",(($sst+1)*3-2),"\t",(($sen+1)*3),"\t",$rpos_perc,"\t",$lflank,"\t",$rflank,"\t",$tmp[$go_f],"\t",$tmp[$go_p],"\t",$tmp[$go_c],"\t",$tmp[$mim],"\n";
		@tmp_out = split (/\|/,$rname);
		push (@out_order,$tmp_out[1]) if (!$seq_out{$tmp_out[1]});
		$name_out{$tmp_out[1]} = $rname;
		$seq_out{$tmp_out[1]} = $cseq{$revname{$rname}};
		$todel{$tmp_out[1]} .= $lflank."&".$stretch."&".$rflank."\t";
	#		print OUT5 $st_count,"\t",$lf_count,"\t",$rf_count,"\t",$ff_count,"\n";
	}
}

sub write_new_fasta {
	print STDERR "\n";
	open (OUTSEQ,">sequences-cod.txt");
	open (OUTOUT,">outside-cod.txt");
	foreach (@out_order) {
		@tmp1 = split (/\t/,$todel{$_}); #this splits entries
		$seq = $seq_out{$_};
		foreach(@tmp1) {				
			@tmp2 = split (/\t/,$_);    # this splits flanks and stetches (new in sep 2010 revision, flanks may overlap now in AAstretch...) 
			foreach(@tmp2) {
				$seq =~ s/$_//; 		# and strip them from sequence
			}
		}
		print OUTSEQ $name_out{$_},"\n",$seq_out{$_},"\n";
		print OUTOUT $name_out{$_},"\n",$seq,"\n";
	}
	close OUTSEQ;
	close OUTOUT;
}
