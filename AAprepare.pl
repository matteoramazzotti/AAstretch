#! /usr/bin/perl
#(c) matteo.ramazzotti@unifi.it
#last revision Oct 19 2017

use Net::FTP;
use LWP::UserAgent;
use LWP::Simple;
use Archive::Extract;
use IO::Compress::Gzip qw(gzip) ;
use IO::Uncompress::Gunzip qw(gunzip);
#name,site,schema
#the mart name can be esily obtaied using R biomaRt with listMarts(host = "www.ensembl.org") or other other sites
@{$mart{'1'}} = ('Vertebrates','www.ensembl.org','ftp.ensembl.org','pub/current_fasta','ENSEMBL_MART_ENSEMBL');
@{$mart{'2'}} = ('Plants','plants.ensembl.org','ftp.ensemblgenomes.org','pub/plants/release-37/fasta','plants_mart');
@{$mart{'3'}} = ('Fungi','fungi.ensembl.org','ftp.ensemblgenomes.org','pub/fungi/release-37/fasta','fungal_mart');
@{$mart{'4'}} = ('Protists','protists.ensembl.org','ftp.ensemblgenomes.org','pub/protists/release-37/fasta','protist_mart');
@{$mart{'5'}} = ('Metazoa','metazoa.ensembl.org','ftp.ensemblgenomes.org','pub/metazoa/release-37/fasta','metazoa_mart');

$martchoice = $ARGV[0];
$orgname = $ARGV[1];
 
$| = 1;
($sec,$min,$hour,$mday,$mon,$year,undef,undef) = gmtime(time);
opendir(DIR,".");
$log_ind = 0;
foreach(readdir DIR) {
	$log_ind++ if ($_ =~ /log_/);
}
$logfile = $log_ind."-"."log_AAprepare.txt";
open (OUT, ">$logfile");
print OUT "\n------ The AAstretch Project -------\n------------ AAprepare -------------\n---- PloS ONE 2012, 7(2):e30824 ----\n---- matteo.ramazzotti\@unifi.it ----\n--- Session ",sprintf("%02d",$mday),"-",sprintf("%02d",$mon+1),"-",$year+1900,"\t",sprintf("%02d",$hour+2),":",sprintf("%02d",$min),":",sprintf("%02d",$sec)," ---\n------------------------------------\n\n";
print "\n------ The AAstretch Project -------\n------------ AAprepare -------------\n---- PloS ONE 2012, 7(2):e30824 ----\n---- matteo.ramazzotti\@unifi.it ----\n--- Session ",sprintf("%02d",$mday),"-",sprintf("%02d",$mon+1),"-",$year+1900,"\t",sprintf("%02d",$hour+2),":",sprintf("%02d",$min),":",sprintf("%02d",$sec)," ---\n------------------------------------\n\n";

print " Preloading marts...";
print OUT " Preloading marts...";
#preload mart db information for the various marts
foreach $i (keys %mart) {
	$page = get("http:\/\/$mart{$i}[1]\/biomart\/martservice?type=registry");
	@vs = split(/\n/,$page);
	foreach $vs (@vs) {
		next if ($vs !~ / Genes /);
		if ($vs =~ / database=\"(.+?)\".+?name=\"(.+?)\".+?serverVirtualSchema=\"(.+?)\"/){
			$mart_db{$i} = $1;
			$mart_name{$i} = $2;
			$mart_vs{$i} = $3;
		}
	}
}
print "done.\n";
print OUT "done.\n";

foreach $m (sort keys %mart) {
	$cnt++;
	print " $cnt. $mart{$m}[0]\n";
}
print "\n Choose one: ";
print OUT "\n Choose one: ";

print $martchoice,"\n\n" if ($martchoice);
if (!$martchoice) {
	$martchoice = <STDIN>;
	chomp $martchoice;
}
print OUT $martchoice,"\n\n";

print " Fetching Mart datasets...";
print OUT " Fetching Mart datasets...";

$dataset = "http://".$mart{$martchoice}[1]."\/biomart\/martservice\?type=datasets&mart=$mart{$martchoice}[4]";

