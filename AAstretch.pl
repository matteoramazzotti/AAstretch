#! /usr/bin/perl -w
#        #############
#          AAstretch
#        #############
# (c) Matteo Ramazzotti 2017
# matteo.ramazzotti@unifi.it
#
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime time;
$short_debug = 0; #if set to 1, no only the 10 fisrt records are printed, just for debug (produces errors...)
$in1 = $ARGV[0];
$in2 = $ARGV[1];
&prog_check;
@res = ('G','P','D','E','R','K','V','I','L','M','A','W','Y','F','S','T','H','C','N','Q');
ASK:
print STDERR "\n------ The AAstretch Project -------\n------------ AAstretch -------------\n---- PloS ONE 2012, 7(2):e30824 ----\n---- matteo.ramazzotti\@unifi.it ----\n--- Session ",sprintf("%02d",$mday),"-",sprintf("%02d",$mon+1),"-",$year+1900,"\t",sprintf("%02d",$hour+2),":",sprintf("%02d",$min),":",sprintf("%02d",$sec)," ---\n------------------------------------\n" if (!$in1);

if (!$in1) {
	print STDERR "\n"; 
	print STDERR "   1. Run\n"; 
	print STDERR "   2. Restart\n"; 
	print STDERR "   3. Clean\n"; 
	print STDERR "   4. Isolate\n";
	print STDERR "   5. Help\n";
	print STDERR "   6. Quit\n\n";
	print STDERR "   Select: ";
	$what = <STDIN>;
	chomp $what;
	$prog = 'run' if (!$what || $what == 1); 
	$prog = 'restart' if ($what && $what == 2); 
	$prog = 'clean' if ($what && $what == 3); 
	$prog = 'isolate' if ($what && $what == 4); 
	$prog = 'help' if ($what && $what == 5);
	$prog = 'quit' if ($what && $what == 6);
	goto ASK if (!$prog);
} else {
	$prog = lc($in1);
	undef ($in1);
	undef ($in2);
}

#######   SWITCH AND CONTROL SECTION ##########

if ($prog eq 'help') {
	&help; exit;
} 
if ($prog eq 'restart') {
	&clean; &extract; shift @ARGV; goto ASK;
}
if ($prog eq 'clean') {
	&clean; shift @ARGV; goto ASK;
}
if ($prog eq 'isolate') {
	&isolate; shift @ARGV; goto ASK;
}
if ($prog eq 'quit') {
	exit;
}
 #######   WORKFLOW CONTROL ##########

&loadconf;
&prog_check;
&load_data if ($v{'scan'} == 1 && !@name);
&scan_data if ($v{'scan'} == 1);
&write_results if ($v{'scan'} == 1);
&fasta_output if ($v{'scan'} == 1);
&sync if ($v{'sync'} == 1);
&explore if ($v{'explore'} == 1);

#plot_all('a') if ($v{'plot_aacids'} == 1);

#plot_all('c') if ($v{'plot_codons'} == 1);

goto ASK;

 #######   SUBROUTINE SECTION ##########

sub prog_check {
#	@pro = qw /AAstretch AAexplore AAsync/;
	@pro = qw /AAexplore AAsync/;
	@mod = qw /.pl .exe/;
	# CHECK FOR THE PRESENCE OF PROGRAMS IN PATH
	@paths = split (/[:|;]/,$ENV{'PATH'});
	foreach $pro (@pro) {
		foreach $mod (@mod) {
			foreach $path (@paths) {
				$path =~ s/\/$//;
				$full = $path."\/".$pro.$mod;
				$launch{$pro} = $pro.$mod if (-e $full);
#			print $full;
#			print "   <-----------" if (-e $full);
#			print "\n";
			}
			$full = $pro.$mod;
			$launch{$pro} = "perl $pro".$mod if (!$launch{$pro} && -e $full && $mod eq '.pl');
			$launch{$pro} = "$pro".$mod if (!$launch{$pro} && -e $full && $mod eq '.exe');
#			print $full;
#			print "   <-----------" if (-e $full);
#			print "\n";
		}
	}
	$err = 0;
	foreach (@pro) {
		if ($launch{$_}) {
			$launch{$_} = "./".$launch{$_} if ($^O !~ /win/i && $launch{$_} =~ /exe/);
		}
		 else {
			print "ERROR: $_ not found on your system !\n";
			$err = 1;
		}
	}
#	print "AAexplore  is at ", $launch{'AAexplore'},"\n";
#	print "AAsync is at ", $launch{'AAsync'},"\n";
	<STDIN> if ($err == 1);
	goto ASK if ($err == 1);
}