foreach $line (split(/\n/,get($dataset))) {
	chomp $line;
	next if ($line !~ /\w/);
	(undef,$geneset,$name) = split (/\t/,$line);
	$geneset_back = $geneset;
	$geneset =~ s/_.*//;
	$geneset{$geneset} = $geneset_back;
}
print "done.\n\n";
print OUT "done.\n\n";

$conn = Net::FTP->new($mart{$martchoice}[2]) or die "Cannot connect to $mart{$martchoice}[2]: $@"; #si connette con l'host
$conn->login("anonymous",'-anonymous@'); #accede alle cartelle
$conn->cwd($mart{$martchoice}[3]);   
@list = $conn->ls($conn->pwd); #ritorna una lista di files (o dirs) nella directory corrente

print "\nAvailable organisms (EnsEMBL FTP):\n\n";
print OUT "\nAvailable organisms (EnsEMBL FTP):\n\n";
$ind = 0;
LIST:
foreach (@list) {
	$ind++;
	@tmp = split (/\//, $_);
	push (@org_list, $_);
	print " $ind. $tmp[$#tmp]\n";
	print OUT " $ind. $tmp[$#tmp]\n";
}
print "\n Choose one: ";
print OUT "\n Choose one: ";
print $orgname,"\n\n" if ($orgname);
if (!$orgname) {
	$orgname = <STDIN>;
	chomp $orgname;
}
print OUT $orgname,"\n\n";
goto LIST if (!$orgname);

push (@ok, $org_list[$orgname-1]) if ($orgname !~ /[,\s]/ && $orgname !~ /^all$/i);
if ($orgname =~ /[,\s]/ && $orgname !~ /^all$/i) {
	@ok_ = split (/[,\s]+/,$orgname); 
	foreach (@ok_) {
		push (@ok,$org_list[$_-1]);
		print STDERR " You selected $_. ",$tmp[$_-1],"\n"; 
		print OUT " Selected $_. ",$tmp[$_-1],"\n"; 
	}
}
@ok = @org_list if ($orgname =~ /^all$/i);

mkdir 'tmp' if (!-d 'tmp');

foreach $org (sort @ok) {
	if ($org =~ /collection/i) {
		print "$org is a collection...skipping\n";
		print OUT "$org is a collection...skipping\n";
		next;
	}
	@split = split (/\//, $org);
	$ftp_name = $split[$#split];
	if (-e "tmp/$ftp_name") { #already processed organism (all)
		print "$ftp_name already processed\n";
		print OUT "$ftp_name already processed\n";
		next;
	}
	$ftp_name =~ /(.).+?_(.+)/;
	$geneset_name = $1.$2;
	print " Collecting data for $ftp_name -> $geneset_name ($geneset{$geneset_name})...\n";
	print OUT " Collecting data for $ftp_name -> $geneset_name ($geneset{$geneset_name})...\n";

	$tentatives = 0;

	# PROTEIN DATA
	DOWN1:
	$tentatives++;
	if (-s "tmp/$ftp_name.prot.gz") { #already processed proteine file
		print "   $ftp_name protein file already downloaded\n";
		print OUT "   $ftp_name protein file already downloaded\n";
		goto DOWN2;
	}
	print "\n   Downloading protein file for $ftp_name (ftp)...";
	print OUT "\n   Downloading protein file for $ftp_name (ftp)...";
	$conn->cwd("$ftp_name/pep/");
	@files = $conn->ls($conn->pwd);                  #ritorna una lista di files (o dirs) nella directory corrente
	foreach(@files) {
		if ($_ =~ /pep\.all/) {
			print OUT $_,"...";
			$conn->binary;
			$conn->get($_, 'tmp/'.$ftp_name.'.prot.gz');
			$conn->ascii;
		}
	}
	$conn->cdup;
	$conn->cdup;
	print OUT "done.\n" if (-s 'tmp/'.$ftp_name.'.prot.gz');
	print "done.\n" if (-s 'tmp/'.$ftp_name.'.prot.gz');
	print OUT "error.\n" if (!-s 'tmp/'.$ftp_name.'.prot.gz');
	print "error.\n" if (!-s 'tmp/'.$ftp_name.'.prot.gz');

	# CDS DATA
	DOWN2: 
	if (-s "tmp/$ftp_name.cds.gz") { #already processed proteine file
		print "   $ftp_name cds file already downloaded\n";
		print OUT "   $ftp_name cds file already downloaded\n";
		goto DOWN3;
	}
	print "   Downloading cds file for $ftp_name (ftp)...";
	print OUT "   Downloading cds file for $ftp_name (ftp)...";
	$conn->cwd("$ftp_name/cdna");
	@files = $conn->ls($conn->pwd);                  #ritorna una lista di files (o dirs) nella directory corrente
	foreach(@files) {
		if ($_ =~ /cdna\.all/) {
			print OUT $_,"...";
			$conn->binary;
			$conn->get($_, 'tmp/'.$ftp_name.'.cds.gz');
			$conn->ascii;
		}
	}
	$conn->cdup;
	$conn->cdup;
	print OUT "done.\n" if (-e 'tmp/'.$ftp_name.'.cds.gz');
	print "done.\n" if (-e 'tmp/'.$ftp_name.'.cds.gz');
	print OUT "error.\n" if (!-e 'tmp/'.$ftp_name.'.cds.gz');
	print "error.\n" if (!-e 'tmp/'.$ftp_name.'.cds.gz');

	# DESCRIPTION DATA
	DOWN3:
	if (-s "tmp/$ftp_name.desc.gz") { #already processed proteine file
		print "   $ftp_name annotation file already downloaded\n";
		print OUT "   $ftp_name annotation file already downloaded\n";
		goto PROCESS;
	}
	print "   Downloading annotations for $ftp_name (biomart)...";
	print OUT "   Downloading annotations for $ftp_name (biomart)...";
	$xml = xml_desc_build();
	$xml =~ s/\n//g;
	download($xml,"tmp/$ftp_name.desc");
	open(IN,"tmp/$ftp_name.desc");
	@in = <IN>;
	close IN;
	$desc_error = 0;
	$desc_error = 1 if ($in[0] =~ /ERROR/); #biomart error cretes a file with size > 0 (cannt be checked with -s), that is different from the ftp fail...
	gzip "tmp/".$ftp_name.'.desc' => "tmp/".$ftp_name.'.desc.gz' if (-s "tmp/".$ftp_name.'.desc' && !$desc_error);
	$max = 3;
	if ($name =~ /sapiens/i) {
		next if (-e "tmp/$ftp_name.mim.gz");
		$xml = xml_desc_build_mim();
		$xml =~ s/XXXXXXXXXX/$ensembl_set_name/; #modify xml on the fly to place name and mart obtained from MARTSERVICE
		$xml =~ s/ZZZZZZZZZZ/$marts_vs{$martchoice}/;
		$xml =~ s/\n//g;
		download($xml,"tmp/$ftp_name.mim");
		open(IN,"tmp/$ftp_name.mim");
		@in = <IN>;
		close IN;
		$desc_error_mim = 0;
		$desc_error_mim = 1 if ($in[0] =~ /ERROR/); #biomart error cretes a file with size > 0 (cannt be checked with -s), that is different from the ftp fail...
		gzip "tmp/".$ftp_name.'.mim' => "tmp/".$ftp_name.'.mim.gz' if (-s "tmp/".$ftp_name.'.mim');
		$max = 4;
	}
#	goto DOWNEND if (-s "tmp/".$ftp_name.'.desc.gz' && ($name =~ /sapiens/i && -s "tmp/".$ftp_name.'.mim.gz'));
#	goto DOWNEND if ($name !~ /sapiens/i && -s "tmp/".$ftp_name.'.desc.gz' );
	print OUT "done.\n" if (-s 'tmp/'.$ftp_name.'.desc.gz');
	print "done.\n" if (-s 'tmp/'.$ftp_name.'.desc.gz');
	
#	DOWNEND:
	$ok = 0;
	$ok++ if (-s "tmp/$ftp_name.prot.gz");
	$ok++ if (-s "tmp/$ftp_name.cds.gz");
	$ok++ if (-s "tmp/$ftp_name.desc.gz" || !$desc_error);
	$ok++ if (-s "tmp/$ftp_name.mim.gz" || !$desc_error_mim);
	$miss = $max-$ok;
	if ($ok < $max && $tentatives == 1) {
		print "\n $miss files missing. Retrying...\n";
		print OUT "\n $miss files missing. Retrying...\n";
		goto DOWN1;
	}
	if ($ok < $max && $tentatives == 2) {
		print "\n $miss file/s missing. File creation aborted.\n";
		print OUT "\n $miss file/s missing. File creation aborted.\n";
		next;
	}

	PROCESS:
	print "   Uncompressing $ftp_name files...";
	print OUT "   Uncompressing $ftp_name files...";
	uncompress_all($ftp_name);
	print "done.\n";
	print OUT "done.\n";

	CREATE:
	print "   Loading $ftp_name data....";
	print OUT "   Loading $ftp_name data....";
	load_data($ftp_name);
	print "done.\n";
	print OUT "done.\n";
	print "   Creating files....";
	print OUT "   Creating files....";
	create_files($ftp_name);
	print "done.\n";
	print OUT "done.\n";
	print "   Clearing temp files...";
	print OUT "   Clearing temp files...";
	unlink "tmp/$ftp_name.prot";
	unlink "tmp/$ftp_name.cds";
	unlink "tmp/$ftp_name.desc";
	unlink "tmp/$ftp_name.prot.gz";
	unlink "tmp/$ftp_name.cds.gz";
	unlink "tmp/$ftp_name.desc.gz";
	print "done.\n";
	print OUT "done.\n";
	open (TOUCH,">tmp/$ftp_name"); #this flags the organism as all done
	print TOUCH "1";
	close TOUCH;
	print "\n $ftp_name has $ok entries available for analysis !!!\n\n";
	print OUT "\n $ftp_name has $ok entries available for analysis !!!\n\n";

}
close OUT;

sub parse_martservice {
	my $name = shift;
	my $alt_name  = '';
	my $ensembl_set_name  = '';
	my $rest  = '';
	my @tmp;
	my @tmp2;
	my $page = get("http://$mart{$martchoice}[2]/biomart/martservice?type=datasets&mart=$mart{$martchoice}[4]");
	$name =~ s/\w_// if ($marts{$martchoice} =~ /bacterial/i && $name !~ /sp_/);
	$name =~ s/_/ /g;
	my $page = get("http:\/\/www.ensembl.org\/biomart\/martservice?type=datasets&mart=$marts{$martchoice}"); #much more accurate, since it consult the official MARTSERVICE
	my @page = split (/\n/,$page);
	foreach(@page) {
		@tmp = split (/\t/,$_);
		shift @tmp;
		$alt_name = '';
		$ensembl_set_name = shift @tmp;
		$rest = shift @tmp;
		$rest =~ s/[:|\/|-]/_/g;
		$rest =~ s/\.//g;
		if ($rest =~ /$name/i) {
			@tmp2 = split (/gene/,$rest);
			$alt_name = $tmp2[0];
		}
		last if $alt_name;
	}
	$alt_name =~ s/ /_/g;
	$alt_name =~ s/_$//;
	return $ensembl_set_name,$alt_name,$name;
}

sub create_files {
	my $org = shift;
	$prot_file = $org.".prot.txt";
	$cod_file = $org.".cod.txt";
	open (PROT,">$prot_file");
	open (COD,">$cod_file");
	$ok = 0;
	$tot = 0;
	foreach $code (sort keys %prot) { # code is the ensembl transcript code that is ised as a reference in the whole AAprepare...
		$coding = '';
		$ann = '';
		($coding) = translate($cod{$code},$prot{$code});
		if ($coding) {
			$go_bp{$code} =~ s/(:?:;)+/---/g;
			$go_mf{$code} =~ s/(:?:;)+/---/g; 
			$go_cc{$code} =~ s/(:?:;)+/---/g; 
			$mim{$code} =~ s/(:?:;)+/---/g; 
			$ann = $name{$code};
			$ann .= '|ann|'.$desc{$code} if ($desc{$code});
			$ann .= '|ann|---' if (!$desc{$code});
			$ann .= '|go_fun|'.$go_mf{$code} if ($go_mf{$code});
			$ann .= '|go_fun|---' if (!$go_mf{$code});
			$ann .= '|go_pro|'.$go_bp{$code} if ($go_bp{$code});
			$ann .= '|go_pro|---' if (!$go_bp{$code});
			$ann .= '|go_com|'.$go_cc{$code} if ($go_cc{$code});
			$ann .= '|go_com|---' if (!$go_cc{$code});
			$ann .= '|omim|'.$mim{$code} if (%mim && $mim{$code});
			$ann .= '|omim|---' if (!%mim || (%mim && !$mim{$code}));
			print PROT $ann,"\n",$prot{$code},"\n";
			print COD $ann,"\n",$coding,"\n";
			$ok++;
		}
		$tot++;
	}
}

sub uncompress_all {
	my $file = shift;
	print 'prot...';
	extract_gz('tmp/'.$file.'.prot.gz') if (-e 'tmp/'.$file.'.prot.gz' && !-e 'tmp/'.$file.'.prot');
	print 'cod...';
	extract_gz('tmp/'.$file.'.cds.gz') if (-e 'tmp/'.$file.'.cds.gz' && !-e 'tmp/'.$file.'.cds');
	print 'desc...';
	extract_gz('tmp/'.$file.'.desc.gz') if (-e 'tmp/'.$file.'.desc.gz' && !-e 'tmp/'.$file.'.desc');
	print 'omim...' if ($file =~ /sapiens/i);
	extract_gz('tmp/'.$file.'.mim.gz') if (-e 'tmp/'.$file.'.mim.gz' && !-e 'tmp/'.$file.'.mim' && $file =~ /sapiens/i);
	}

sub extract_gz {
	my $arch = shift;
	my $file = $arch;
	$file =~ s/\.gz//;
	my $obj = Archive::Extract->new( archive => $arch );
	$obj->extract(to => 'tmp');
	undef $arch;
}

sub load_data {
	%prot = ();
	%name = ();
	%cod = ();
	%desc = ();
	%tr_id = ();
	%go_bp = ();
	%go_mf = ();
	%go_cc = ();
	my $name = shift;
	open (IN,'tmp/'.$name.".prot");
	$ind = 0;
	$err_cnt = 0;
	print "prot...";

	######### load protein data ###########
	while ($line = <IN>) {
		chomp $line;
		if ($line =~ />/) {
			$err1 = 0;
			$err2 = 0;
			$err1 = $prot{$tmp[$#tmp]} =~ s/\*/*/g if ($prot{$tmp[$#tmp]}); # those must be discarded
			$err2 = $prot{$tmp[$#tmp]} =~ s/([XZUOB])/$1/g if ($prot{$tmp[$#tmp]}); # those must be discarded
			if ($err1 > 1 || $err2 > 0) {
				delete $prot{$tmp[$#tmp]};
				delete $name{$tmp[$#tmp]};
				$err_cnt++;
			}
			$ind++;
			$line =~ />(.+?) .+?gene:(.+?) transcript:(.+?) /;
			$pid = $1;
			$gid = $2;
			$tid = $3;
			$pid =~ s/\..+//;
			$tid =~ s/\..+//;
			$gid =~ s/\..+//;
			$protein{$tid} = $pid;
			$transcript{$pid} = $tid;
			$name{$pid} = '>prot|'.$pid.'|cod|'.$tid.'|gene|'.$gid;
		} else {
			$prot{$pid}.= $line;
		}
	}	
	close IN;

	######### load cdna data ###########
	print "cod...";
	open (IN,'tmp/'.$name.".cds");
	$ind = 0;
	while ($line = <IN>) {
		chomp $line;
		if ($line =~ />/) {
			$line =~ />(.+?) /;
			$tid = $1;
			$tid =~ s/\..+//;
			$ind++;
		} else {
			$cod{$protein{$tid}} .= $line;
		}
	}
	close IN;
	%field = ();
		$field{'TID'} = 0;
		$field{'DES'} = 1;
		$field{'GOC'} = 2;
		$field{'GOD'} = 3;
		$field{'GON'} = 4;
	print "desc...";
	open (IN,'tmp/'.$name.".desc");
	$ind = 0;
	while($line = <IN>) {
		chomp $line;
		$ind++;
		next if ($ind == 1);
		@tmp = split(/\t/,$line);
		$did = $protein{$tmp[$field{'TID'}]};
		$go_bp{$did} .= $tmp[$field{'GOC'}].":".$tmp[$field{'GOD'}].';' if ($tmp[$field{'GON'}] && $tmp[$field{'GON'}] =~ /biological_process/i && $go_bp{$tmp[$field{'TID'}]} !~ /$tmp[$field{'GOC'}]/);
		$go_mf{$did} .= $tmp[$field{'GOC'}].":".$tmp[$field{'GOD'}].';' if ($tmp[$field{'GON'}] && $tmp[$field{'GON'}] =~ /molecular_function/i && $go_mf{$tmp[$field{'TID'}]} !~ /$tmp[$field{'GOC'}]/);
		$go_cc{$did} .= $tmp[$field{'GOC'}].":".$tmp[$field{'GOD'}].';' if ($tmp[$field{'GON'}] && $tmp[$field{'GON'}] =~ /cellular_component/i && $go_cc{$tmp[$field{'TID'}]} !~ /$tmp[$field{'GOC'}]/);
		$desc{$did} = $tmp[$field{'DES'}];
	}
	close IN;

#	if ($name =~ /sapiens/i) {
#		open (IN,'tmp/'.$name.".mim") or die "no";
#		$ind = 0;
#		$field{'TID'} = 0;
#		$field{'MIA'} = 1;
#		$field{'MID'} = 2;
#		while (<IN>) {
#			chomp $_;
#			@tmp = split(/\t/, $_);
#			next if ($_ =~ /^Ensembl/i);# {
#			$ind++;
#			$mim{$tmp[$field{'TID'}]} .= $tmp[$field{'MIA'}].":".$tmp[$field{'MID'}].';' if ($tmp[$field{'MIA'}] && $mim{$tmp[$field{'TID'}]} !~ /$tmp[$field{'MIA'}]/ && $tmp[$field{'MIA'}] ne $tmp[$field{'TID'}]);
#		}
#	}
}

sub translate {
	&gen_code if (!%codon_one);
	my $what = shift;
	my $prot = shift;
	return if ($prot =~ /\*/);
	my $prot1 = '';
	my $prot2 = '';
	my $prot3 = '';
	my $coding = '';
	my $start = '';
	my $len = '';
	while ($what =~ /(\w\w\w)/g) {
		$prot1 .= $codon_one{$1} if ($codon_one{$1});
	}
	$cod2 = substr($what,1);
	while ($cod2 =~ /(\w\w\w)/g) {
		$prot2 .= $codon_one{$1} if ($codon_one{$1});
	}
	$cod3 = substr($what,2);
	while ($cod3 =~ /(\w\w\w)/g) {
		$prot3 .= $codon_one{$1} if ($codon_one{$1});
	}
	$coding = substr($what,$-[0]*3,(length($1)+1)*3) if ($prot1 =~ /($prot)/);
	$coding = substr($what,$-[0]*3+1,(length($1)+1)*3) if ($prot2 =~ /($prot)/);
	$coding = substr($what,$-[0]*3+2,(length($1)+1)*3) if ($prot3 =~ /($prot)/);
	return ($coding);
}

sub script_build_old_ensembl_61 {
	my $script = '';
	my $mim = shift;
	$script .= "using $marts{$martchoice}.$ensembl_set_name get ";
	$script .= 'ensembl_transcript_id,description,go_biological_process_id,go_molecular_function_id,go_cellular_component_id' if (!$mim);
	$script .= 'ensembl_transcript_id,mim_morbid_accession,mim_morbid_description' if ($mim);
	$script .= " where biotype=protein_coding;";
	return $script;
}

sub script_build {
	my $script = '';
	my $mim = shift;
	$script .= "using $marts{$martchoice}.$ensembl_set_name get ";
	$script .= 'ensembl_transcript_id,description,go_id,name_1006,namespace_1003' if (!$mim);
	$script .= 'ensembl_transcript_id,mim_morbid_accession,mim_morbid_description' if ($mim);
	$script .= " where biotype=protein_coding;";
	return $script;
}

sub xml_desc_build {
	#virtualSchemaName and dataset name are taken from the links in the MARTSERVICE page @ http://www.ensembl.org/martservice.html
	my $xml = '';
	$attributes = get ("http://".$mart{$martchoice}[1]."/biomart/martservice?type=attributes&dataset=$geneset{$geneset_name}"); # ask biomart for attributes, since names changes according to the ensempl db selected
	#print " ATTRIBUTES \n$attributes\n";
	$attributes =~ /(.+?)\tGO term accession/i;
	$goacc = $1;
	$attributes =~ /(.+?)\tGO term name/i;
	$gonam = $1;
	$attributes =~ /(.+?)\tGO domain/i;
	$godom = $1;

$xml = <<XML_END;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "$mart_vs{$martchoice}" formatter = "TSV" header = "1" uniqueRows = "0" count = "" datasetConfigVersion = "0.6" >
	<Dataset name = "$geneset{$geneset_name}" interface = "default" >
		<Filter name = "biotype" value = "protein_coding"/>
		<Attribute name = "ensembl_transcript_id" />
		<Attribute name = "description" />
		<Attribute name = "$goacc" />
		<Attribute name = "$gonam" />
		<Attribute name = "$godom" />
	</Dataset>
</Query>

XML_END
;
return $xml;
}

sub xml_desc_build_mim {
	#virtualSchemaName amd dataset name are taken from the links in the MARTSERVICE page @ http://www.ensembl.org/martservice.html
	$xml = '';
$xml = <<XML_END_MIM;
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "$marts_vs{$martchoice}" formatter = "TSV" header = "0" uniqueRows = "0" count = "" datasetConfigVersion = "0.6" >
	<Dataset name = "$geneset{$geneset_name}" interface = "default" >
		<Filter name = "biotype" value = "protein_coding"/>
		<Attribute name = "ensembl_transcript_id" />
		<Attribute name = "mim_morbid_accession" />
		<Attribute name = "mim_morbid_description" />
	</Dataset>
</Query>

XML_END_MIM
;
return $xml;
}

sub download {
	my $what = shift;
	my $file = shift;
	$path = "http://$mart{$martchoice}[1]/biomart/martservice?";
	$ua = LWP::UserAgent->new;
	$response = '';
	$request = '';
	$request = HTTP::Request->new("POST",$path,HTTP::Headers->new(),'query='.$what."\n");
	open (OUT, ">$file");
	$ua->request($request,
		sub {   
			my($data, $response) = @_;
			if ($response->is_success) {
				print OUT "$data";
			}
			else {
				warn ("Problems with the web server: ".$response->status_line);
			}
	    }
		,1000); #timeout is set to 100 instead of the original 1000
	close OUT;
	undef $ua;
}

sub gen_code {
(%codon_one) = (
'GGG' => 'G',
'GGA' => 'G',
'GGT' => 'G',
'GGC' => 'G',
'GAG' => 'E',
'GAA' => 'E',
'GAT' => 'D',
'GAC' => 'D',
'GTG' => 'V',
'GTA' => 'V',
'GTT' => 'V',
'GTC' => 'V',
'GCG' => 'A',
'GCA' => 'A',
'GCT' => 'A',
'GCC' => 'A',
'AGG' => 'R',
'AGA' => 'R',
'AGT' => 'S',
'AGC' => 'S',
'AAG' => 'K',
'AAA' => 'K',
'AAT' => 'N',
'AAC' => 'N',
'ATA' => 'I',
'ATT' => 'I',
'ATC' => 'I',
'ATG' => 'M',
'ACG' => 'T',
'ACA' => 'T',
'ACT' => 'T',
'ACC' => 'T',
'TGA' => '-',
'TGT' => 'C',
'TGC' => 'C',
'TGG' => 'W',
'TAG' => '-',
'TAA' => '-',
'TAT' => 'Y',
'TAC' => 'Y',
'TTG' => 'L',
'TTA' => 'L',
'TTT' => 'F',
'TTC' => 'F',
'TCG' => 'S',
'TCA' => 'S',
'TCT' => 'S',
'TCC' => 'S',
'CGG' => 'R',
'CGA' => 'R',
'CGT' => 'R',
'CGC' => 'R',
'CAG' => 'Q',
'CAA' => 'Q',
'CAT' => 'H',
'CAC' => 'H',
'CTG' => 'L',
'CTA' => 'L',
'CTT' => 'L',
'CTC' => 'L',
'CCG' => 'P',
'CCA' => 'P',
'CCT' => 'P',
'CCC' => 'P'	
);
}