sub loadconf {
	print STDERR "\n> AAstretch.conf file not found <\n" if (!-e 'AAstretch.conf');
	goto ASK if (!-e 'AAstretch.conf');
	$/ = undef;
	open (FILE, "AAstretch.conf");
	$conf = <FILE>;
	close (FILE);
	@con = split (/(?:\015{1,2}\012|\015|\012)/, $conf);
	$/ = "\n";
	undef %v;
	foreach $line (@con) {
		next if ($line =~ /#/ || $line !~ /\w/);
		$line =~ s/ //g;
		chomp $line;
		@tmp = split (/=/,$line);
		$v{lc($tmp[0])} = $tmp[1];
	}
	$protfile = '';	
	$protfile = $v{'data_source'} if ($v{'data_source'});
	$protfile = $ARGV[1] if ($ARGV[1]);
	$codfile = $protfile ;
	$codfile =~ s/\.prot/.cod/;
	$outfile = $protfile;
	$outfile =~ s/\.txt/-AAstretch.txt/;
	open (LOG,">log.txt") if ($v{'verbose'} == 1);
}

sub load_data { ## rev 29-10-09: blank lines and comments (^#) are skipped
	print STDERR "\n> Loading data <\n ";
	print STDERR "Input file $protfile not found\n" if (!-e $protfile);
	goto ASK  if (!-e $protfile);
	#universal line splitting system, tested on linux, mac (> osX) and windows.
	$/ = undef;
	open (FILE, "$protfile");
	$lines = <FILE>;
	close (FILE);
	@lines = split (/(?:\015{1,2}\012|\015|\012)/, $lines);
	$/ = "\n";
	$y = -1;
	foreach (@lines) {
		chomp $_;
		next if ($_ !~ /\w/ || $_ =~ /^#/); 
		$y++ if ($_ =~ />/);
		$y2 = $y+1 if ($_ =~ />/);
		print STDERR "\r  Loading sequence $y2"  if ($_ =~ />/);
		$name[$y] = $_ if ($_ =~ />/);
		$seq[$y] .= uc($_) if ($_ !~ />/);
	}
	#print STDERR " ",scalar(@seq)," sequence/s loaded.";
	#print STDERR "Name","\t","Stretches","\t","start.stop","\t","left-flanks","right-flanks","\n";
	foreach(0..$#seq)  {
		$checkname{$seq[$_]} .= $name[$_] . " @@@ "; 
	}
#	print "CHECK: ",scalar keys %checkname,"\n\n";
	foreach (keys %checkname) {
		@tmp = split(/ @@@ /, $checkname{$_});
#		print "\n----------------------\n";
		undef $name_ok;
		foreach (@tmp) {
#			print "---> ",$_,"\n";
			$name_ok = $_ if ($_ =~ /GO:/ || $_ =~ /MIM:/);
		}
		$name_ok = $tmp[0] if (!$name_ok);
		push (@newseq, $_);
		push (@newname, $name_ok);
#		print "$checkname{$_} -> $name_ok" if (scalar @tmp > 1);
#		<> if (scalar @tmp > 1);
	}	
	@name = @newname;
	@seq = @newseq;
	print STDERR ", ". scalar @seq , " unique sequences.\n"; 
	if ($v{'isoform_check'} =~ /on/i) {
		&create_isoforms if (!-e "$protfile.isoforms.txt");
		&load_isoforms;
	}
}

sub load_isoforms {
	print STDERR "\n> Loading isoform data <\n ";
	$/ = undef;
	open (ISO, "$protfile.isoforms.txt");
	$lines = <ISO>;
	close ISO;
	@lines = split (/(?:\015{1,2}\012|\015|\012)/, $lines);
	$/ = "\n";
	my $st = -1;
	my $cnt = 0;
	foreach (@lines) {
		next if ($_ !~ /\w/);
		chomp $_;
		if ($_ =~ /^-- /) {
			@tmp = split (/ @@@ /, $_);
			$lab = $tmp[0];
			$ann = $tmp[1];
			$st++;
			print STDERR "\r  Loading isoforms: $cnt variants for $st proteins";
		}
		if ($_ =~ />/) {
			$isoform{$_} = $lab;
#			$ann_isoform{$_} = $ann;
#			print "$isoform{$_} ()is a $ann_isoform{$_}";
#			<>;
			$cnt++;
		}
	}
}

sub create_isoforms {
	print STDERR "\n> Creating isoform data <\n ";
	open (ISO, ">$protfile.isoforms.txt");
#	print STDERR "\n> Purging isoforms <\n ";
	my $ison = 0;
	my $iso_tot = 0;
	my %iso;
	my %isoforms;
	my %passed;
	foreach $index (0..$#name) {
		print STDERR "\r  Gathered $ison isoforms in $iso_tot proteins over $index"  if ($name[$index] =~ />/);
		@tmp = split (/\|/,$name[$index]);
		$passed{$tmp[5]} = 1; #tmp[5] is the gene name
		if ($passed{$tmp[5]}) { #if passed the gene has a splicing variant
			$ann = join "|",($tmp[6],$tmp[7],$tmp[8],$tmp[9],$tmp[10],$tmp[11],$tmp[12],$tmp[13],$tmp[14],$tmp[15]);
#			$tmp[5] =~ s/ isoform (\w+)//;
			$iso{$tmp[5]} .= $index.":".$tmp[1]."|";
			$iso_ann{$tmp[5]} = $ann if ($ann =~ /GO:/);
			$iso_ann{$tmp[5]} = $ann if ($tmp[15] !~ /---/);
			$isonum{$tmp[5]}++;
			$isoforms{$tmp[5]} = $iso{$tmp[5]} if ($isonum{$tmp[5]} > 1);
			$ison++ if ($isonum{$tmp[5]} > 1);
			$iso_tot = scalar keys %isoforms;
		}
	}
	print STDERR "\n\n";
	foreach(keys %isoforms) {
		if ($isonum{$_} > 1) {
			print ISO "\n\n-- $_ @@@ $iso_ann{$_}\n\n" if ($iso_ann{$_});
			print ISO "\n\n-- $_ @@@ ann|---|go_fun|---|go_pro|---|go_com|---|omim|---\n\n" if (!$iso_ann{$_});
			@tmp = split (/\|/,$iso{$_});
			foreach(@tmp) {
				@tmp1 = split (/:/,$_);
#				print ISO ">$tmp1[1]|$name[$tmp1[0]]\n$seq[$tmp1[0]]\n";
				print ISO "$name[$tmp1[0]]\n";
			}
		}
	}
	close ISO;
}

sub scan_data {
	open (AVAILOUT, ">avail_seq.txt");
	print STDERR "\n\n> Scanning sequences <\n ";
	my @tup_head = ();
	$full_for_glob = '';
	foreach $tuple (1..$v{'tuple'}) {
		push  @tup_head, 'tup'.$tuple;
	}
	$l_flank_desc = '';
	$l_flank_desc = "lf_poly_res\tlf_poly_len\tlf_poly_dist\t" if ($v{'tuple'} > 1);
	$r_flank_desc = '';
	$r_flank_desc = "rf_poly_res\trf_poly_len\trf_poly_dist\t" if ($v{'tuple'} > 1);
	$out = "Name"."\t"."Len"."\t"."Stretches_tot"."\t"."Stretch_seq"."\t"."Stretch_len"."\t".$v{'residue'}."%"."\t"."pure".$v{'residue'}."_len"."\t"."pure".$v{'residue'}."_ratio"."\t"."start"."\t"."stop"."\t"."Position%"."\t"."lf_seq"."\t".$l_flank_desc."rf_seq"."\t".$r_flank_desc."go_func"."\t"."go_proc"."\t"."go_comp"."\t"."omim"."\n";
	$| = 1;
	my $tot = 0;
	my $ignored = 0;
	my $avail = 0;
	$total_AA_count = 0;
	$m1st = 0;
	undef %avail;
	undef %result_iso;
	%todel = ();
	%toprint = ();
	%seq_out = ();
	%cod_out = ();
	%st_out = ();
	%lf_out = ();
	%rf_out = ();
	%ff_out = ();
	foreach $count (0..$#seq) {
		$count_ind = $count+1;
		print STDERR "\r  Scanning sequence $count_ind: $tot stretches in $avail proteins found ($ignored ignored)" if ($v{'ignore'} || $v{'only'});
		print STDERR "\r  Scanning sequence $count_ind: $tot stretches in $avail proteins found " if (!$v{'ignore'} && !$v{'only'});
		@name_tmp = split (/\|/, $name[$count]);
		if ($v{'ignore'} && $name_tmp[7] =~ /$v{'ignore'}/i) {
			$ignored++;
#			print STDERR "\r  Ignoring sequence $count -> $name[$count]";
			next;
		}
		if ($v{'only'} && $name_tmp[7] !~ /$v{'only'}/i) {
			$ignored++;
#			print STDERR "\r  Ignoring sequence $count";
			next;
		}
		$cnt = 0;
		$m1st++ if ($seq[$count] =~ /^M/);
		$full_for_glob .= $seq[$count]."-";
		$total_AA_count += length($seq[$count]);
#		print $name[$count],"\t",length($seq[$count]),"\n";
		print AVAILOUT $name[$count],"\n"; #this passes scanned sequences name to AAsync (if used) through a file
		($stretch,$cnt,$pos,$flankl,$flankr) = polyAAfind($seq[$count],$name[$count]); #polyQfind returns stretches, flankl and flankr separated by a minus sign in order to maintain the positioninig on the sequence
# NEW: CHECK FOR ISOFORMS, %isoform store isoform labels for each entry, if the same label is found snd the position of stretches is the same, this means that an isoform, gave identical resylts, so it must be skipped...
#		undef $pos;
		next if ($cnt  == 0);
		print "\n------------\n$name[$count]\nCNT: $cnt\nST: $stretch\nLF: $flankl\nRF: $flankr\nPO: $pos\n------\n" if ($v{'verbose'} == 1);
		 <STDIN> if ($v{'verbose'} == 1);
		@st = split (/-/, $stretch);
		@lf = split (/-/, $flankl);
		@rf = split (/-/, $flankr);
		@pos = split (/-/, $pos);
		foreach my $ind (0..$#st) {
			goto ISO_SKIP if ($v{'isoform_check'} !~ /on/i); # see the conf file, if isoform_check is off, this section is akipped 
			if ($isoform{$name[$count]}) {
				$key = $st[$ind].$lf[$ind].$rf[$ind]; #pos would be better, but is a very labile key, joining stretch and flanks is a much more stringent...
				#print "$name[$count] \n has isoforms \n $isoform{$name[$count]} \n 
				next if ($result_iso{$isoform{$name[$count]}} && $result_iso{$isoform{$name[$count]}} =~ $key);
				$result_iso{$isoform{$name[$count]}} .= $key." ";
			}
			ISO_SKIP:
			$avail{$name[$count]} = 1;
			$avail = scalar keys %avail;
			print "\n\n-*-*- AVAIL -*-*-\n",join "\n",keys %avail,"\n-*-*----------*-*-\n\n" if ($v{'verbose'} == 1);
			$tot++; #this counts the number of stretches
			($pos_st,$pos_en) = split (/\./,$pos[$ind]);
			$position = int($pos_st/length($seq[$count])*100);
			(undef,$res_perc) = count_new($st[$ind],$name[$count],'st');
			$res_perc = $res_perc/length($st[$ind])*100;
			($lf_AA,undef) = count_new($lf[$ind],$name[$count],'lf');
			($rf_AA,undef) = count_new($rf[$ind],$name[$count],'rf');
#			($ff_AA,undef) = count_new($lf[$ind]."-".$rf[$ind]);
			
			$poly_max_len = 0;
			while ($st[$ind] =~/($v{'residue'}+)/g) {
				$poly_max_len = length ($1) if (length ($1) > $poly_max_len);
			}
			$poly_max_ratio = $poly_max_len/length($st[$ind]);
			
			$lf_poly_desc = '';
			$rf_poly_desc = '';
			$lf_poly_desc = flank_anal($lf_AA,"L",$lf[$ind]) if ($v{'tuple'} > 1);
			$rf_poly_desc = flank_anal($rf_AA,"R",$rf[$ind]) if ($v{'tuple'} > 1);

			@name_out = split (/\|/, $name[$count]);
			@name_out2 = split (/\|go_fun\|/, $name[$count]);
			$toprint{$name_out[1]} = 1;
			$todel{$name_out[1]} .= $lf[$ind].$st[$ind].$rf[$ind]."\t";
			$seq_out{$name_out[1]} = $seq[$count];
			$cod_out{$name_out[1]} = $name_out2[0];
			$st_out{$name_out[1]} .= $st[$ind];
			$lf_out{$name_out[1]} .= $lf[$ind];
			$rf_out{$name_out[1]} .= $rf[$ind];
			$ff_out{$name_out[1]} .= $lf[$ind].$lf[$ind];

#			if (!$isoform{$name[$count]}) {
				$out .= $name_out2[0]."\t".length($seq[$count])."\t".($#st+1)."\t".$st[$ind]."\t".length($st[$ind])."\t".$res_perc."\t".$poly_max_len."\t".$poly_max_ratio."\t".$pos_st."\t".$pos_en."\t".$position."\t".$lf[$ind].$lf_poly_desc."\t".$rf[$ind].$rf_poly_desc."\t".$name_out[9]."\t".$name_out[11]."\t".$name_out[13]."\t".$name_out[15]."\n";
#			} else {
#				@tmp = split (/\|/,$ann_isoform{$name[$count]});
#				$out .= $name_out2[0]."\t".length($seq[$count])."\t".($#st+1)."\t".$st[$ind]."\t".length($st[$ind])."\t".$res_perc."\t".$poly_max_len."\t".$poly_max_ratio."\t".$pos_st."\t".$pos_en."\t".$position."\t".$lf[$ind].$lf_poly_desc."\t".$rf[$ind].$rf_poly_desc."\t".$tmp[3]."\t".$tmp[5]."\t".$tmp[7]."\t".$tmp[9]."\n";
#			}
		}
		return if ($tot > 10 && $short_debug); 
	}
	$available_seq = $#seq+1-$ignored;
	$total_stretch_count = $tot;
	close LOG if ($v{'verbose'} == 1);
	close AVAILOUT;
}

sub fasta_output {
	print STDERR "\n> Writing fasta files <";
	open(SEQOUT, ">sequences.txt");
	open(OOUT, ">outside.txt");
	open(SOUT, ">stretches.txt");
	open(LFOUT, ">left_flanks.txt");
	open(RFOUT, ">right_flanks.txt");
	open(FFOUT, ">both_flanks.txt");

	foreach (keys %toprint) {
		@tmp = split (/\t/,$todel{$_});
		$seq = $seq_out{$_};
		foreach(@tmp) {
			$seq =~ s/$_//; #this creates a temporray sequence deprived of strateches and flanks, useful for sttistical analyses
		}
		print SEQOUT "$cod_out{$_}\n$seq_out{$_}\n";
		print OOUT "$cod_out{$_}\n$seq\n";
		print SOUT "$cod_out{$_}\n$st_out{$_}\n";
		print LFOUT "$cod_out{$_}\n$lf_out{$_}\n";
		print RFOUT "$cod_out{$_}\n$rf_out{$_}\n";
		print FFOUT "$cod_out{$_}\n$ff_out{$_}\n";
	}		#	print STDERR $name[$count],"\t",$cnt,"\t",$stretch,"\t",$pos,"\t",$flankl,"\t",$flankr,"\n";
	close SEQOUT;
	close OOUT;
	close SOUT;
	close LFOUT;
	close RFOUT;
	close FFOUT;
}

sub flank_anal { #added 20-5-2010
#	print "\n> FLank analysis <\n";
	my $count = shift; #the strings with counts as returned by count_new sub
	my $dir = shift; #L or R, calculations of flank distance is different
	my $seq = shift; #the flank sequence
	my $dist;
	my @tmp1 = split (/\t/,$count);
	my %highest = ();
	my $true_tup = '';
	my $flank = '';
	shift @tmp1; #the tuple 1 is uninformative...
	foreach my $counts (0..$#tmp1) { #the tuple 1 is not interesting...
		$true_tup = $counts+2;
#		print $tmp1[$counts],"\n";
		my @tmp2 = split (/ /,$tmp1[$counts]);
		foreach my $res (0..$#res) {
			$highest{$res[$res].'@'.$true_tup} = $tmp2[$res]*$true_tup; # this is used to prefer longer tuples 
#			print "$res[$res] @ ",$true_tup," = ",$highest{$res[$res].'@'.$true_tup},"\n";
		}
	}
	my @sorted = sort {$highest{$b} <=> $highest{$a}} keys %highest;
	return ("\t-\t-\t-") if ($highest{$sorted[0]} == 0); # the most tupled residue, the tuple length and its distance from the stetch...maybe
#	print "-------------\nSEQ: $seq\nRES   : ",join " ",@res,"\t",join " ",@res,"\nCOUNTS: ",join "\t",@tmp1,"\nDIR: $dir\n------------\n";
#	print "1st $sorted[0] ",$highest{$sorted[0]}," -> last $sorted[$#sorted] ",$highest{$sorted[1]},"\n";
	my @res = split (/@/,$sorted[0]);
	$flank = $res[0] x $res[1];
	$seq =~ /$flank/;
	my $st = $-[0];
	$dist = $st+$v{'flank_start'} if ($dir eq 'R'); # this is just the 1st position, must take into account L or R and fdist 
	$dist = $v{'flank_length'}-$res[1]-$st+$v{'flank_start'} if ($dir eq 'L'); # this is just the 1st position, must take into account L or R and fdist 
#	print "SEQ: $seq\nAA: $res[0]\tRES: $res[1] ($flank) \tDIST: $dist\nPOS: $st\n";
#	print "FL: $v{'flank_length'}\n";
#	print "FS: $v{'flank_start'}\n";
#	<STDIN>;
	return ("\t$res[0]\t$res[1]\t$dist"); # the most tupled residue, the tuple length and its distance from the stetch...maybe
}

sub count { # useless, the count_new is better since can catch singletons, couplets triplets and so on 
	my $seq = shift;
	$seq =~ s/ //g;
#	$seq =~ s/-//g;
	my $num;
	my $list = '';
	my $res = '';
	foreach $search (@res) {
		$num = $seq =~ s/$search/$search/g;
		$num = 0 if (!$num);
		$list .= $num." ";
		$res = $num if ($search eq $v{'residue'});
	}
	return $list,$res;
}

sub count_new { # added 03-05-2010
	my $seq = shift;
	my $name = shift;
	my $who = shift;
	my $do = shift;
#	print "$who -> $name\n" if ($seq !~ /\w/);
#	<STDIN> if ($seq !~ /\w/);
	$seq =~ s/ //g;
	
#	$seq =~ s/-//g;
	my $num;
	my $res = '';
	my $list = '';
	my @list = ();
	foreach $tuple (1..$v{'tuple'}) { #this should allow the count procedure to cope for couplets, triplets and so on
		foreach $search (@res) {
			$num = 0;
			$key = $search;
			$key .= '+' if ($tuple > 1);
			print $seq,"\n" if ($do);
			while ($seq =~ /($key)/g) {
				$num++ if (length($1) == $tuple);
				print $1 if ($do);
				<STDIN> if ($do);
			}	
			$num = 0 if (!$num);
			$list .= $num." ";
			$res = $num if ($search eq $v{'residue'} && $tuple == 1);
		}
		$list .= "\t";
	}
	shift @list;
	return ($list,$res);  
}


sub isolate {
	my @all = ();
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime time;
	$mon++;
	$year += 1900;
	#this way the log file name will be YYYYMMDD-HHMMSS-log.txt
	$dir = $year.".".sprintf("%02d",$mon).".".sprintf("%02d",$mday)."-".sprintf("%02d",$hour).sprintf("%02d",$min).sprintf("%02d",$sec);
	mkdir $dir;
	print STDERR "   Moving files in folder $dir...";
	opendir (DIR,".");
	foreach (readdir DIR) {
		push (@all, $_) if ($_ =~ /-AAstretch/);
		push (@all, $_) if ($_ =~ /stretches/);
		push (@all, $_) if ($_ =~ /flanks/);
		push (@all, $_) if ($_ =~ /avail/);
		push (@all, $_) if ($_ =~ /summary/);
		push (@all, $_) if ($_ =~ /gaps/);
		push (@all, $_) if ($_ =~ /sequences/);
		push (@all, $_) if ($_ =~ /outside/);
	}
	foreach $file (@all) {
		next if (!-e $file);
		$out = $dir.'/'.$file;
		rename $file, $out;
	}
	open (IN,"AAstretch.conf");
	open (OUT,">$dir/AAstretch.conf");
	while (<IN>) {print OUT $_;}
	close IN;
	close OUT;
#		unlink $file;
	print STDERR "done.\n";
}


sub clean {
	my @all = ();
	print STDERR "\n   Cleaning the folder...";
	opendir (DIR,".");
	foreach (readdir DIR) {
		push (@all, $_) if ($_ =~ /-AAstretch/);
		push (@all, $_) if ($_ =~ /stretches/);
		push (@all, $_) if ($_ =~ /flanks/);
		push (@all, $_) if ($_ =~ /avail/);
		push (@all, $_) if ($_ =~ /summary/);
		push (@all, $_) if ($_ =~ /gaps/);
		push (@all, $_) if ($_ =~ /sequences/);
		push (@all, $_) if ($_ =~ /outside/);
	}
	foreach (@all) {
		unlink $_;
	}
	closedir DIR;
	print STDERR "done.\n";
}

sub extract {
	print STDERR "   Recreating the start environment...";
	require Archive::Zip;
	$zip = Archive::Zip->new();
	$zip->read("data.zip");
	$zip->extractMember( 'prot.txt' );
	$zip->extractMember( 'cod.txt' );
	$zip->extractMember( 'isoforms.txt' );
	print STDERR "done\n";
}

sub sync {
#	print STDERR "\n\n> Synchronizing with codons <\n ";
	$prog = $launch{'AAsync'};
	system "$prog $codfile $outfile";
}

sub explore {	
	print STDERR "\n\n> Exploring results <\n ";
	$prog = $launch{'AAexplore'};
	system "$prog $outfile" 
}

sub polyAAfind { #catches polyAA stretches as defined by input parameters and returns 4 strings containing, separated by a "-" the stretches, their position, the left flanks and the right flanks 
	my $seq = shift;
	my $name = shift;
	my $stretch = '';
	my $flankl = '';
	my $flankr = '';
	my $pos = '';
	my $match;
	my $cnt = 0;
	print LOG "\n  ----   $name  -----\n" if ($v{'verbose'} == 1);
#	print "\n  ----   $name  -----\n"  if ($v{'verbose'} == 1);

	# the patt engine ###########################################################################
	if ($v{'scanmode'} eq 'patt') {
		$matchseq = "(:?$v{'residue'}\{$v{'patt_extrem_len'},})(:?.{$v{'patt_gap_min_size'},$v{'patt_gap_max_size'}})(:?$v{'residue'}\{$v{'patt_extrem_len'},})(:?(:?.{$v{'patt_gap_min_size'},$v{'patt_gap_max_size'}})(:?$v{'residue'}\{$v{'patt_extrem_len'},})){0,$v{'patt_gap_max_number'}}";
		while ($seq =~ m/($matchseq)/gc) { # this (:?$v{'residue'}) solves the problem of missing variable interpolation...but dunno why...
			$match = $1;
			$matchlength = length($match);
			$AAcnt = $match =~ s/$v{'residue'}/$v{'residue'}/g;
			$match_perc = $AAcnt/$matchlength*100;
			print LOG "\n    at ",(pos($seq)-$matchlength+1)," $match of $matchlength residues: " if ($v{'verbose'} == 1);
			if ($matchlength<$v{'patt_stretch_min_size'} || $matchlength>$v{'patt_stretch_max_size'}) { #  match discarded due to small or large size
				print LOG " error in size." if ($v{'verbose'} == 1);
				next;
			} elsif
			($match_perc < $v{'patt_stretch_min_aa_perc'}) { #  match discarded due to a poor $v{'residue'} aminoacid percentage
				$back = pos($seq)-$matchlength+1;
	#			substr($seq,pos($seq)-1,1,'@');
				print LOG "<" ,$v{'patt_stretch_min_aa_perc'},", error in %  and pos moved to ",($back+1) if ($v{'verbose'} == 1);
				pos($seq) = $back;
				next;
			} else {
				print "\n     Valid match at ",(pos($seq)-$matchlength+1),": $match ( length $matchlength, perc $match_perc )" if ($v{'verbose'} == 1);
				print LOG "OK !!!" if ($v{'verbose'} == 1);
			}
			$cnt++;
			$lst = pos($seq)-$matchlength-$v{'flank_start'}-$v{'flank_length'};
			$llen = $v{'flank_length'};
			$llen += $lst if ($lst < 0);
			$lst = 0 if ($lst < 0);
			$t_flankl = '';
			$t_flankl = substr ($seq,$lst,$llen);
			$flankl .= $t_flankl."-" if (length($t_flankl) > 0);
			$flankl .= "*-" if (length($t_flankl) == 0);
			$rst = pos($seq)+$v{'flank_start'};
			$t_flankr = '';
			$t_flankr .= substr ($seq,$rst,$v{'flank_length'});
			$flankr .= $t_flankr."-" if (length($t_flankr) > 0);
			$flankr .= "*-" if (length($t_flankr) == 0);
			$stretch .= $match."-";
			$pos .= (pos($seq)-$matchlength+1).".".pos($seq)."-";
			#comment the following lines if not in debug
	#		$flankltmp = substr ($seq,$lst,$v{'flank_length'}) if ($lst >= 1);
	#		$flankltmp = "*" if ($lst < 1);
	#		$flankrtmp = substr ($seq,$rst,$v{'flank_length'}) if ($rst+$v{'flank_length'} <= length($seq));
	#		$flankrtmp = "*" if ($rst+$v{'flank_length'} > length($seq));
	#		print STDERR "$flankltmp - ",(pos($seq)-length($1)+1)," - ",$1," - ",pos($seq)," - $flankrtmp\n";
		}
	}
	# the seed engine ###########################################################################
	if ($v{'scanmode'} eq 'seed') {
		$matchseq = "$v{'residue'}\{$v{'seed_seed_min_size'},$v{'seed_seed_max_size'}}";
		undef @stretch;
		undef @flankl;
		undef @flankr;
		undef @pos;
		undef @pos_st;
		undef @pos_en;
		$tseq = $seq; #temporary variable
#		$resi = $v{'residue'};
#		$v{'verbose'} = 1 if ($tseq =~ /MSQPNRGPSPFSPVQLHQLRAQILAYKMLARGQPLPETLQLAVQGKRTLPGMQQQQ/);
#		$v{'verbose'} = 0 if ($tseq !~ /MSQPNRGPSPFSPVQLHQLRAQILAYKMLARGQPLPETLQLAVQGKRTLPGMQQQQ/);
		$tseq =~ s/[^$v{'residue'}]/-/g; #every gap residue is transformed into a "-"  to allow \b in seed identification
		$left_good = '';
		$right_good = '';
		while ($tseq =~ /\b($matchseq)\b/g) { # a seed is found as a stretch o consecutive Q flanked by non Q
			$end = 0;
			$cnt++;
			$match = $1; #the seed
			$length = length($match); # the length of the seed for starting zooming out
			$pos_st = pos($tseq)-$length+1; # the right position of the seed (last Q)
			$pos_en = pos($tseq); # the right position of the seed (last Q)
			print "\n\n $name[$count]\n\n- GOT CENTER with $match at $pos_st-$pos_en -\n" if ($v{'verbose'} == 1);
			$max = $v{'seed_gap_max_size'}+1; #+1 for starting with the -- in while procedure
			$match_perc = 0;
			while ($max > 1 && $match_perc < $v{'seed_stretch_min_aa_perc'}) { # until %Q is below the threshold
				$right_score = 0; # a scorer for "-" signs, while going right counts how many gaps are passed
				$right_content = '';
				$right_AA = 0;
				$right = 0;
				$max--;
				print "   GOING right for $max:" if ($v{'verbose'} == 1);
				<STDIN> if ($v{'verbose'} == 1);
				$right_good = '';
				while ($right_score <= $max) {
					print " RIGHT OUTSIDE\n" if ($pos_en+$right+1 > length($seq) && $v{'verbose'} == 1);
					last if ($pos_en+$right+1 > length($seq)); # the end of the sequence is reached, so stop going right
					$right_next = substr($seq,$pos_en+$right,1); # the next character of the match
					$right_content .= $right_next; # this contain the sequence of the right extension
					$right_score++ if ($right_next ne $v{'residue'}); # very time a gap is passed, the gap score is increased
					$right_score = 0 if ($right_next eq $v{'residue'}); # every time a Q is matched, the gap score is reset so that the match can extend right for other $max residues
					$right_AA++ if ($right_next eq $v{'residue'}); # counts the Q in the match
					$right++; # the total length of the right extension
	#				print "\n  $right_content:$right_AA ";
				} # the extension is finished since a gap has exceeded the imposed length $v{'gap_max_size'}
				if ($pos_en+$right+1 <= length($seq)) {
					$right_good = substr($right_content,0,$right-$max-1); #the whole content of the right extension minus the gaps exceeding the threshold length 
					$match_perc = ($length+$right_AA)/($length+length($right_good))*100; # $length is the length of the seed, in fact the % is computed including the seed
					print "    - $match -> $right_good = $match_perc\n" if ($v{'verbose'} == 1);
				}
			}
			$max = $v{'seed_gap_max_size'}+1;
			$match_perc = 0;
			while ($max > 1 && $match_perc < $v{'seed_stretch_min_aa_perc'}) { # 02/12/2010 qdded the control $max > 1 that was absent before, dunno why...
				$max--;
				$left_score = 0;
				$left_content = '';
				$left_AA = 0;
				$left = 0;
				$left_good = '';
				print "   GOING left for $max:\n" if ($v{'verbose'} == 1);
				while ($left_score <= $max) {
					print " LEFT OUTSIDE\n" if ($pos_en-$length-$left < 0 && $v{'verbose'} == 1);
					last if ($pos_en-$length-$left < 0); # the beginning of the sequence is reached, so stop going left
					last if ($end && $pos_en-$length-$left < $end); # the beginning of the last sequence is reached, so stop going left
					$left_next = substr($seq,$pos_en-$length-$left-1,1); # the substring is in the left direction
					$left_content .= $left_next; # the content goes in the right direction so a reverse will be needed at the end 
					$left_score++ if ($left_next ne $v{'residue'}); # a score for gaps
					$left_score = 0 if ($left_next eq $v{'residue'}); # every time a Q is matched, the gap score is reset so that the match can extend left for other $max residues
					$left_AA++ if ($left_next eq $v{'residue'}); # a score for Qs
					$left++; # the total length of the left extension
	#				print "\n  ",reverse($left_content),":$left_AA ";
				}
				if ($pos_en-$length-$left >= 0) {
					$left_good = substr($left_content,0,$left-$max-1); # remember the left is mounted reverse
					$match_perc = ($length+$left_AA)/($length+length($left_good))*100; # $length is the length of the seed, in fact the % is computed including the seed
					$left_good = reverse $left_good;
					print "    - $left_good <- $match = $match_perc\n" if ($v{'verbose'} == 1);
				}
			}
			#describing match
			$good_match = $left_good.$match.$right_good; # see line 635, the whole match is recorded
			$AAcnt = $good_match =~ s/$v{'residue'}/$v{'residue'}/g; # number of Qs in the stretch
			$match_perc = $AAcnt/length($good_match)*100; # %Q in the whole match
			next if ($match_perc < $v{'seed_stretch_min_aa_perc'});
			print "$good_match > ",$v{'seed_stretch_min_aa_perc'},"%, OK!!!\n" if ($v{'verbose'} == 1);
			push @stretch , $good_match;

			#describing positions
			$newpos = $pos_en+length($right_good); # the end of the seed + the length of the right extension, this is the start for searching the new seed
			$end = $newpos; # <- check what exactly $pos_en is, there is something strange here, maybe the end is placed too close since length(seed) must be added, too 
			$start = $newpos-length($good_match)+1; # if the above comment is true, the $start is placed forward and is incorrect
			push @pos_st , $start;
			push @pos_en , $end;
			push @pos , ($start).".".($end);
 
			#describing lflank
			$lst = $start-$v{'flank_start'}-$v{'flank_length'}-1;
			$llen = $v{'flank_length'};
			$lst = 0 if ($lst < 0);
			$llen += $lst if ($lst < 0);
			print "LFLANK: st $lst len $llen\n" if ($v{'verbose'} == 1);
			$t_flankl = '';
			$t_flankl = substr ($seq,$lst,$llen);
			push @flankl , $t_flankl if (length($t_flankl) > 0);
			push @flankl , "@" if (length($t_flankl) == 0);

			#describing rflank
			$rst = $end+$v{'flank_start'} if ($end+$v{'flank_start'} < length($seq)); 
			$rst = length($seq) if ($end+$v{'flank_start'} >= length($seq)); 
			$rlen = $v{'flank_length'}; # gorilla modofications due to errors when an isolated seed is found at the end of a sequence
			$rlen = length($seq)-$rst if ($rst+$rlen >= length($seq));
			$rlen = 0 if ($rlen < 0);
			print "RFLANK: st $rst len $rlen, seqlen ",length($seq),"\n" if ($v{'verbose'} == 1);
			$t_flankr = '';
			$t_flankr .= substr($seq,$rst,$rlen);
			push @flankr , $t_flankr if (length($t_flankr) > 0);
			push @flankr , "@" if (length($t_flankr) == 0);

#			print "\n ->      M ",scalar @stretch," ($cnt) -> $t_flankl|$start|$good_match|$end|$t_flankr: $match_perc %\n\n" if ($v{'verbose'} == 1);
#			print "\n ->array M ",scalar @stretch," ($cnt) -> $flankl[$#flankl]|$start|$good_match|$end|$flankr[$#flankr]: $match_perc %\n" if ($v{'verbose'} == 1);
			pos($tseq) = $end; # WARNING: at this stage of development, it is possible that a right flank and the following left flank overlap... 
			# try adding $v{'flank_length'}  to $newpos to overcome this problem, but has to be checked...
#			if ($#pos_st > 0 && $#pos_en > 0 && $pos_st[$#pos_st] <= $pos_st[$#pos_st-1] && $pos_en[$#pos_en] >= $pos_en[$#pos_en-1]) {  # pre-gif-meeting
#			if ($#pos_st > 0 && $#pos_en > 0 && $pos_st[$#pos_st] <= $pos_en[$#pos_en-1]) { #post-gif meeting, but removed on september 2010
			# current match is contained inthe previous match if its start is higher than the previous one AND its end is lower than the previous one, but this is unuseful
			# TRY USING SIMPLY something like "if the start of the current match is before the end of the previous match", that sounds much better
			# if there already is a match AND if the start of the current match is prior to the start of the previous match AND the end of the current match is after the end of the previous match (???) : this sounds strange... 
			# to avoid flank overlap in contiguous matches, some changes is needed here !!!! e.g. adding flank_len in comparisons
#				$p_tmp = pop @pos;
#				$l_tmp = pop @flankl;
#				$r_tmp = pop @flankr;
#				$s_tmp = pop @stretch;
#				pop @pos;
#				pop @flankl;
#				pop @flankr;
#				pop @stretch;
#				push @pos, $p_tmp;
#				push @flankl, $l_tmp;
#				push @flankr, $r_tmp;
#				push @stretch, $s_tmp;
#				$cnt--;
#				print "\nThis match contains /overlap the previous, so I just have\n" if ($v{'verbose'} == 1);
#				foreach (0..$#stretch) {
#					print "$_ : $stretch[$_]\n" if ($v{'verbose'} == 1);
#				}
#			}
#			if ($#pos_st > 0 && $#pos_en > 0 && $pos_st[$#pos_st] == $pos_en[$#pos_st-1]+$v{'flank_length'}+1 && $flankl[$#flankl] eq $flankr[$#flankr-1]) { #this should be redundant
#				$flankl[$#flankl] = "@"; # this way the current left flank is "neutralized" since it is identical to the right flank of the previous match 
#				print "\n ->cM ",scalar @stretch," ($cnt) -> $flankl[$#flankl] |$start| $good_match |$end| $flankr[$#flankr]: $match_perc %\n\n" if ($v{'verbose'} == 1);
#			}
			<STDIN> if ($v{'verbose'} == 1);
		}
		$stretch = join "-",@stretch;
		$pos = join "-",@pos;
		$flankl = join "-",@flankl;
		$flankr = join "-",@flankr;
	}
	# the rich engine ###########################################################################
	if ($v{'scanmode'} eq 'rich') {
		undef @stretch;
		undef @flankl;
		undef @flankr;
		undef @pos;
		undef $cnt;
		my $count = 0;
		my $posi = 0;
		my $perc = 0;
		my $win = int($v{'rich_win_length'}/2);
		my $res = $v{'residue'};
		my $string = '-'x($win); #the -1 adjust the position of the first +
		my $tolerance = $v{'rich_gap_tolerance'} if ($v{'rich_gap_tolerance'} !~ /auto/i);
		$tolerance = (100-$v{'rich_stretch_min_aa_perc'})/10-$v{'rich_win_length'}+1 if ($v{'rich_gap_tolerance'} =~ /auto/i);
		my @perc = (); my @posi = (); my @data = ();
		my $m = ''; my $M = ''; my $lfl = ''; my $rfl = '';
		foreach my $ind (1..length($seq)-$win) { # this slides the window and counts the Q
			$anal = substr($seq,$ind-1,$v{'rich_win_length'});
			$count = $anal =~ s/$res/$res/g;
			$posi = $ind+$win;
			$perc = sprintf("%.2f",$count/$v{'rich_win_length'}*100); # then computes the %  
			push(@perc,$perc); # and stores %values
			push(@posi,$posi);  # position and
			push(@data,$anal); # residues in the window
		}
		open (DATA, ">>out.txt") if ($v{'rich_verbose'});
		print DATA "\nNAM: $name\n" if ($v{'rich_verbose'} && $v{'rich_verbose'} == 1);
		print DATA substr($name,0,10),"\t" if ($v{'rich_verbose'} && $v{'rich_verbose'} == 2);
		foreach $ind (0..$#posi) { #this builds up a sequence counterpart made of + and - according to the %threshold reached (+ = above, - = below)
#			print DATA $data[$ind],"\t",$posi[$ind],"\t",$perc[$ind],"\t" if ($v{'rich_verbose'} == 1);
			$string .= "+" if ($perc[$ind] >= $v{'rich_stretch_min_aa_perc'}); 
			$string .= "-" if ($perc[$ind] < $v{'rich_stretch_min_aa_perc'});
#			print DATA "+" if ($v{'rich_verbose'} == 1 && $perc[$ind] >= $v{'rich_stretch_min_aa_perc'}); 
#			print DATA "-" if ($v{'rich_verbose'} == 1 && $perc[$ind] < $v{'rich_stretch_min_aa_perc'}); 
#			print DATA "\n" if ($v{'rich_verbose'} == 1);
		}
		$tol_string = $string; #this is used for tolerance adjustment
		foreach (1..2) { #double pass solves a technical issue...
			foreach my $t (1..$tolerance) { #the tolerance is the number of allowed - between two +: ex. if tol = 2, then +++--+++ -> ++++++++ => acceptable
				$m = '\+'.'-'x$t.'\+';
				$M = '+'.'+'x$t.'+';
				$tol_string =~ s/$m/$M/g;
			}
		}
		$adj_string = $tol_string;
		foreach my $t (1..$win) { #this expand allowed stratch considering the window leftward
			$adj_string =~ s/-\+/++/g;
		} 
		foreach my $t (1..$win) { #this expand allowed stratch considering the window rightward
			$adj_string =~ s/\+-/++/g;
		}
		print DATA "\nSEQ: ",$seq,"\nSTR: ",$string,"\nTOL: ",$tol_string,"\nEXT: ",$adj_string,"\n\n" if ($v{'rich_verbose'} && $v{'rich_verbose'} == 1);
		while ($adj_string =~ /(\++)/g) { #catches consecutive ++ stretches
			$len = length($1); 
			next if ( $len < $v{'rich_stretch_min_size'}); #discard too short stretches
			$str = substr($seq,pos($adj_string)-$len,$len);
			$str_len = length($str);
			print DATA "STR: ", $str,"\n" if ($v{'rich_verbose'} && $v{'rich_verbose'} == 1); 
			$str =~ s/(^[^$res]*?)$res/$res/; #removes residues before the first Q
			$st_rem = 0;
			$st_rem = length($1); # counts the residues removed
			$str =~ s/$res([^$res]*?$)/$res/; #removes residues after the last Q
			$en_rem = 0;
			$en_rem = length($1); # counts the residues removed
			print DATA "ADJ: ", $st_rem,"-",$str,"-",$en_rem,"\n" if ($v{'rich_verbose'} && $v{'rich_verbose'} == 1);
			print DATA " too short !!!\n" if ($v{'rich_verbose'} && $v{'rich_verbose'} == 1 && length($str) < $v{'rich_stretch_min_size'});
			next if (length($str) < $v{'rich_stretch_min_size'});
			$count = $str =~ s/$res/$res/g;
			$perc = sprintf("%.2f",$count/length($str)*100); 
			print DATA " too poor !!!\n" if ($v{'rich_verbose'} && $v{'rich_verbose'} == 1 && $perc < $v{'rich_stretch_min_aa_perc'});
			next if ($perc < $v{'rich_stretch_min_aa_perc'});
			$st = pos ($adj_string)-$str_len+$st_rem+1;
			$en = pos ($adj_string)-$en_rem;
			$lf_st = $st-$v{'flank_start'}-$v{'flank_length'}-1;
			$lf_len = $v{'flank_length'};
			$lf_len = $v{'flank_length'}+$lf_st if ($lf_st < 0); #if lf_st <0, then the length is shortened
			$lf_st = 0 if ($lf_st < 0);
			$rf_st = $en+$v{'flank_start'};
			$rf_len = $v{'flank_length'};
			$rf_len = $v{'flank_length'}-(($rf_st+$rf_len)-length($seq)) if ($rf_st+$rf_len > length($seq));
			$rf_len = 0 if ($rf_st > length($seq));
			$rf_st = length($seq) if ($rf_st > length($seq));
			$lfl = substr($seq,$lf_st,$lf_len);
			$rfl = substr($seq,$rf_st,$rf_len);
			$tpos = $st.".".$en;
			push(@pos,$tpos);
			push(@stretch,$str);
			push @flankr , "@" if (length($rfl) == 0);
			push @flankr , $rfl if (length($rfl) > 0);
			push @flankl , "@" if (length($lfl) == 0);
			push @flankl , $lfl if (length($lfl) > 0);
			print DATA "\nPOS: $tpos\nST: $st\nEN: $en\nSTRETCH: $str ($perc %)\nLFL: $lfl\nRFL: $rfl\n\n" if ($v{'rich_verbose'} && $v{'rich_verbose'} == 1);
		}
		$stretch = join "-",@stretch;
		$pos = join "-",@pos;
		$flankl = join "-",@flankl;
		$flankr = join "-",@flankr;
		$cnt = scalar @stretch;
		print DATA $cnt,"\t",scalar @stretch, "\t",$stretch,"\n" if ($v{'rich_verbose'} && $v{'rich_verbose'} == 2);
		close DATA if ($v{'rich_verbose'});
	}
	return ($stretch,$cnt,$pos,$flankl,$flankr);
}

sub compute_globals {
	print STDERR "\n\n> Computing globals <\n ";
	$totglob = $full_for_glob =~ s/-/-/g;
	print STDERR " Counting $totglob sequences\n";
	my ($glob_list,undef) = count_new($full_for_glob);
	my @glob_list = split (/\t/,$glob_list);
	my $tup_cnt = 1;
	my $global_stat = '';
	foreach my $stat (@glob_list) {
		$stat =~ s/ /\t/g; 
		$global_stat .= "\nGlobal_stat_tup_".$tup_cnt."\t".$stat;
		$tup_cnt++;
	}
	$global_stat =~ s/\n//;
	return $global_stat;
}

sub write_results {
	$global_stat = compute_globals;

	print STDERR "\n> Writing prot-out.txt <\n";

#	$mingaprep = $v{'gap_min_size'};
#	$maxgaprep = $v{'gap_max_size'};
#	$mingaprep = 'no gap allowed' if ($v{'gap_max_size'} == 0);
#	$maxgaprep = 'no gap allowed' if ($v{'gap_max_size'} == 0);

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime time;
	$mon++;
	$year += 1900;
	$head = '';
	foreach (sort keys %v) {
		$head .= $_."\t".$v{$_}."\n";
	}
	chomp $head;

	open(OUT, ">$outfile");
	
	
print OUT <<EOT;
AAstretch launched $mday/$mon/$year at $hour:$min:$sec
$head
EOT
;
	print OUT "$global_stat\nAvailable sequences\t$available_seq\nTotal AA count\t$total_AA_count\nTotal stretches found\t$total_stretch_count\n1st-M\t$m1st\n$out"; 
	close OUT;
}

sub help {
	print "\n USAGE: AAstretch.pl [run|restart|clean|isolate|help]\n\n";
	print " Fill in the AAstretch.conf file and launch the program.\n";
	print " AAsync and (optionally) AAexplore scripts must be installed.\n\n";
	print " Run     : launch AAstretch (reads AAstretch.conf)\n";
	print " Restart : recreates the starting environment\n";
	print " Clean   : removes previous results\n";
	print " Isolate : put all results in a new folder\n";
	print " help    : this help\n\n";
}
