#!  /usr/bin/perl -w
use Tk;
use GD;
use GD::Graph::mixed;
use Tk::NoteBook;
use Tk::BrowseEntry;
use Statistics::Distributions qw/chisqrprob/;
use Cwd;
use lib 'mylib';
use mylib::myPlot;
$verbose = 0;
$tuple = 1;
$ratio_t = 2;
$filter = '';
$filter_on = 'none';
$filter_mode = '---';
$filter_lock = 0;
$background = 'glob';
#$background_was = 'glob';
$firstM_ = 0;
@save = qw/Current All/;
@play_time = qw/1 0.5 0.25 0.1/;
#@pvalues = qw/0.1 0.05  0.01 0.001/;
@filter_choices = qw/~ !~ --- = != > < >= <= --- >< >=< ><= >=<= --- <> <=> <>= <=>=/;
@filter_to_file = qw/match nomatch --- equal_to different_from greater_than lower_than greater=_than lower=_than --- within within_lower_included within_higher_included within_included ---  outside outside_lower_included outside_higher_included outside_included/;
@res_choices = qw/res_abs res_ratio res_groups_abs res_groups_ratio/;
@cod_choices = qw/cod_ratio cod_bias/;
@go_type_choice = qw/code name/;
@go_mode_choice = qw/raw perc/;
$go_what = 'code';
$go_mode = 'perc';
$go_count = 10;
$mw = MainWindow->new(-title=>'AAstretch - AAexplorer - by matteo.ramazzotti@unifi.it 2017');
$mw->Tk::bind('<MouseWheel>' => '');
$frame1 = $mw->Frame->pack(-fill=>'both');

$frame1_sub1 = $frame1->Labelframe(-text=>'File', -pady=>5, -padx=>5)->pack(-side=>'left', -fill=>'both');
$frame1_sub1a = $frame1_sub1->Labelframe(-text=>'Input/output', -pady=>5, -padx=>5)->pack(-side=>'top', -fill=>'both');
$frame1_sub1b = $frame1_sub1->Labelframe(-text=>'Background', -pady=>5, -padx=>5)->pack(-side=>'bottom', -fill=>'both');
$frame1_sub1a->Button(-text=>'Load new file', -command=>sub {fileselect('new')})->pack(-side=>'left',-fill=>'both');
$frame1_sub1a->Button(-text=>'Save Current graphs', -command=>sub {save('current')})->pack(-side=>'left',-fill=>'both');
$frame1_sub1a->Button(-text=>'Save All graphs', -command=>sub {save('all')})->pack(-side=>'left',-fill=>'both');
$frame1_sub1b->Radiobutton(-text=>'Glob', -variable=>\$background, -value=>'glob', -command=>sub {&change_background;&refresh})->pack(-side=>'left',-fill=>'both');
$frame1_sub1b->Radiobutton(-text=>'Full', -variable=>\$background, -value=>'full', , -command=>sub {&change_background;&refresh})->pack(-side=>'left',-fill=>'both');
$frame1_sub1b->Radiobutton(-text=>'Purged', -variable=>\$background, -value=>'purged', , -command=>sub {&change_background;&refresh})->pack(-side=>'left',-fill=>'both');
$frame1_sub1b->Checkbutton(-text=>'Disable 1st M', -variable=>\$firstM_, -onvalue=>1, -offvalue=>0, , -command=>sub {&change_background;&refresh})->pack(-side=>'left',-fill=>'both');
#$frame1_sub2->BrowseEntry(-width=>8, -label=>'Save', -variable=>\$savewhat, -browsecmd=>\&savewhat,-choices=>\@save)->pack();

$frame1_sub2 = $frame1->Labelframe(-text=>'Visualization', -pady=>5, -padx=>5)->pack(-side=>'left', -fill=>'both');
$frame1_sub2a = $frame1_sub2->Labelframe(-text=>'Y-axis control', -pady=>5, -padx=>5)->pack(-side=>'top', -fill=>'both');
$frame1_sub2b = $frame1_sub2->Labelframe(-text=>'Graph mode', -pady=>5, -padx=>5)->pack(-side=>'bottom', -fill=>'both');
$frame1_sub2a->Radiobutton(-text=>'Counts', -variable=>\$type, -value=>'raw')->pack(-side=>'left', -anchor=>'nw');
$frame1_sub2a->Radiobutton(-text=>'Percent', -variable=>\$type, -value=>'perc')->pack(-side=>'left', -anchor=>'nw');
#$br_ent1 = $frame1_sub2a->BrowseEntry(-width=>3, -label=>'Tuple:', -variable=>\$tuple, -browsecmd=>\&refresh)->pack(-side=>'left', -anchor=>'nw');
$frame1_sub2a->Label(-text=>'Threshold')->pack(-side=>'left', -fill=>'both');
$frame1_sub2a->Entry(-width=>4, -textvariable=>\$ratio_t)->pack(-side=>'left', -fill=>'both');
$frame1_sub2a->Button(-text=>'Refresh', -command=>\&refresh)->pack(-side=>'right', -fill=>'both');
$frame1_sub2b->BrowseEntry(-label=>'Residue',-width=>10, -variable=>\$graph_mode, choices=>\@res_choices, -browsecmd=>\&fileload)->pack(-side=>'left', -anchor=>'nw');
$frame1_sub2b->BrowseEntry(-label=>'Codons',-width=>10, -variable=>\$graph_mode, choices=>\@cod_choices, -browsecmd=>\&fileload)->pack(-side=>'left', -anchor=>'nw');

$frame1_sub3 = $frame1->Labelframe(-text=>'Selection', -pady=>5, -padx=>5)->pack(-side=>'left', -fill=>'both');
$frame1_sub3a = $frame1_sub3->Labelframe(-text=>'Stretch length', -pady=>5, -padx=>5)->pack(-side=>'top', -fill=>'both');
$frame1_sub3b = $frame1_sub3->Labelframe(-text=>'Filter', -pady=>5, -padx=>5)->pack(-side=>'bottom', -fill=>'both', -anchor=>'nw');
$br_ent3 = $frame1_sub3a->BrowseEntry(-width=>3, -label=>'Stretch size from', -variable=>\$len1)->pack(-side=>'left');
$br_ent4 = $frame1_sub3a->BrowseEntry(-width=>3, -label=>'to', -variable=>\$len2)->pack(-side=>'left');
$frame1_sub3a->Button(-text=>'Select', -command=>\&refresh)->pack(-side=>'left');
$br_ent5 = $frame1_sub3b->BrowseEntry(-width=>15,-textvariable=>\$filter_on, -state=>'disabled')->pack(-side=>'left');
$br_ent6 = $frame1_sub3b->BrowseEntry(-width=>3,-textvariable=>\$filter_mode, -choices=>\@filter_choices)->pack(-side=>'left');
$ent1 = $frame1_sub3b->Entry(-width=>15, -textvariable=>\$filter)->pack(-side=>'left');
$filt_but = $frame1_sub3b->Button(-text=>'Filter', -command=>sub {$lock_button->configure(-state=>'normal');&refresh})->pack(-side=>'left');
$lock_button = $frame1_sub3b->Checkbutton(-text=>'Lock', -variable=>\$filter_lock, -onvalue=>1, -command=>\&filter_lock, -state=>'disabled')->pack(-side=>'left');

$frame1_sub4 = $frame1->Labelframe(-text=>'Records', -pady=>5, -padx=>5)->pack(-side=>'left', -fill=>'both');
$frame1_sub4->Label(-textvariable=>\$record_label)->pack();

$frame2 = $mw->Frame->pack(-fill=>'both');
$nb = $frame2->NoteBook()->pack(-fill=>'both');
$lab_1 = $frame2->Label(-text=>'Bin');
$bin_1 = $frame2->Entry(-width=>3, -textvariable=>\$bin1); $bin1 = 1;
$update_but_1 = $frame2->Button(-text=>'Update', -command=>\&create_res_summary);
$bin_2 = $frame2->Entry(-width=>3, -textvariable=>\$bin2); $bin2 = 1;
$update_but_2 = $frame2->Button(-text=>'Update', -command=>\&create_cod_summary);

$st_poly_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$st_poly_res, -browsecmd=>sub {update_poly_res('st')});
$gap_poly_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$gap_poly_res, -browsecmd=>sub {update_poly_res('gap')});
$lf_poly_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$lf_poly_res, -browsecmd=>sub {update_poly_res('lf')});
$rf_poly_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$rf_poly_res, -browsecmd=>sub {update_poly_res('rf')});
$ff_poly_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$ff_poly_res, -browsecmd=>sub {update_poly_res('ff')});
$st_topo_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$st_topo_res, -browsecmd=>sub {update_topology('st')});
$gap_topo_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$gap_topo_res, -browsecmd=>sub {update_topology('gap')});
$lf_topo_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$lf_topo_res, -browsecmd=>sub {update_topology('lf')});
$rf_topo_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$rf_topo_res, -browsecmd=>sub {update_topology('rf')});
$ff_topo_selector = $frame2->BrowseEntry(-width=>8, -label=>'Residue:', -variable=>\$ff_topo_res, -browsecmd=>sub {update_topology('ff')});

$st_poly_log_label = $frame2->Label(-text=>'Log');
$gap_poly_log_label = $frame2->Label(-text=>'Log');
$lf_poly_log_label = $frame2->Label(-text=>'Log');
$rf_poly_log_label = $frame2->Label(-text=>'Log');
$ff_poly_log_label = $frame2->Label(-text=>'Log');
$st_topo_log_label = $frame2->Label(-text=>'Log');
$gap_topo_log_label = $frame2->Label(-text=>'Log');
$lf_topo_log_label = $frame2->Label(-text=>'Log');
$rf_topo_log_label = $frame2->Label(-text=>'Log');
$ff_topo_log_label = $frame2->Label(-text=>'Log');

$st_poly_log = $frame2->Checkbutton(-onvalue=> 'l', -offvalue=>'0', -variable=>\$st_poly_islog, -command=>sub {update_poly_res('st')});
$gap_poly_log = $frame2->Checkbutton(-onvalue=> '1', -offvalue=>'0', -variable=>\$gap_poly_islog, -command=>sub {update_poly_res('gap')});
$lf_poly_log = $frame2->Checkbutton(-onvalue=> '1', -offvalue=>'0', -variable=>\$lf_poly_islog, -command=>sub {update_poly_res('lf')});
$rf_poly_log = $frame2->Checkbutton(-onvalue=> '1', -offvalue=>'0', -variable=>\$rf_poly_islog, -command=>sub {update_poly_res('rf')});
$ff_poly_log = $frame2->Checkbutton(-onvalue=> '1', -offvalue=>'0', -variable=>\$ff_poly_islog, -command=>sub {update_poly_res('ff')});
$st_topo_log = $frame2->Checkbutton(-onvalue=> 'l', -offvalue=>'0', -variable=>\$st_topo_islog, -command=>sub {update_topology('st')});
$gap_topo_log = $frame2->Checkbutton(-onvalue=> '1', -offvalue=>'0', -variable=>\$gap_topo_islog, -command=>sub {update_topology('gap')});
$lf_topo_log = $frame2->Checkbutton(-onvalue=> '1', -offvalue=>'0', -variable=>\$lf_topo_islog, -command=>sub {update_topology('lf')});
$rf_topo_log = $frame2->Checkbutton(-onvalue=> '1', -offvalue=>'0', -variable=>\$rf_topo_islog, -command=>sub {update_topology('rf')});
$ff_topo_log = $frame2->Checkbutton(-onvalue=> '1', -offvalue=>'0', -variable=>\$ff_topo_islog, -command=>sub {update_topology('ff')});

$st_poly_play = $frame2->Button(-text=>'Play', -command=>sub {poly_play('st')});
$gap_poly_play = $frame2->Button(-text=>'Play', -command=>sub {poly_play('gap')});
$lf_poly_play = $frame2->Button(-text=>'Play', -command=>sub {poly_play('lf')});
$rf_poly_play = $frame2->Button(-text=>'Play', -command=>sub {poly_play('rf')});
$ff_poly_play = $frame2->Button(-text=>'Play', -command=>sub {poly_play('ff')});
$st_topo_play = $frame2->Button(-text=>'Play', -command=>sub {topo_play('st')});
$gap_topo_play = $frame2->Button(-text=>'Play', -command=>sub {topo_play('gap')});
$lf_topo_play = $frame2->Button(-text=>'Play', -command=>sub {topo_play('lf')});
$rf_topo_play = $frame2->Button(-text=>'Play', -command=>sub {topo_play('rf')});
$ff_topo_play = $frame2->Button(-text=>'Play', -command=>sub {topo_play('ff')});

$st_poly_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$st_p_play_time, -choices=>\@play_time);
$gap_poly_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$gap_p_play_time, -choices=>\@play_time);
$lf_poly_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$lf_p_play_time, -choices=>\@play_time);
$rf_poly_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$rf_p_play_time, -choices=>\@play_time);
$ff_poly_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$ff_p_play_time, -choices=>\@play_time);
$st_topo_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$st_t_play_time, -choices=>\@play_time);
$gap_topo_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$gap_t_play_time, -choices=>\@play_time);
$lf_topo_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$lf_t_play_time, -choices=>\@play_time);
$rf_topo_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$rf_t_play_time, -choices=>\@play_time);
$ff_topo_play_time = $frame2->BrowseEntry(-width=>5, -label=>'sec', -variable=>\$ff_t_play_time, -choices=>\@play_time);

$summary_res_page = $nb->add("summary_res", -label=>'Residue Summary');
$summary_cod_page = $nb->add("summary_cod", -label=>'Codon Summary');
$summary_res_canvas = $summary_res_page->Canvas(-width=>850, height=>650)->pack(-fill=>'both');
$summary_res_canvas->Tk::bind('<Shift-Button-1>' => sub{printout_one($summary_res_canvas)});
$summary_res_canvas->Tk::bind('<Double-Button-1>' => sub{get_data($summary_res_canvas)});
$summary_cod_canvas = $summary_cod_page->Canvas(-width=>850, height=>650)->pack(-fill=>'both');
$summary_cod_canvas->Tk::bind('<Shift-Button-1>' => sub{printout_one($summary_cod_canvas)});
$summary_cod_canvas->Tk::bind('<Double-Button-1>' => sub{get_data($summary_cod_canvas)});
$st_page = $nb->add("stretch", -label=>'Stretches');
$st_canvas = $st_page->Canvas(-width=>850, height=>650)->pack(-fill=>'both');
$st_canvas->Tk::bind('<Shift-Button-1>' => sub{printout_one($st_canvas)});
$st_canvas->Tk::bind('<Double-Button-1>' => sub{get_data($st_canvas)});
$gap_page = $nb->add("gaps", -label=>'Gaps');
$gap_canvas = $gap_page->Canvas(-width=>850, height=>650)->pack(-fill=>'both');
$gap_canvas->Tk::bind('<Shift-Button-1>' => sub{printout_one($gap_canvas)});
$gap_canvas->Tk::bind('<Double-Button-1>' => sub{get_data($gap_canvas)});
$lf_page = $nb->add("left", -label=>'Left flanks');
$lf_canvas = $lf_page->Canvas(-width=>850, height=>650)->pack(-fill=>'both');
$lf_canvas->Tk::bind('<Shift-Button-1>' => sub{printout_one($lf_canvas)});
$lf_canvas->Tk::bind('<Double-Button-1>' => sub{get_data($lf_canvas)});
$rf_page = $nb->add("right", -label=>'Right flanks');
$rf_canvas = $rf_page->Canvas(-width=>850, height=>650)->pack(-fill=>'both');
$rf_canvas->Tk::bind('<Shift-Button-1>' => sub{printout_one($rf_canvas)});
$rf_canvas->Tk::bind('<Double-Button-1>' => sub{get_data($rf_canvas)});
$ff_page = $nb->add("both", -label=>'Flanks');
$ff_canvas = $ff_page->Canvas(-width=>850, height=>650)->pack(-fill=>'both');
$ff_canvas->Tk::bind('<Shift-Button-1>' => sub{printout_one($ff_canvas)});
$ff_canvas->Tk::bind('<Double-Button-1>' => sub{get_data($ff_canvas)});

$go_page = $nb->add("go", -label=>'GO / MIM');
$go_frame1 = $go_page->Frame->pack(-fill=>'both',-expand=>'y',);
$go_frame2 = $go_page->Frame->pack(-fill=>'both',-expand=>'y',);
$go_selector = $go_frame1->BrowseEntry(-width=>9, -label=>'Data', -variable=>\$go_sel)->pack(-side=>'left');
$go_frame1->BrowseEntry(-width=>5, -label=>'Type', -variable=>\$go_what, -choices=>\@go_type_choice)->pack(-side=>'left');
$go_frame1->BrowseEntry(-width=>5, -label=>'Mode', -variable=>\$go_mode, -choices=>\@go_mode_choice)->pack(-side=>'left');
$go_frame1->Label(-text=>'Min count')->pack(-side=>'left');
$go_frame1->Entry(-width=>10, -textvariable=>\$go_count)->pack(-side=>'left');
$go_frame1->Button(-text=>'Update', -command=>\&go_analysis)->pack(-side=>'left');
$go_frame1->Button(-text=>'Get data', -command=>sub{get_data($go_canvas)})->pack(-side=>'right');
$go_frame1->Button(-text=>'Save graph', -command=>sub{printout_one($go_canvas)})->pack(-side=>'right');
$go_frame1->Label(-textvariable=>\$go_extrem_label)->pack(-side=>'left');
#$go_canvas = $go_frame2->Scrolled("Canvas", -width=>850, height=>650, -scrollbars=>'on')->pack(-fill=>'both');
$go_scroll = $go_frame2->Scrollbar(-orient =>'h', command=>\&go_scroll)->pack(-side=>'top',-fill=>'both'); 
$go_canvas = $go_frame2->Canvas(-width=>850, height=>650)->pack(-side=>'left', -fill=>'both');
$go_canvas->Tk::bind('<Shift-Button-1>' => sub{printout_one($go_canvas)});
$go_canvas->Tk::bind('<Double-Button-1>' => sub{get_data($go_canvas)});

$text_page = $nb->add("text", -label=>'Text');
$text_text = $text_page->Scrolled('Text', -wrap=>'none', -width=>'100', -scrollbars=>'nw', -font=>[-family => 'Courier', -size=>10])->pack(-expand=>'y', -fill=>'both');
$selected_page = $nb->add("selected", -label=>'Selected');
$selected_page->Label(-text=>'Currently plotted proteins');
$sel_f1 = $selected_page->Frame->pack(-side=>'left', -fill=>'both');
$sel_f2 = $selected_page->Frame->pack(-side=>'right', -fill=>'both');
$sel_f1->Label(-text=>'Currently selected proteins')->pack(-fill=>'both');
$selected_text1 = $sel_f1->Scrolled('Text', -wrap=>'none', -width=>'100', -scrollbars=>'nw', -font=>[-family => 'Courier', -size=>10])->pack(-fill=>'both', -expand=>'y');
$sel_f2->Label(-text=>'Currently selected graph data')->pack(-fill=>'both');
$selected_text2 = $sel_f2->Scrolled('Text', -wrap=>'none', -width=>'20', -scrollbars=>'nw', -font=>[-family => 'Courier', -size=>10])->pack(-fill=>'both', -expand=>'y');
$mw->resizable('0','0');
&initialize;
&fileselect;
MainLoop;

sub initialize {
	print "Initialize sub\n" if ($verbose);
	@res = ('G','P','D','E','R','K','V','I','L','M','A','W','Y','F','S','T','H','C','N','Q');
	@res_groups = ('KRH','DE','NSTQ','WYF','AVILM','G','P','C');
	@cods = sort qw /A-GCC S-AGT C-TGT R-CGA I-ATC N-AAC S-AGC Y-TAC S-TCG T-ACA P-CCG L-CTG A-GCA K-AAG V-GTG H-CAC V-GTT R-AGA T-ACC P-CCA W-TGG L-CTC R-CGC L-TTG Q-CAG T-ACG K-AAA M-ATG V-GTA L-CTT G-GGA V-GTC C-TGC S-TCA I-ATT Y-TAT N-AAT T-ACT D-GAC Q-CAA G-GGT S-TCC F-TTT R-AGG R-CGT I-ATA R-CGG H-CAT G-GGG P-CCC E-GAG L-TTA D-GAT L-CTA S-TCT F-TTC A-GCG G-GGC E-GAA A-GCT P-CCT _-TAA _-TAG _-TGA /;
	$type = 'perc';
	$graph_mode = 'res_ratio';
	foreach(@cods) {
		@tmp = split (/-/,$_);
		$codons{$tmp[0]} .= $_." ";
		$codons_t{$tmp[1]} = $_;
		$codons_of{$tmp[0]} .= $tmp[1]."|";
	}
	$st_p_play_time = 0.25; $lf_p_play_time = 0.25; $rf_p_play_time = 0.25; $ff_p_play_time = 0.25;
	$st_t_play_time = 0.25; $lf_t_play_time = 0.25; $rf_t_play_time = 0.25; $ff_t_play_time = 0.25;
	$st_poly_islog = 0; $gap_poly_islog = 0; $lf_poly_islog = 0; $rf_poly_islog = 0; $ff_poly_islog = 0;
	$st_topo_islog = 0; $gap_topo_islog = 0; $lf_topo_islog = 0; $rf_topo_islog = 0; $ff_topo_islog = 0;
}

sub fileselect {
	print "Fileselect sub\n" if ($verbose);
	my $mode = shift;
	$resfile = '';
	goto GR if ($mode && $mode eq 'new');
	$resfile = $ARGV[0] if ($ARGV[0] && -e $ARGV[0]);
	$resfile = cwd."/".$resfile if ($ARGV[0] && -e $ARGV[0]);
	GR:
 my $types = [
     ['AAstretch output',  ['*-AAstretch.txt']],
     ['text files',  ['.txt']],
	];
	$resfile = $mw->getOpenFile(-filetypes  => $types) if (!$resfile);
	return if (!$resfile);
	$codfile = $resfile;
	$codfile =~ s/\.txt/-cod.txt/;
#	$ratio_t = 0.05;
#	$ratio_t = $ARGV[1] if ($ARGV[0] && $ARGV[1]);
	@path = split (/[\\|\/]/,$resfile);
	pop @path;
	$path = join "\\",@path if ($^O =~ /^win/i);
	$path = join "\/",@path if ($^O !~ /^win/i);
	$mw->configure(-title=>'AAexplorer v1.0- by matteo.ramazzotti@unifi.it 2010 - '.$path);
	&fileload;
	$mw->focusForce;
}
sub alert {
	my $what = shift;
	$nb->configure(-foreground=>'red') if ($what eq 'block');
	$nb->configure(-foreground=>'black') if ($what eq 'free');
	$mw->update;
}

sub change_background {
	if ($background eq 'glob') {
		&background;
	}
	else {
		my $glob_alt_file = $path.'/outside.txt' if ($graph_mode =~ /res/ && $background eq 'purged'); 
		$glob_alt_file = $path.'/sequences.txt' if ($graph_mode =~ /res/ && $background eq 'full'); 
		$glob_alt_file = $path.'/outside-cod.txt' if ($graph_mode =~ /cod/ && $background eq 'purged'); 
		$glob_alt_file = $path.'/sequences-cod.txt' if ($graph_mode =~ /cod/ && $background eq 'full'); 
		my ($g1,$g2,$g3) = load_alt_background($glob_alt_file);
		%global_count = %$g1; # global background is loaded from storage
		%global_perc = %$g2;
		%global_perc_gap = %$g3;
	}
}
	
sub fileload {
	print "Fileload sub\n" if ($verbose);
	my $file = $resfile if ($graph_mode =~ /res/); 
	$file = $codfile if ($graph_mode =~ /cod/); 
	alert('block'); 
	load($file);
	&change_background if ($background ne 'glob');
	
	@res_gap = ();
	@cods_gap = ();
	@res_groups_gap = ();
	foreach(@res) { push (@res_gap,$_) if ($_ ne $residue);}
	foreach(@res_groups) { $_ =~ s/$residue//; push (@res_groups_gap,$_);}
	foreach(@cods) { push (@cods_gap,$_) if ($_ !~ /$residue-/);}
	
	$lf_poly_selector->configure(-choices=>\@res) if ($graph_mode =~ /res/);
	$lf_poly_selector->configure(-choices=>\@cods) if ($graph_mode =~ /cod/);
	$lf_poly_selector->configure(-choices=>\@res_groups) if ($graph_mode =~ /groups/);
	$rf_poly_selector->configure(-choices=>\@res) if ($graph_mode =~ /res/);
	$rf_poly_selector->configure(-choices=>\@cods) if ($graph_mode =~ /cod/);
	$rf_poly_selector->configure(-choices=>\@res_groups) if ($graph_mode =~ /groups/);
	$st_poly_selector->configure(-choices=>\@res) if ($graph_mode =~ /res/);
	$st_poly_selector->configure(-choices=>\@cods) if ($graph_mode =~ /cod/);
	$st_poly_selector->configure(-choices=>\@res_groups) if ($graph_mode =~ /groups/);
	$ff_poly_selector->configure(-choices=>\@res) if ($graph_mode =~ /res/);
	$ff_poly_selector->configure(-choices=>\@cods) if ($graph_mode =~ /cod/);
	$ff_poly_selector->configure(-choices=>\@res_groups) if ($graph_mode =~ /groups/);
	$gap_poly_selector->configure(-choices=>\@res_gap) if ($graph_mode =~ /res/);
	$gap_poly_selector->configure(-choices=>\@cods_gap) if ($graph_mode =~ /cod/);
	$gap_poly_selector->configure(-choices=>\@res_groups_gap) if ($graph_mode =~ /groups/);
	$lf_topo_selector->configure(-choices=>\@res) if ($graph_mode =~ /res/);
	$lf_topo_selector->configure(-choices=>\@cods) if ($graph_mode =~ /cod/);
	$lf_topo_selector->configure(-choices=>\@res_groups) if ($graph_mode =~ /groups/);
	$rf_topo_selector->configure(-choices=>\@res) if ($graph_mode =~ /res/);
	$rf_topo_selector->configure(-choices=>\@cods) if ($graph_mode =~ /cod/);
	$rf_topo_selector->configure(-choices=>\@res_groups) if ($graph_mode =~ /groups/);
	$st_topo_selector->configure(-choices=>\@res) if ($graph_mode =~ /res/);
	$st_topo_selector->configure(-choices=>\@cods) if ($graph_mode =~ /cod/);
	$st_topo_selector->configure(-choices=>\@res_groups) if ($graph_mode =~ /groups/);
	$ff_topo_selector->configure(-choices=>\@res) if ($graph_mode =~ /res/);
	$ff_topo_selector->configure(-choices=>\@cods) if ($graph_mode =~ /cod/);
	$ff_topo_selector->configure(-choices=>\@res_groups) if ($graph_mode =~ /groups/);
	$gap_topo_selector->configure(-choices=>\@res_gap) if ($graph_mode =~ /res/);
	$gap_topo_selector->configure(-choices=>\@cods_gap) if ($graph_mode =~ /cod/);
	$gap_topo_selector->configure(-choices=>\@res_groups_gap) if ($graph_mode =~ /groups/);

	$br_ent5->configure(-choices=>\@filters, -state=>'normal');

	if ($graph_mode =~ /res/) {
#		@gap_res = ();
#		foreach (@res) {
#			push(@gap_res, $_) if ($_ ne $residue);
#		}
#		$gap_topo_selector->configure(-choices=>\@gap_res) if ($graph_mode !~ /res/
#		$gap_poly_selector->configure(-choices=>\@gap_res);
		$gap_poly_res = $res_gap[0];
		$gap_topo_res = $res_gap[0];
		$st_poly_res = $residue;
		$lf_poly_res = $residue; 
		$rf_poly_res = $residue; 
		$ff_poly_res = $residue; 
		$st_topo_res = $residue;
		$lf_topo_res = $residue; 
		$rf_topo_res = $residue; 
		$ff_topo_res = $residue;
	}
	if ($graph_mode =~ /cod/) {
#		@gap_cods = ();
#		foreach (@cods) {
#			@tmp = split (/-/,$_);
#			push(@gap_cods, $_) if ($tmp[0] ne $residue);
#		}
#		$gap_topo_selector->configure(-choices=>\@gap_cods);
#		$gap_poly_selector->configure(-choices=>\@gap_cods);
		$gap_poly_res = $cods_gap[0];
		$gap_topo_res = $cods_gap[0];
		@tmp = split (/ /,$codons{$residue});
		$st_poly_res = $tmp[0];
		$lf_poly_res = $tmp[0]; 
		$rf_poly_res = $tmp[0]; 
		$ff_poly_res = $tmp[0]; 
		$st_topo_res = $tmp[0];
		$lf_topo_res = $tmp[0]; 
		$rf_topo_res = $tmp[0]; 
		$ff_topo_res = $tmp[0];
		$tuple = 1;
	}
	$mw->update;
	&refresh;
}

sub refresh {
	alert('block'); 
	print "Refresh sub\n" if ($verbose);
	&scan;
	$ent1->configure(-background=>'red') if (scalar @st_seq_ok == 0); 
	$ent1->configure(-background=>'white') if (scalar @st_seq_ok > 0); 
	return if (scalar @st_seq_ok == 0);
	&create_data;
	&create_res_summary if ($graph_mode =~ /res/);
	&create_cod_summary if ($graph_mode =~ /cod/);
	&create_graph;
	&plot;
	update_poly_res('st');
	update_poly_res('gap');
	update_poly_res('lf');
	update_poly_res('rf');
	update_poly_res('ff');
	update_topology('st');
	update_topology('gap');
	update_topology('lf');
	update_topology('rf');
	update_topology('ff');
	print "--------------\n" if ($verbose);
	alert('free');
	&associate;
	&go_analysis;
}

sub my_open {
	print "myopen sub\n" if ($verbose);
	my $file = shift;
	my $in = '';
	my @in = ();
	$/ = undef;
	open (FILE, $file);
	$in = <FILE>;
	close (FILE);
	$in =~ s/\"//g; 
	@in = split (/(?:\015{1,2}\012|\015|\012)/, $in);
	$/ = "\n";
	return \@in;
}

sub load_alt_background {
	print "load_alt_background sub\n" if ($verbose);
	my $file = shift;
	$newdata = my_open($file);	
	@in = @$newdata;
	my @glob_alt_seq = ();
	$alt_firstM = 0;
	foreach (@in) {
		next if ($_ =~ />/);
		push (@glob_alt_seq, $_);
		$alt_firstM++ if ($graph_mode =~ /res/ && $_ =~ /^M/);
		$alt_firstM++ if ($graph_mode =~ /cod/ && $_ =~ /^ATG/);
	}
#	print "$firstM, $alt_firstM\n";
	my ($glob_alt_cnt,$glob_alt_tot) = counter(\@glob_alt_seq,$tuple,'st');
	my ($glob_alt_gap_cnt,$glob_alt_gap_tot) = counter(\@glob_alt_seq,$tuple,'gap');
	my $res;
	my %glob_alt_cnt = %$glob_alt_cnt;
	my %glob_alt_gap_cnt = %$glob_alt_gap_cnt;
	my %global_alt_count = ();
	my %global_alt_perc = ();
	my %global_alt_perc_gap = ();
	my %already = ();
	$glob_alt_tot -= $alt_firstM if ($firstM_);
	$glob_alt_gap_tot -= $alt_firstM if ($firstM_);
	$glob_alt_cnt{'M'} -= $alt_firstM if ($firstM_ && $graph_mode =~ /res/);
	$glob_alt_cnt{'M-ATG'} -= $alt_firstM if ($firstM_ && $graph_mode =~ /cod/);
	$glob_alt_gap_cnt{'M'} -= $alt_firstM if ($firstM_ && $graph_mode =~ /res/);
	$glob_alt_gap_cnt{'M-ATG'} -= $alt_firstM if ($firstM_ && $graph_mode =~ /cod/);
	if ($graph_mode =~ /groups/) {
		foreach(keys %glob_alt_cnt) {
			$already{$_} = 1; # the residues have been already counted in counter sub
		}
		foreach my $seq (@glob_alt_seq) { #also in groups mode, single residue counts are needed to allow topology plots... 
			while ($seq =~ /(.)/g) {
				$res = $1;
				next if ($already{$res});
				$glob_alt_cnt{$res}++;
				$glob_alt_gap_cnt{$res}++ if ($res ne $residue);
			}
		}
	}
	foreach(keys %glob_alt_cnt) {
		$global_alt_count{$tuple.'@'.$_} = $glob_alt_cnt{$_};
		$global_alt_perc{$tuple.'@'.$_} = sprintf("%.2f",$glob_alt_cnt{$_}/$glob_alt_tot*100);
		$global_alt_perc_gap{$tuple.'@'.$_} = sprintf("%.2f",$glob_alt_gap_cnt{$_}/$glob_alt_gap_tot*100) if ($_ ne $residue);
		$global_alt_perc_gap{$tuple.'@'.$_} = 0 if ($_ eq $residue);
		print $_,"\t",$global_alt_perc{$tuple.'@'.$_},"\t",$global_alt_perc_gap{$tuple.'@'.$_},"\n";
		
	}
	return \%global_alt_count,\%global_alt_perc,\%global_alt_perc_gap;
}

sub background {
	undef %global_sum;
	undef %global_count;
	undef %global_perc;
	undef %global_vals;
	undef %global_sum_gap;
	undef %global_perc_gap;
	@glob_lab = @res if ($graph_mode =~ /res/);
	@glob_lab = @cods if ($graph_mode =~ /cod/);
	foreach (0..$#glob_lab) {
		$global_sum{$tup_ind} += $global_vals[$_];
		$global_sum_gap{$tup_ind} += $global_vals[$_] if ($glob_lab[$_] ne $residue && $graph_mode =~ /res/);
		$global_sum_gap{$tup_ind} += $global_vals[$_] if ($glob_lab[$_]  !~ /^$residue-/ && $graph_mode =~ /cod/);
		$global_vals{$glob_lab[$_]} = $global_vals[$_];
	}
	# 8/10/2010 correction for 1st M (ATG)
	$global_sum{$tup_ind} -= $firstM if ($firstM_);
	$global_sum_gap{$tup_ind} -= $firstM*$firstM_ if ($firstM_);
	$global_vals{'M'} -= $firstM if ($firstM_ && $graph_mode =~ /res/);
	$global_vals{'M-ATG'} -= $firstM if ($firstM_ && $graph_mode =~ /res/);
	
	foreach (0..$#glob_lab) {
		$global_count{$tup_ind.'@'.$glob_lab[$_]} = $global_vals{$glob_lab[$_]};
		$global_perc{$tup_ind.'@'.$glob_lab[$_]} = sprintf("%.2f",$global_vals{$glob_lab[$_]}/$global_sum{$tup_ind}*100);
		$global_perc_gap{$tup_ind.'@'.$glob_lab[$_]} = sprintf("%.2f",$global_vals{$glob_lab[$_]}/$global_sum_gap{$tup_ind}*100) if ($glob_lab[$_] ne $residue && $graph_mode =~ /res/);
		$global_perc_gap{$tup_ind.'@'.$glob_lab[$_]} = sprintf("%.2f",$global_vals{$glob_lab[$_]}/$global_sum_gap{$tup_ind}*100) if ($glob_lab[$_]  !~ /^$residue-/ && $graph_mode =~ /cod/);
		$global_perc_gap{$tup_ind.'@'.$glob_lab[$_]} = 0 if ($glob_lab[$_] eq $residue && $graph_mode =~ /res/);
		$global_perc_gap{$tup_ind.'@'.$glob_lab[$_]} = 0 if ($glob_lab[$_]  =~ /^$residue-/ && $graph_mode =~ /cod/);
	}
	if ($graph_mode =~ /groups/) {
		foreach my $glab (0..$#labels) {
			@tmp = split (//,$labels[$glab]);
			next if ($global_count{$tup_ind.'@'.$labels[$glab]});
			foreach (@tmp) {
				$global_count{$tup_ind.'@'.$labels[$glab]} += $global_vals{$_};
			}
			$global_perc{$tup_ind.'@'.$labels[$glab]} = sprintf("%.2f",$global_count{$tup_ind.'@'.$labels[$glab]}/$global_sum{$tup_ind}*100);
			$global_perc_gap{$tup_ind.'@'.$labels[$glab]} = sprintf("%.2f",$global_count{$tup_ind.'@'.$labels[$glab]}/$global_sum_gap{$tup_ind}*100);
		}
	}
}

sub load {
	print "load sub\n" if ($verbose);
	my $file = shift;
	$newdata = my_open($file);	
	@in = @$newdata;
	if ($file =~ /-cod/) {
		@labels = @cods;	
	}
	if ($file !~ /-cod/) {
		@labels = @res;
		@labels = @res_groups if ($graph_mode =~ /groups/);
	}
	
	@tuples = ();

	undef %records;
	undef %is_record;
	undef $records;
	undef %st_data;
	undef %lf_data;
	undef %rf_data;
	undef %ff_data;
	undef $count_start;
	undef $pure_col;
	undef $name_col;
	undef $res_perc_col;
	undef $position_col;
	undef %lf_seq;
	undef %rf_seq;
	undef %st_seq;
	@stretch_x = ();
	@stretch_y = ();
	@position = ();
	@pure_cod = ();
	@keynames = ();
	@st_seq = ();
	@lf_seq = ();
	@rf_seq = ();
	@filters = ();
	%filters_ind = ();
	@to_be_filtered = ();
	@glob_lab = ();
	$headers = '';
	$records_tot = 0;
	@go_type_list = ();
#	@prot_lengths = ();
	foreach $row (0..$#in) { #scans the file header collecting globals, tuples and the row start for data
		$line = $in[$row];
#		$line =~ s/[\/|\\]/-/g;
		chomp $line;
		if ($line =~ /^residue/i) {
			$residue = $line;
			$residue =~ s/residue\t//i;
#			if ($graph_mode =~ /cod/) {
#				@tmp = split (/ /,$codons{$residue});
#				$residue = $tmp[0];
#			}
		}
		if ($line =~ /flank_length/i) {
			$flank_length = $line;
			$flank_length =~ s/flank_length\t//i;
		}
		if ($line =~ /...._gap_max_size/i) {
			$gap_max_size = $line;
			$gap_max_size =~ s/...._gap_max_size\t//i;
		}
		
		if ($line =~ /global_stat_tup_1/i) { #catch the global counts and assign lables and computed percentages
			@global_vals = split(/\t/,$line);
			$tup_ind = shift @global_vals;
			$tup_ind =~ s/global_stat_tup_//i;
			&background;
		}	
		if ($line =~ /^1st-M/i) {
			$firstM = $line;
			$firstM =~ s/1st-M\t//;
		}
		if ($line =~ /Name\tLen/i) { #this is the line before data start
			$headers = $line;
			@headers = split(/\t/,$line);
			foreach $head (0..$#headers) { #this cycle searches for interesting columns
				$lab = $headers[$head];
				if ($lab =~ /stretch_len/i) { #where the stretch_len is positioned
					$st_col = $head;
				}
				if ($lab =~ /stretch_seq/i) { #where the stretch_len is positioned
					$st_seq_col = $head;
				}
				if ($lab =~ /Name/i) { #where the stretch_len is positioned
					$name_col = $head;
				}
				if ($lab =~ /pure_homo/i) { #where the stretch_len is positioned
					$pure_col = $head;
				}
				if ($lab =~ /^$residue/i) { #where the Q% is positioned
					$res_perc_col = $head;
				}
				if ($lab =~ /position/i) { #where the Q% is positioned
					$position_col = $head;
				}
				if ($lab =~ /lf_seq/i) { #where the Q% is positioned
					$lf_seq_col = $head;
				}
				if ($lab =~ /rf_seq/i) { #where the Q% is positioned
					$rf_seq_col = $head;
				}
				if ($lab =~ /st_tup/) { 
					$lab =~ s/st_tup//;
					push (@tuples, $lab); #tuple number is stored in the @tuples array !!!
					$count_start = $head;# if (!$count_start); #where the counts start
#					print "START: $count_start\n  $lab\n  $head\n";
#					<>;
				}
				$tup_number = scalar @tuples;
				push (@filters, $lab); #if ($lab =~ /name/i || $lab =~ /seq/i || $lab =~ /go/i);
				push (@filters, 'ff_seq') if ($lab =~ /rf_seq/i);
				$filters_ind{$lab} = $head;# if ($lab =~ /name/i || $lab =~ /seq/i || $lab =~ /go/i);
				$filters_ind{'ff_seq'} = $lf_seq_col.".".$rf_seq_col if ($lab =~ /rf_seq/i);
				if ($lab =~ /go_/i) {
					$go_func_col = $head+1 if ($lab =~ /func/);
					push (@go_type_list,'go_func') if ($lab =~ /func/);
					$go_proc_col = $head+1 if ($lab =~ /proc/);
					push (@go_type_list,'go_proc') if ($lab =~ /proc/);
					$go_comp_col = $head+1 if ($lab =~ /comp/);
					push (@go_type_list,'go_comp') if ($lab =~ /comp/);
				}
				if ($lab =~ /omim/i) { 
					$omim_col = $head+1;
					push (@go_type_list,'omim');
				}
			}
			$count_start -= $#tuples;
		}
		if ($line =~ /^>/) {
			my @tmp = split (/\t/,$line); #splits the data line in tabs 
			$tmp[$st_col] = $tmp[$st_col]/3 if ($graph_mode =~ /cod/);
			foreach $tup (@tuples) { #accumulates the data indexed by tuple and stratech length for faster data usage
				$tempor = $count_start+$tup-1;
				$st_data{$tup.'@'.$tmp[$st_col]} .= $tmp[$tempor]."&";
				$lf_data{$tup.'@'.$tmp[$st_col]} .= $tmp[$tup_number*1+$tempor]."&";
				$rf_data{$tup.'@'.$tmp[$st_col]} .= $tmp[$tup_number*2+$tempor]."&";
				$ff_data{$tup.'@'.$tmp[$st_col]} .= $tmp[$tup_number*3+$tempor]."&";
			}
			$is_record{$tmp[$st_col]} = 1; #just for indexing the length of ther stratches and build the summary
#			if ($graph_mode =~ /res/) {
				$lf_seq{$tmp[$st_col]} .= $tmp[$lf_seq_col]."&"; #just for indexing the length of ther stratches and build the summary
				$rf_seq{$tmp[$st_col]} .= $tmp[$rf_seq_col]."&"; #just for indexing the length of ther stratches and build the summary
				$st_seq{$tmp[$st_col]} .= $tmp[$st_seq_col]."&"; #just for indexing the length of ther stratches and build the summary
#			}
			$records_tot++;
			push(@to_be_filtered,$records_tot."\t".$line) if ($st_col);
			push(@stretch_x,$tmp[$st_col]) if ($st_col);
			push(@stretch_y,$tmp[$res_perc_col]) if ($res_perc_col);
			push(@st_len,$tmp[$st_col]) if ($st_col);
			push(@st_seq,$tmp[$st_seq_col]) if ($st_seq_col);
			push(@lf_seq,$tmp[$lf_seq_col]) if ($lf_seq_col);
			push(@rf_seq,$tmp[$rf_seq_col]) if ($rf_seq_col);
			push(@position,$tmp[$position_col]) if ($position_col);
			push(@pure_cod,$tmp[$pure_col]) if ($pure_col);
			@name = split(/\|/,$tmp[$name_col]);
			push(@keynames,$name[0]); 
#			$records{$tmp[$st_col]}++; #records are the length of the stretches
#			$records{'All'}++;
		}
	}
#	print "\n\n",$st_data{'1@33'}, "\n--------\n", $ff_data{'2@33'},"\n\n";
#	sleep 50;
	# this fills the browsentries in GUI
	@choices = sort {$a <=> $b} keys %is_record;
	unshift(@choices,'All');
#	$br_ent1->configure(-choices=>\@tuples);
	$br_ent3->configure(-choices=>\@choices);
	$br_ent4->configure(-choices=>\@choices);
	$go_selector->configure(-choices=>\@go_type_list);
	$len1 = $choices[0];
	$len2 = $choices[0];
	$go_sel = $go_type_list[0];
}

sub create_res_summary {
	print "Create_res_summary sub\n" if ($verbose);
	undef @summary_x;
	undef @summary_y;
	undef $summary1_gr;
	undef $summary1_img;
	undef $summary1_plot;
#	undef $summary2_gr;
	undef $summary2_img;
	undef $summary2_plot;
#	undef $summary3_gr;
	undef $summary3_img;
	undef $summary3_plot;
	$summary_res_canvas->delete('all');
	foreach (sort {$a <=> $b} keys %records) {
		next if ($_ eq 'All');
		#@summary_x contains stretch lengths, @summary_y contains 
		push (@summary_x,$_);
		push (@summary_y,$records{$_});
	}
	
	($summary_x,$summary_y) = binner(\@summary_x,\@summary_y,$bin1);
	@summary_x = @$summary_x;
	@summary_y = @$summary_y;

	$summary1_init{'x_label'} = "Length of stretch (bin $bin1)";
	$summary1_init{'y_label'} = "Counts";
	$summary1_init{'x_tick_number'} = 10;
	$summary1_init{'t_margin'} = 1;
	$summary1_init{'b_margin'} = 1;
	$summary1_init{'l_margin'} = 1;
	$summary1_init{'r_margin'} = 1;
	$summary1_init{'title'} = "distribution of stretch lengths";
	$summary1_gr = GD::Graph::bars->new(400, 300);
	$summary1_gr->set(%summary1_init);
	$summary1_gr = giantize($summary1_gr);
	@summary1_data = (\@summary_x,\@summary_y);
	$summary1_plot = $summary1_gr->plot(\@summary1_data);	
	$summary1_img = $mw->Photo(-format=>'GIF', -data=>$summary1_plot->gif);
	$summary_res_canvas->createImage(20,40,-tags=>'sumres1',-image=>$summary1_img, -anchor=>'nw');
	$summary_res_canvas->createWindow(20,20,-window=>$lab_1);
	$summary_res_canvas->createWindow(60,20,-window=>$bin_1);
	$summary_res_canvas->createWindow(110,20,-window=>$update_but_1);
	@summary2_data = (\@stretch_len_ok,\@stretch_y_ok);
	$summary2_plot = scatter(\@stretch_len_ok,\@stretch_y_ok,"Effect of stretch length on gaps",'Stretch length',"$residue % in the stretch");
	$summary2_img = $mw->Photo(-format=>'GIF', -data=>$summary2_plot);#->draw('gif'));
	$summary_res_canvas->createImage(440,20,-tags=>'sumres2',-image=>$summary2_img, -anchor=>'nw');
	@summary3_data = (\@stretch_len_ok,\@position_ok);
	$summary3_plot = scatter(\@stretch_len_ok,\@position_ok,"Stretch localization",'Stretch length',"Position percent");
	$summary3_img = $mw->Photo(-format=>'GIF', -data=>$summary3_plot);#->draw('gif'));
	
	$summary_res_canvas->createImage(15,330,-tags=>'sumres3',-image=>$summary3_img, -anchor=>'nw');
}

sub scatter { #this returns an image, since each time the draw command is launched new graphs are overlapped in the same image
	my $x = shift;
	my $y = shift;
	my $title = shift;
	my $x_label = shift;
	my $y_label = shift;
	my $plot = ();
    $plot = mylib::myPlot->new (450, 320);
    $plot->setGraphOptions ('horGraphOffset' => 50,
                           'vertGraphOffset' => 10,
                           'title' => $title,
                           'horAxisLabel' => $x_label,
                           'vertAxisLabel' => $y_label,
							);
   $plot->setData ($x,$y,'Points Noline Red');
   $img = $plot->draw('gif');
 	return $img;
}


sub create_cod_summary {
	print "Create_cod_summary sub\n" if ($verbose);
	$summary_cod_canvas->delete('all');
	$bin_mode = 1;
	if ($bin_mode == 1) {
		($summary_cod_x,$summary_cod_y) = simple_binner(\@pure_cod_ok,$bin2);
		@summary_cod_x = @$summary_cod_x;
		@summary_cod_y = @$summary_cod_y;
		foreach (0..$#summary_cod_x) {
#			print "$summary_cod_x[$_] -> $summary_cod_x[$_]\n";
		}
	}
	$summary_cod1_init{'x_label'} = "% pure codon (bin $bin2)";
	$summary_cod1_init{'y_label'} = "Counts";
	$summary_cod1_init{'x_tick_number'} = 'auto';
	$summary_cod1_init{'title'} = "distribution of pure codon in stretches";
	$summary_cod1_gr = GD::Graph::bars->new(400, 300);
	$summary_cod1_gr->set(%summary_cod1_init);
	$summary_cod1_gr = giantize($summary_cod1_gr);
	@summary_cod1_data = (\@summary_cod_x,\@summary_cod_y);
	$summary_cod1_plot = $summary_cod1_gr->plot(\@summary_cod1_data);
	$summary_cod1_img = $mw->Photo(-format=>'GIF', -data=>$summary_cod1_plot->gif);
	$summary_cod_canvas->createImage(20,40,-tags=>'sumcod1',-image=>$summary_cod1_img, -anchor=>'nw');
	$summary_cod_canvas->createWindow(20,20,-window=>$lab_1);
	$summary_cod_canvas->createWindow(60,20,-window=>$bin_2);
	$summary_cod_canvas->createWindow(110,20,-window=>$update_but_2);
	@summary_cod2_data = (\@stretch_len_ok,\@pure_cod_ok);
	$summary_cod2_plot = scatter(\@stretch_len_ok,\@pure_cod_ok,"Effect of stretch length on pures",'Stretch length',"Pure codon percent");
	$summary_cod2_img = $mw->Photo(-format=>'GIF', -data=>$summary_cod2_plot);#->draw('gif'));

	$summary_cod_canvas->createImage(440,20,-tags=>'sumcod1',-image=>$summary_cod2_img, -anchor=>'nw');

}

sub simple_binner {
	print "Simple_binner sub\n" if ($verbose);
	my $in = shift;
	my $bin = shift;
	my @in = @$in;
	my $st; my $en;
	my @bin_cumul = ();
	my @bin_count = ();
	my @bins = ();
	for (my $i=1;$i<=(100+$bin);$i+=$bin) {
		$bin_count = 0;
		foreach (@in) {
			$bin_count++ if ($_ <= $i);
		}
		push (@bins,$i);
		push (@bin_cumul,$bin_count);
	}
	foreach my $sc (1..$#bin_cumul) {
		$bin_count[$sc] = $bin_cumul[$sc]-$bin_cumul[$sc-1];
	}
	return (\@bins,\@bin_count);
}
sub binner {	
	print "Binner sub\n" if ($verbose);
	my $in_x = shift;
	my $in_y = shift;
	@in_x = @$in_x;
	@in_y = @$in_y;
	my $st; my $en;
	my $bin = shift;
	$st = $in_x[0];
	$en = $in_x[$#in_x];
	my $bin_count;
	my @bin_cumul = ();
	my @bin_count = ();
	my @bins = ();
	#	print "ST: $summary_st; END: $summary_en\n";
	for (my $i=$st;$i<=$en;$i+=$bin) {
		$bin_count = 0;
		foreach my $sc (0..$#in_x) {
			$bin_count += $in_y[$sc] if ($in_x[$sc] <= $i);
		}
		push (@bins,$i);
		push (@bin_cumul,$bin_count);
	}
	foreach $sc (1..$#bin_cumul) {
		$bin_count[$sc] = $bin_cumul[$sc]-$bin_cumul[$sc-1];
	}
	return (\@bins,\@bin_count);
#\E0	print "BINS: ",scalar @summary_x," / ",scalar @summary_y,"\n";
}			

sub graph_results { #to be implemented, yet, next version, maybe...
	print "Graph_results sub\n" if ($verbose);
	my $name;
	my $pos;
	my $len;
	my %names = ();
	$img = GD::Simple->new(400,300);
	$new = 0;
	foreach(0..$#position) {
		if (!$names{$keynames[$_]}) {
			$new++;
			$img->fgcolor('black');
			$img->rectangle(2,2+$step,350,2+$step);
		}
		$names{$keynames[$_]} = 1;
		$step = $new*5;
		$center = 350*$position/100;
		$img->bgcolor('red');
		$img->fgcolor('red');
		$img->rectangle($center-$len,2+$step,$center+$len,2+$step);
	}
}	

sub filter_lock {
	if ($filter_lock == 1) {
		$filt_but->configure(-state=>'disabled') ;
		$br_ent5->configure(-state=>'disabled') ;
		$br_ent6->configure(-state=>'disabled') ;
		$ent1->configure(-state=>'disabled') ;
		my @tmp = split (/\n/,$selected_data);
		%filter_lock = ();
		foreach my $lock (1..$#tmp) {
			my @tmp1 = split (/\t/,$tmp[$lock]);
			$filter_lock{$tmp1[0]} = 1;
		}
	} else {
		$filt_but->configure(-state=>'normal') ;
		$br_ent5->configure(-state=>'normal') ;
		$br_ent6->configure(-state=>'normal') ;
		$ent1->configure(-state=>'normal') ;
		undef %filter_lock;
	}
}

sub filter_check { #remember that @filter_choices = qw/~ !~ = != > < >= <= >< >=< ><= >=<=/;
	print "Filter_check sub\n" if ($verbose);
	my $field = shift;
	my $in_filter = $filter;
	@tmp = split (/\t/,$to_be_filtered[$field]);
	my $topic = $tmp[$filters_ind{$filter_on}+1];
	if ($filter_on =~ /ff_seq/i) {
		@ff_tmp = split(/\./,$filters_ind{$filter_on});
		$topic = $tmp[$ff_tmp[0]+1].$tmp[$ff_tmp[1]+1];
	}
	if ($filter_on =~ /seq/i || $filter_on =~ /name/i || $filter_on =~ /go/i || $filter_on =~ /mim/i || $filter_on =~ /homolog/i) {
		if ($graph_mode =~ /cod/ && $filter_on =~ /seq/i) {
			$topic =~ s/(...)/$1 /g;
		}
		if ($graph_mode =~ /cod/ && length($in_filter) < 3) {
			$in_filter = $codons_of{$in_filter};
			$in_filter =~ s/\|/)|(/g;
			$in_filter =~ s/\|\($//;
			$in_filter = '('.$in_filter;
			
#			print "$topic -> $in_filter\n"; filter_mode
		}
		print "$field -> $topic -> $filter -> NO\n" if ($topic !~ /$filter/i);
		print "$field -> $topic -> $filter -> OK\n" if ($topic =~ /$filter/i);
######### NOTE THAT 1 means discard, 0 means accept !!!
		return 1 if ($filter_mode =~ /[>|<]/); #incompatibility of gt and lt with text, return always true i.e. discard
		return 0 if ($filter_mode eq '~' && $topic !~ /$in_filter/i);
		return 0 if ($filter_mode eq '!~' && $topic =~ /$in_filter/i);
		return 0 if ($filter_mode eq '=' && $topic ne $in_filter);
		return 0 if ($filter_mode eq '!=' && $topic eq $in_filter);
	} else {
		return 1 if ($filter_mode =~ /~/); #incompatibility of match with numbers, return always true
		return 0 if ($filter_mode eq '=' && $topic != $in_filter);
		return 0 if ($filter_mode eq '!=' && $topic == $in_filter);
		return 0 if ($filter_mode eq '<' && $topic >= $in_filter);
		return 0 if ($filter_mode eq '<=' && $topic > $in_filter);
		return 0 if ($filter_mode eq '>' && $topic <= $in_filter);
		return 0 if ($filter_mode eq '>=' && $topic < $in_filter);
		if ($filter_mode =~ />/ && $filter_mode =~ /</) {
			@tmp = split (/[&| ]/,$in_filter); 
			@tmp = sort (@tmp);
			return 0 if ($filter_mode eq '><' && ($topic <= $tmp[0] || $topic >= $tmp[1]));
			return 0 if ($filter_mode eq '>=<' && ($topic < $tmp[0] || $topic >= $tmp[1]));
			return 0 if ($filter_mode eq '><=' && ($topic <= $tmp[0] || $topic > $tmp[1]));
			return 0 if ($filter_mode eq '>=<=' && ($topic < $tmp[0] || $topic > $tmp[1]));
			return 0 if ($filter_mode eq '<>' && ($topic >= $tmp[0] || $topic <= $tmp[1]));
			return 0 if ($filter_mode eq '<=>' && ($topic > $tmp[0] || $topic <= $tmp[1]));
			return 0 if ($filter_mode eq '<>=' && ($topic >= $tmp[0] || $topic < $tmp[1]));
			return 0 if ($filter_mode eq '<=>=' && ($topic > $tmp[0] || $topic < $tmp[1]));
		}
	}
#	print "$field -> $topic -> $filter -> OK !!!\n";
	return 1;
}


sub scan {
	print "Scan sub\n" if ($verbose);
	#########    this defines the list of stetch lengths to be analysed  #########
	undef @ind;
	if ($len1 eq 'All') {
		@ind = @choices;
		shift @ind; # $shortind[0] is 'all'
	}
	if ($len2 eq 'All') {
		@ind = @choices;
		shift @ind; # $shortind[0] is 'all'
	} 
	if ($len1 ne 'All' && $len2 ne 'All') {
		$m = $len1 if ($len1 < $len2);
		$m = $len1 if ($len1 == $len2);
		$m = $len2 if ($len1 > $len2);
		$M = $len1 if ($len1 > $len2);
		$M = $len1 if ($len1 == $len2);
		$M = $len2 if ($len1 < $len2);
		foreach $range ($m..$M) {
			push (@ind,$range) if ($is_record{$range});
		}
	}
	$m = $ind[0];
	$M = $ind[$#ind];
	@st_seq_ok = ();
	@lf_seq_ok = ();
	@rf_seq_ok = ();
	@ff_seq_ok = ();	
	@stretch_len_ok = ();
	@stretch_y_ok = ();
	@position_ok = ();
	@pure_cod_ok = ();
	%records = ();
	$current_records = '';
	$avail_records = 0;
	$selected_data = "Ind\t".$headers."\n";
	print join "\n", keys %filter_lock if (%filter_lock);
	foreach (0..$#st_seq) { #runs through all record indices
		if (%filter_lock) {
			@tmp = split (/\t/,$to_be_filtered[$_]);
			next if (!$filter_lock{$tmp[0]});
			$filter_on = '---';
			$m = 0;
			$M = 10E10;
		}
		if ($st_len[$_] >=$m && $st_len[$_] <=$M) {
			$ex = 1;
			$ex = filter_check($_) if ($filter_mode ne '---' && $filter =~ /./);
			if ($ex) {
				$records{$st_len[$_]}++;
				push(@st_seq_ok, $st_seq[$_]);
				push(@lf_seq_ok, $lf_seq[$_]);
				push(@rf_seq_ok, $rf_seq[$_]);
				push(@ff_seq_ok, $lf_seq[$_]);
				push(@ff_seq_ok, $rf_seq[$_]);
				push(@stretch_len_ok, $stretch_x[$_]);
				push(@stretch_y_ok, $stretch_y[$_]);
				push(@position_ok, $position[$_]);
				push(@pure_cod_ok, $pure_cod[$_]) if ($pure_cod[$_]);
				$selected_data .= $to_be_filtered[$_]."\n";
			}
		}
	}
	$m = $ind[0] if (%filter_lock);
	$M = $ind[$#ind] if (%filter_lock);
	$selected_text1->Contents($selected_data);
	$avail_records = scalar @st_seq_ok;
	$current_records = $avail_records."\n over \n".$records_tot;
}

sub create_data {
	return if ($avail_records == 0);
	$st_cnt= ''; %st_cnt= (); $st_tot = '';
	($st_cnt,$st_tot) = counter(\@st_seq_ok,$tuple,'st');
	%st_cnt = %$st_cnt;
	$gap_cnt= ''; %gap_cnt= (); $gap_tot = '';
	($gap_cnt,$gap_tot) = counter(\@st_seq_ok,$tuple,'gap');
	%gap_cnt = %$gap_cnt;
	$lf_cnt= ''; %lf_cnt= (); $lf_tot = '';
	($lf_cnt,$lf_tot) = counter(\@lf_seq_ok,$tuple,'gap');
	%lf_cnt = %$lf_cnt;
	$rf_cnt= ''; %rf_cnt= (); $rf_tot = '';
	($rf_cnt,$rf_tot) = counter(\@rf_seq_ok,$tuple,'gap');
	%rf_cnt = %$rf_cnt;
	$ff_cnt= ''; %ff_cnt= (); $ff_tot = '';
	($ff_cnt,$ff_tot) = counter(\@ff_seq_ok,$tuple,'gap');
	%ff_cnt = %$ff_cnt;
	
	$report_text = "AA\t"if ($graph_mode =~ /res/);
	$report_text = "COD\t"if ($graph_mode =~ /cod/);
	if ($graph_mode =~ /res/ || $graph_mode =~ /cod_ratio/) {
		$report_text .= "Back\tBack%\tBack-$residue%\tStre\tStre%\tStreR\tStre-p\tGap\tGap%\tGapR\tGap-p\tLeft\tLeft%\tLeftR\tLeft-p\tRigh\tRight%\tRightR\tRight-p\tBoth\tBoth%\tBothR\tBoth-p\n";
		foreach (sort {$a cmp $b} @labels) { # for each residue/codon the p-value is computed using chi-square test
			($st_pval{$_},$st_perc{$_},$st_chisq{$_},$st_ratio{$_}) = p_value($st_cnt{$_},$st_tot,$_,'st');
			($lf_pval{$_},$lf_perc{$_},$lf_chisq{$_},$lf_ratio{$_}) = p_value($lf_cnt{$_},$lf_tot,$_,'gap'); #according to elodie idea, flanks have to be statistically treated as if they were gaps
			($rf_pval{$_},$rf_perc{$_},$rf_chisq{$_},$rf_ratio{$_}) = p_value($rf_cnt{$_},$rf_tot,$_,'gap');
			($ff_pval{$_},$ff_perc{$_},$ff_chisq{$_},$ff_ratio{$_}) = p_value($ff_cnt{$_},$ff_tot,$_,'gap');
			($gap_pval{$_},$gap_perc{$_},$gap_chisq{$_},$gap_ratio{$_}) = p_value($gap_cnt{$_},$gap_tot,$_,'gap');
			$tmp_label = $_;
			$tmp_label =~ s/$residue/($residue)/; 
			$report_text .= "$tmp_label\t".$global_count{$tuple."@".$_}."\t".$global_perc{$tuple."@".$_}."\t".$global_perc_gap{$tuple."@".$_}."\t$st_cnt{$_}\t$st_perc{$_}\t$st_ratio{$_}\t$st_pval{$_}\t$gap_cnt{$_}\t$gap_perc{$_}\t$gap_ratio{$_}\t$gap_pval{$_}\t $lf_cnt{$_}\t$lf_perc{$_}\t$lf_ratio{$_}\t$lf_pval{$_}\t$rf_cnt{$_}\t$rf_perc{$_}\t$rf_ratio{$_}\t$rf_pval{$_}\t$ff_cnt{$_}\t$ff_perc{$_}\t$ff_ratio{$_}\t$ff_pval{$_}\n";
		}
		# the global p-value is also computed, again using chi-sqaure
		$df = scalar(@labels)-1;
		$st_pval_full = p_value_full(\%st_chisq, $df);
		$lf_pval_full = p_value_full(\%lf_chisq, $df-1);
		$rf_pval_full = p_value_full(\%rf_chisq, $df-1);
		$ff_pval_full = p_value_full(\%ff_chisq, $df-1);
		$gap_pval_full = p_value_full(\%gap_chisq, $df-1);
		
	}

	if ($graph_mode =~ /cod/ && $graph_mode =~ /bias/) {
		$type = 'perc';
		$report_text = "COD\tBack\tBack%\tBack-$residue%\tStre\tStre%\tGap\tGap%\tLeft\tLeft%\tRigh\tRight%\tBoth\tBoth%\n";
		$global_perc = codon_analysis (\%global_count);
		$global_perc_gap = codon_analysis (\%global_count);
		$st_perc = codon_analysis (\%st_cnt);
		$lf_perc = codon_analysis (\%lf_cnt);
		$rf_perc = codon_analysis (\%rf_cnt);
		$ff_perc = codon_analysis (\%ff_cnt);
		%global_perc = %{$global_perc};
		%global_perc_gap = %{$global_perc_gap};
		%st_perc = %{$st_perc};
		%gap_perc = %{$st_perc};
		%lf_perc = %{$lf_perc};
		%rf_perc = %{$rf_perc};
		%ff_perc = %{$ff_perc};
		foreach (@labels) {
			$key = substr($_,0,1); # this is the key derived from e.g. A-CGT, A
#			next if ($key eq '_' || $key eq 'M' || $key eq 'W'); #only one codon for W and M, while "_" is not present in translations...
			$tmp_label = $_;
			$tmp_label =~ s/$residue/($residue)/; 
			$report_text .= "$tmp_label\t".$global_count{$tuple.'@'.$_}."\t".$global_perc{$tuple.'@'.$_}."\t".$global_perc_gap{$tuple.'@'.$_}."\t$st_cnt{$_}\t$st_perc{$_}\t$gap_cnt{$_}\t$gap_perc{$_}\t$lf_cnt{$_}\t$lf_perc{$_}\t$rf_cnt{$_}\t$rf_perc{$_}\t$ff_cnt{$_}\t$ff_perc{$_}\n";
		}
	}
	if ($type eq 'perc') {
		%st_cnt = %st_perc;
		%gap_cnt = %gap_perc;
		%lf_cnt = %lf_perc;
		%rf_cnt = %rf_perc;
		%ff_cnt = %ff_perc;
	}
	$text_text->Contents("$report_text");
}

##### this compute a p-value given the frequency of elemnt and that of globals using chi-square ########### 
sub p_value {
	print "p-value sub\n" if ($verbose);
	my $cnt = shift;
	my $tot = shift;
	my $res = shift;
	my $what = shift;
	my $perc = 0;
	my $chisq = 0;
	my $pval = 0;
	my $ratio = 0;
#	my $resi = $res;
	my $key = substr($res,0,1);
	return "0","0","0","0" if ($what eq 'gap' && $key eq $residue);
	$perc = sprintf("%.2f",$cnt/$tot*100) if ($cnt && $tot && $res);
	$perc = 1E-6 if (!$perc);
	return $perc if (!$res); #this is returned to the glob_alt function
#	print $residue ,"($key) $res -> ", $global_perc_gap{$tuple."@".$res},"\n" if ($what eq 'gap');
	$chisq = (($perc-$global_perc{$tuple."@".$res})**2)/$global_perc{$tuple."@".$res} if ($what ne 'gap');
	$chisq = (($perc-$global_perc_gap{$tuple."@".$res})**2)/$global_perc_gap{$tuple."@".$res} if ($what eq 'gap');
	$pval = sprintf("%.4f",chisqrprob(1,$chisq));
	$ratio = sprintf("%.2f",$perc/$global_perc{$tuple."@".$res})  if ($what ne 'gap');
	$ratio = sprintf("%.2f",$perc/$global_perc_gap{$tuple."@".$res})  if ($what eq 'gap');
	return $pval,$perc,$chisq,$ratio;
}
##### since the p-value sub returns the chi-square value for each residue, it is sufficient to sum all this values and use the correct df to get the total p-value ########### 
sub p_value_full {
	print "p_value_sub sub\n" if ($verbose);
	my $hash = shift;
	my %hash = %$hash;
	my $df = shift;
	my $tot = 0;
	my $pval = 0;
#	print "DF: $df\n";
	foreach(keys %hash) {
		$tot += $hash{$_};
	}
	$pval = sprintf("%.4f",chisqrprob($df,$tot));
	return $pval;
}

#####  ########### 
sub counter {
	print "Counter sub\n" if ($verbose);
	my $array = shift;
	my @array = @$array;
	my $tup = shift;
	my $what = shift;
	my %cnt = ();
	my %cnt_g = ();
	my $cnt_tot = 0;
	my $keyr;
	my $key;
	my @labels = @res;
	@labels = @cods if ($graph_mode =~ /cod/);
	$tup = 1 if ($graph_mode =~ /groups/);
	foreach my $seq (@array) {
		if ($graph_mode =~ /cod/) {
			while ($seq =~ /(...)/g) {
				$cnt{$codons_t{$1}}++;
			}
		}
		if ($graph_mode =~ /res/) {
			foreach my $res (@labels) {
				$res .= '+' if ($tup > 1);
				while ($seq =~ /($res)/g) {
					$cnt{$res}++ if (length($1) == $tup);
				}
			}
		}
	}
	foreach my $res (@labels) {
		if ($graph_mode =~ /res/ && $what =~ 'gap' && $res eq $residue) {
			$cnt{$residue} = 0;
		}
		if ($graph_mode =~ /groups/ && $what =~ 'st' && $res eq $residue) {
			$cnt{$residue} = 0;
		}
		if ($graph_mode =~ /cod/ && $what =~ 'gap') {
			@tmp = split (/-/,$res);
#			print "$res has $tmp[0] -> $residue => $cnt{$res} -> ";
			$cnt{$res} = 0 if ($tmp[0] eq $residue);
#			print $cnt{$res},"\n";
		}
		$cnt{$res} = 0 if (!$cnt{$res});
		$cnt_tot += $cnt{$res};
	}
	if ($graph_mode =~ /groups/) {
		foreach	my $rg (@res_groups) {
			@tmp = split (//,$rg);
			foreach my $res (@tmp) {
				next if ($what !~ /st/ && $res eq $residue);
				$cnt_g{$rg} += $cnt{$res};
			}
		}
		%cnt = %cnt_g;
	}
#	print " $what -> $firstM_ so $cnt{'M'}, $cnt_tot -> " if ($what =~ /gen/);
#	$cnt{'M'} = $cnt{'M'}-($firstM*$firstM_) if ($graph_mode =~ /res/ && $what =~ /gen/);   #the number of fist Ms (or ATGs)  can be removed this way
#	$cnt{'ATG'} = $cnt{'ATG'}-($firstM*$firstM_) if ($graph_mode =~ /cod/ && $what =~ /gen/); #the number of fist Ms (or ATGs)  can be removed this way
#	$cnt_tot = $cnt_tot-($firstM*$firstM_) if ($what =~ /gen/); #the number of fist Ms (or ATGs)  can be removed this way
#	print "$cnt{'M'}, $cnt_tot\n" if ($what =~ /gen/);
	return (\%cnt,$cnt_tot);
}

sub codon_analysis { #this receives a hash containing counts and returns a hash 
                     #with codons expressed in terms of % respect to coded residue (the bias)
	print "Codon_analysis sub\n" if ($verbose);
	my $count_hash = shift;
	my %hash = %{$count_hash};
	my %perc = ();
	$modi = '';
	$modi = $tuple."@" if ($hash{$tuple."@".'Q-CAG'}); #this is is used when the global counter arrives...
	foreach my $res (@res,"_") {
		@tmp = split (/ /,$codons{$res});
		$tot = 0;
		foreach	(@tmp) {
			$tot += $hash{$modi.$_};
		}
		foreach	(@tmp) {
			$perc{$modi.$_} = sprintf("%.2f",$hash{$modi.$_}/$tot*100) if ($tot);
			$perc{$modi.$_} = sprintf("%.2f",0) if ($tot == 0);
		}
	}
	return \%perc;
}

sub create_graph {
	print "Create_graph sub\n" if ($verbose);
	undef @graph_labels;
	undef @gap_labels;
	undef @st_vals;
	undef @gap_vals;
	undef @lf_vals;
	undef @rf_vals;
	undef @ff_vals;
	undef %st_init;
	undef %lf_init;
	undef %rf_init;
	undef %gap_init;
	undef %ff_init;
	undef @glob_vals;
	undef @glob_vals_gap;
	undef @st_color;
	undef @gap_color;
	undef @lf_color;
	undef @rf_color;
	undef @ff_color;
	foreach (@labels) {
		$key = substr($_,0,1); # this is ok for both residue and codons
#		$keyr = substr($residue,0,1); # this is the key derived from e.g. A-CGT, A
#		print "$_ -> $key -> $keyr\n";
#		next if ($graph_mode =~ /cod/ && $key eq '-'); # || $key eq 'M' || $key eq 'W')); #only one codon for W and M, - is not present in translations...
		push (@graph_labels, $_);
		push (@gap_labels, $_) if ($key ne $residue);
		
		if ($graph_mode !~ /ratio/) {
			push (@st_vals, $st_cnt{$_}); 
			push (@gap_vals, $gap_cnt{$_}) if ($key ne $residue);
			push (@lf_vals, $lf_cnt{$_}) if ($key ne $residue); 
			push (@rf_vals, $rf_cnt{$_}) if ($key ne $residue); 
			push (@ff_vals, $ff_cnt{$_}) if ($key ne $residue); 
		}
		if ($graph_mode =~ /ratio/) {
			push (@st_vals, $st_cnt{$_}/$global_perc{$tuple."@".$_}); 
			push (@gap_vals, $gap_cnt{$_}/$global_perc_gap{$tuple."@".$_}) if ($key ne $residue);
			push (@lf_vals, $lf_cnt{$_}/$global_perc_gap{$tuple."@".$_}) if ($key ne $residue);
			push (@rf_vals, $rf_cnt{$_}/$global_perc_gap{$tuple."@".$_}) if ($key ne $residue);
			push (@ff_vals, $ff_cnt{$_}/$global_perc_gap{$tuple."@".$_}) if ($key ne $residue); 
		}
		
		if ($graph_mode =~ /res/ || $graph_mode =~ /cod_ratio/) {
#			push (@st_color, 'lgreen') if ($st_pval{$_} <= $p_value_t && $st_perc{$_} >= $global_perc{$tuple."@".$_}); 
#			push (@gap_color, 'lgreen') if ($gap_pval{$_} <= $p_value_t && $gap_perc{$_} >= $global_perc_gap{$tuple."@".$_} && $key ne $residue); 
#			push (@lf_color, 'lgreen') if ($lf_pval{$_} <= $p_value_t && $lf_perc{$_} >= $global_perc_gap{$tuple."@".$_} && $key ne $residue);
#			push (@rf_color, 'lgreen') if ($rf_pval{$_} <= $p_value_t && $rf_perc{$_} >= $global_perc_gap{$tuple."@".$_} && $key ne $residue); 
#			push (@ff_color, 'lgreen') if ($ff_pval{$_} <= $p_value_t && $ff_perc{$_} >= $global_perc_gap{$tuple."@".$_} && $key ne $residue);  

#			push (@st_color, 'lred') if ($st_pval{$_} <= $p_value_t && $st_perc{$_} < $global_perc{$tuple."@".$_}); 
#			push (@gap_color, 'lred') if ($gap_pval{$_} <= $p_value_t && $gap_perc{$_} < $global_perc_gap{$tuple."@".$_} && $key ne $residue); 
#			push (@lf_color, 'lred') if ($lf_pval{$_} <= $p_value_t && $lf_perc{$_} < $global_perc_gap{$tuple."@".$_} && $key ne $residue);
#			push (@rf_color, 'lred') if ($rf_pval{$_} <= $p_value_t && $rf_perc{$_} < $global_perc_gap{$tuple."@".$_} && $key ne $residue); 
#			push (@ff_color, 'lred') if ($ff_pval{$_} <= $p_value_t && $ff_perc{$_} < $global_perc_gap{$tuple."@".$_} && $key ne $residue);  

#			push (@st_color, 'black') if ($st_pval{$_} > $p_value_t); 
#			push (@gap_color, 'black') if ($gap_pval{$_} > $p_value_t && $key ne $residue); 
#			push (@lf_color, 'black') if ($lf_pval{$_} > $p_value_t && $key ne $residue); 
#			push (@rf_color, 'black') if ($rf_pval{$_} > $p_value_t && $key ne $residue); 
#			push (@ff_color, 'black') if ($ff_pval{$_} > $p_value_t && $key ne $residue);  

###############    septermber 2010 new version, green or red or black according to genome ratio, not p-values 
			$ratio_t = 1/$ratio_t if ($ratio_t < 1);
			$ratio_t = abs($ratio_t);
			push (@st_color, 'lgreen') if ($st_perc{$_}/$global_perc{$tuple."@".$_} >= $ratio_t); 
			push (@gap_color, 'lgreen') if ($key ne $residue && $gap_perc{$_}/$global_perc_gap{$tuple."@".$_} >= $ratio_t); 
			push (@lf_color, 'lgreen') if ($key ne $residue && $lf_perc{$_}/$global_perc_gap{$tuple."@".$_} >= $ratio_t);
			push (@rf_color, 'lgreen') if ($key ne $residue && $rf_perc{$_}/$global_perc_gap{$tuple."@".$_} >= $ratio_t); 
			push (@ff_color, 'lgreen') if ($key ne $residue && $ff_perc{$_}/$global_perc_gap{$tuple."@".$_} >= $ratio_t);  

			push (@st_color, 'lred') if ($st_perc{$_}/$global_perc{$tuple."@".$_} <= 1/$ratio_t); 
			push (@gap_color, 'lred') if ($key ne $residue && $gap_perc{$_}/$global_perc_gap{$tuple."@".$_} <= 1/$ratio_t); 
			push (@lf_color, 'lred') if ($key ne $residue && $lf_perc{$_}/$global_perc_gap{$tuple."@".$_} <= 1/$ratio_t);
			push (@rf_color, 'lred') if ($key ne $residue && $rf_perc{$_}/$global_perc_gap{$tuple."@".$_} <= 1/$ratio_t); 
			push (@ff_color, 'lred') if ($key ne $residue && $ff_perc{$_}/$global_perc_gap{$tuple."@".$_} <= 1/$ratio_t);  

			push (@st_color, 'black') if ($st_perc{$_}/$global_perc{$tuple."@".$_} < $ratio_t && $st_perc{$_}/$global_perc{$tuple."@".$_} > 1/$ratio_t); 
			push (@gap_color, 'black') if ($key ne $residue && ($gap_perc{$_}/$global_perc_gap{$tuple."@".$_} < $ratio_t && $gap_perc{$_}/$global_perc_gap{$tuple."@".$_} > 1/$ratio_t)); 
			push (@lf_color, 'black') if ($key ne $residue && ($lf_perc{$_}/$global_perc_gap{$tuple."@".$_} < $ratio_t && $lf_perc{$_}/$global_perc_gap{$tuple."@".$_} > 1/$ratio_t));
			push (@rf_color, 'black') if ($key ne $residue && ($rf_perc{$_}/$global_perc_gap{$tuple."@".$_} < $ratio_t && $rf_perc{$_}/$global_perc_gap{$tuple."@".$_} > 1/$ratio_t)); 
			push (@ff_color, 'black') if ($key ne $residue && ($ff_perc{$_}/$global_perc_gap{$tuple."@".$_} < $ratio_t && $ff_perc{$_}/$global_perc_gap{$tuple."@".$_} > 1/$ratio_t));  


		}
		if ($graph_mode =~ /cod_bias/) {
			push (@glob_vals, $global_perc{$tuple."@".$_}); 
			push (@glob_vals_gap, $global_perc_gap{$tuple."@".$_}) if ($key ne $residue);

		}
	}
	if ($graph_mode =~ /groups/) { #this simply removes $residue from multiple labels in groups...
		foreach(0..$#gap_labels) {
			$gap_labels[$_] =~ s/$residue//;
		}
	}
	if ($graph_mode =~ /res/ || $graph_mode =~ /cod_ratio/) {
		@st_data=(\@graph_labels,\@st_vals);
		@gap_data=(\@gap_labels,\@gap_vals);
		@lf_data=(\@gap_labels,\@lf_vals);
		@rf_data=(\@gap_labels,\@rf_vals);
		@ff_data=(\@gap_labels,\@ff_vals);
	}	

	if ($graph_mode =~ /cod_bias/) {
		@st_data=(\@graph_labels,\@st_vals,\@glob_vals);
		@gap_data=(\@gap_labels,\@gap_vals,\@glob_vals_gap);
		@lf_data=(\@graph_labels,\@lf_vals,\@glob_vals);
		@rf_data=(\@graph_labels,\@rf_vals,\@glob_vals);
		@ff_data=(\@graph_labels,\@ff_vals,\@glob_vals);
	}

	$st_init{'y_label'} = 'Raw count' if ($type eq 'raw');
	$st_init{'y_label'} = 'Percent' if ($type eq 'perc');
	$st_init{'y_label'} = 'Genomic ratio' if ($graph_mode =~ /ratio/);
	$st_init{'title'} = "Percent report on $st_tot elements, p-value = $st_pval_full" if ($type eq 'perc');
	$st_init{'title'} = "Count report on $st_tot elements, p-value = $st_pval_full" if ($type eq 'raw');
	$st_init{'title'} = "Genomic ratio on $st_tot elements, p-value = $st_pval_full" if ($graph_mode =~ /ratio/);
#	$st_init{'y_max_value'} = $st_tot if ($type eq 'raw');
	$st_init{'y_max_value'} = 100 if ($graph_mode =~ /bias/);
#	$st_init{'y_max_value'} = 'auto' if ($graph_mode =~ /ratio/);
	$st_init{'x_labels_vertical'} = 1 if ($graph_mode =~ /cod/);
	$st_init{'x_labels_vertical'} = 0 if ($graph_mode =~ /res/);
	$st_init{'y_tick_number'} = 10;

	$gap_init{'y_label'} = 'Raw count' if ($type eq 'raw');
	$gap_init{'y_label'} = 'Percent' if ($type eq 'perc');
	$gap_init{'y_label'} = 'Genomic ratio' if ($graph_mode =~ /ratio/);
	$gap_init{'title'} = "Percent report on $gap_tot elements, p-value = $gap_pval_full" if ($type eq 'perc');
	$gap_init{'title'} = "Count report on $gap_tot elements, p-value = $gap_pval_full" if ($type eq 'raw');
	$gap_init{'title'} = "Genomic ratio on $gap_tot elements, p-value = $gap_pval_full" if ($graph_mode =~ /ratio/);
#	$gap_init{'y_max_value'} = $gap_tot if ($type eq 'raw');
	$gap_init{'y_max_value'} = 100 if ($graph_mode =~ /bias/);
#	$gap_init{'y_max_value'} = 'auto' if ($graph_mode =~ /ratio/);
	$gap_init{'x_labels_vertical'} = 1 if ($graph_mode =~ /cod/);
	$gap_init{'x_labels_vertical'} = 0 if ($graph_mode =~ /res/);
	$gap_init{'y_tick_number'} = 10;
	
	$lf_init{'y_label'} = 'Raw count' if ($type eq 'raw');
	$lf_init{'y_label'} = 'Percent' if ($type eq 'perc');
	$lf_init{'y_label'} = 'Genomic ratio' if ($graph_mode =~ /ratio/);
	$lf_init{'title'} = "Percent report on $lf_tot elements, p-value = $lf_pval_full" if ($type eq 'perc');
	$lf_init{'title'} = "Count report on $lf_tot elements, p-value = $lf_pval_full" if ($type eq 'raw');
	$lf_init{'title'} = "Genomic ratio on $lf_tot elements, p-value = $lf_pval_full" if ($graph_mode =~ /ratio/);
#	$lf_init{'y_max_value'} = $lf_tot if ($type eq 'raw');
	$lf_init{'y_max_value'} = 100 if ($graph_mode =~ /bias/);
#	$lf_init{'y_max_value'} = 'auto' if ($graph_mode =~ /ratio/);
	$lf_init{'x_labels_vertical'} = 1 if ($graph_mode =~ /cod/);
	$lf_init{'x_labels_vertical'} = 0 if ($graph_mode =~ /res/);
	$lf_init{'y_tick_number'} = 10;
	
	$rf_init{'y_label'} = 'Raw count' if ($type eq 'raw');
	$rf_init{'y_label'} = 'Percent' if ($type eq 'perc');
	$rf_init{'y_label'} = 'Genomic ratio' if ($graph_mode =~ /ratio/);
	$rf_init{'title'} = "Percent report on $rf_tot elements, p-value = $rf_pval_full" if ($type eq 'perc');
	$rf_init{'title'} = "Count report on $rf_tot elements, p-value = $rf_pval_full" if ($type eq 'raw');
	$rf_init{'title'} = "Genomic ratio on $rf_tot elements, p-value = $rf_pval_full" if ($graph_mode =~ /ratio/);
#	$rf_init{'y_max_value'} = $rf_tot if ($type eq 'raw');
	$rf_init{'y_max_value'} = 100 if ($graph_mode =~ /bias/);
#	$rf_init{'y_max_value'} = 'auto' if ($graph_mode =~ /ratio/);
	$rf_init{'x_labels_vertical'} = 1 if ($graph_mode =~ /cod/);
	$rf_init{'x_labels_vertical'} = 0 if ($graph_mode =~ /res/);
	$rf_init{'y_tick_number'} = 10;
	
	$ff_init{'y_label'} = 'Raw count' if ($type eq 'raw');
	$ff_init{'y_label'} = 'Percent' if ($type eq 'perc');
	$ff_init{'y_label'} = 'Genomic ratio' if ($graph_mode =~ /ratio/);
	$ff_init{'title'} = "Percent report on $ff_tot elements, p-value = $ff_pval_full" if ($type eq 'perc');
	$ff_init{'title'} = "AA count report on $ff_tot elements, p-value = $ff_pval_full" if ($type eq 'raw');
	$ff_init{'title'} = "Genomic ratio on $ff_tot elements, p-value = $ff_pval_full" if ($graph_mode =~ /ratio/);
#	$ff_init{'y_max_value'} = $ff_tot if ($type eq 'raw');
	$ff_init{'y_max_value'} = 100 if ($graph_mode =~ /bias/);
#	$ff_init{'y_max_value'} = 'auto' if ($graph_mode =~ /ratio/);
	$ff_init{'x_labels_vertical'} = 1 if ($graph_mode =~ /cod/);
	$ff_init{'x_labels_vertical'} = 0 if ($graph_mode =~ /res/);
	$ff_init{'y_tick_number'} = 10;
	
	if ($graph_mode =~ /res/ || $graph_mode =~ /cod_ratio/) {
		$st_gr = GD::Graph::bars->new(800, 300);
		$gap_gr = GD::Graph::bars->new(800, 300);
		$lf_gr = GD::Graph::bars->new(800, 300);
		$rf_gr = GD::Graph::bars->new(800, 300);
		$ff_gr = GD::Graph::bars->new(800, 300);

		$st_gr->set(dclrs => \@st_color, cycle_clrs => 1);
		$gap_gr->set(dclrs => \@gap_color, cycle_clrs => 1);
		$lf_gr->set(dclrs => \@lf_color, cycle_clrs => 1);
		$rf_gr->set(dclrs => \@rf_color, cycle_clrs => 1);
		$ff_gr->set(dclrs => \@ff_color, cycle_clrs => 1);

	}
	if ($graph_mode =~ /cod_bias/) {
		$st_gr = GD::Graph::mixed->new(800, 300);
		$gap_gr = GD::Graph::mixed->new(800, 300);
		$lf_gr = GD::Graph::mixed->new(800, 300);
		$rf_gr = GD::Graph::mixed->new(800, 300);
		$ff_gr = GD::Graph::mixed->new(800, 300);

		$st_gr->set( types => [qw(bars points)], dclrs =>[qw/lred black/]);
		$gap_gr->set( types => [qw(bars points)], dclrs =>[qw/lred black/]);
		$lf_gr->set( types => [qw(bars points)], dclrs =>[qw/lred black/]);
		$rf_gr->set( types => [qw(bars points)], dclrs =>[qw/lred black/]);
		$ff_gr->set( types => [qw(bars points)], dclrs =>[qw/lred black/]);
		
	}

	$st_gr->set(%st_init);
	$gap_gr->set(%gap_init);
	$lf_gr->set(%lf_init);
	$rf_gr->set(%rf_init);
	$ff_gr->set(%ff_init);

	$st_gr = giantize($st_gr);
	$gap_gr = giantize($gap_gr);
	$rf_gr = giantize($rf_gr);
	$lf_gr = giantize($lf_gr);
	$ff_gr = giantize($ff_gr);
	
	$st_plot = $st_gr->plot(\@st_data);	
	$gap_plot = $gap_gr->plot(\@gap_data);	
	$lf_plot = $lf_gr->plot(\@lf_data);	
	$rf_plot = $rf_gr->plot(\@rf_data);	
	$ff_plot = $ff_gr->plot(\@ff_data);

	$st_img = $mw->Photo(-format=>'GIF', -data=>$st_plot->gif);
	$gap_img = $mw->Photo(-format=>'GIF', -data=>$gap_plot->gif);
	$lf_img = $mw->Photo(-format=>'GIF', -data=>$lf_plot->gif);
	$rf_img = $mw->Photo(-format=>'GIF', -data=>$rf_plot->gif);	
	$ff_img = $mw->Photo(-format=>'GIF', -data=>$ff_plot->gif);	

	$st_gdata = \@st_data;
	$gap_gdata = \@gap_data;
	$lf_gdata = \@lf_data;
	$rf_gdata = \@rf_data;
	$ff_gdata = \@ff_data;
}
sub plot {
	print "Plot sub\n" if ($verbose);
	$st_canvas->delete('stmain');
	$gap_canvas->delete('gapmain');
	$lf_canvas->delete('lfmain');
	$rf_canvas->delete('rfmain');
	$ff_canvas->delete('ffmain');
	
	$st_canvas->createImage(10,10,-tag=>'stmain',-image=>$st_img, -anchor=>'nw');
	$gap_canvas->createImage(10,10,-tag=>'gapmain',-image=>$gap_img, -anchor=>'nw');
	$lf_canvas->createImage(10,10,-tag=>'lfmain',-image=>$lf_img, -anchor=>'nw');
	$rf_canvas->createImage(10,10,-tag=>'rfmain',-image=>$rf_img, -anchor=>'nw');
	$ff_canvas->createImage(10,10,-tag=>'ffmain',-image=>$ff_img, -anchor=>'nw');
	
	$record_label = $current_records;
}
sub giantize {
	print "Giantize sub\n" if ($verbose);
	my $graph = shift;
	my $mode = shift;
	$graph->set_x_axis_font(gdGiantFont) if (!$mode); 	
	$graph->set_y_axis_font(gdGiantFont);	
	$graph->set_x_label_font(gdGiantFont) if (!$mode);
	$graph->set_y_label_font(gdGiantFont);	
	$graph->set_title_font(gdGiantFont);	
	return $graph;
}

sub poly_play {
	print "poly_play sub\n" if ($verbose);
	my $what = shift;
	my @labs = @res;
	@labs = @cods if ($graph_mode =~ /cod/);
	foreach(@labs) {
		$st_poly_res = $_ if ($what eq 'st');
		$gap_poly_res = $_ if ($what eq 'gap');
		$lf_poly_res = $_ if ($what eq 'lf');
		$rf_poly_res = $_ if ($what eq 'rf');
		$ff_poly_res = $_ if ($what eq 'ff');
		update_poly_res($what);
		$mw->update;
		select(undef,undef,undef,$st_p_play_time) if ($what eq 'st');
		select(undef,undef,undef,$gap_p_play_time) if ($what eq 'gap');
		select(undef,undef,undef,$lf_p_play_time) if ($what eq 'lf');
		select(undef,undef,undef,$rf_p_play_time) if ($what eq 'rf');
		select(undef,undef,undef,$ff_p_play_time) if ($what eq 'ff');
	}
}

sub update_poly_res { 
	print "update_poly_res sub\n" if ($verbose);
	my $what = shift;
	if ($what eq 'st') {
		$st_canvas->delete('stpoly');
		@tmp = split (/-/,$st_poly_res);
		($st_poly_plot,$st_poly_data) = poly_res_plot(\@st_seq_ok,$st_poly_res,"Poly $st_poly_res in the stretches",10) if ($tmp[0] eq $residue);
		($st_poly_plot,$st_poly_data) = poly_res_plot(\@st_seq_ok,$st_poly_res,"Poly $st_poly_res in the stretches") if ($tmp[0] ne $residue);
		$st_poly_img = $mw->Photo(-format=>'GIF', -data=>$st_poly_plot->gif);
		$st_canvas->createWindow(50,335,-window=>$st_poly_log_label);
		$st_canvas->createWindow(80,335,-window=>$st_poly_log);
		$st_canvas->createWindow(160,335,-window=>$st_poly_selector);
		$st_canvas->createWindow(260,335,-window=>$st_poly_play);
		$st_canvas->createWindow(335,335,-window=>$st_poly_play_time);
		$st_canvas->createImage(20,350,-tag=>'stpoly', -image=>$st_poly_img, -anchor=>'nw');
	}
	if ($what eq 'gap') {
		$gap_canvas->delete('gappoly');
		@tmp = split (/-/,$gap_poly_res);		
		($gap_poly_plot,$gap_poly_data) = poly_res_plot(\@st_seq_ok,$gap_poly_res,"Poly $gap_poly_res in the gaps",10) if ($tmp[0] eq $residue);
		($gap_poly_plot,$gap_poly_data) = poly_res_plot(\@st_seq_ok,$gap_poly_res,"Poly $gap_poly_res in the gaps") if ($tmp[0] ne $residue);
		$gap_poly_img = $mw->Photo(-format=>'GIF', -data=>$gap_poly_plot->gif);
		$gap_canvas->createWindow(50,335,-window=>$gap_poly_log_label);
		$gap_canvas->createWindow(80,335,-window=>$gap_poly_log);
		$gap_canvas->createWindow(160,335,-window=>$gap_poly_selector);
		$gap_canvas->createWindow(260,335,-window=>$gap_poly_play);
		$gap_canvas->createWindow(335,335,-window=>$gap_poly_play_time);
		$gap_canvas->createImage(20,350,-tag=>'gappoly', -image=>$gap_poly_img, -anchor=>'nw');
	}
	if ($what eq 'lf') {
		$lf_canvas->delete('lfpoly');
		($lf_poly_plot,$lf_poly_data) = poly_res_plot(\@lf_seq_ok,$lf_poly_res,"Poly $lf_poly_res in the left flanks"); 
		$lf_poly_img = $mw->Photo(-format=>'GIF', -data=>$lf_poly_plot->gif);
		$lf_canvas->createWindow(50,335,-window=>$lf_poly_log_label);
		$lf_canvas->createWindow(80,335,-window=>$lf_poly_log);
		$lf_canvas->createWindow(160,335,-window=>$lf_poly_selector);
		$lf_canvas->createWindow(260,335,-window=>$lf_poly_play);
		$lf_canvas->createWindow(335,335,-window=>$lf_poly_play_time);
		$lf_canvas->createImage(20,350,-tag=>'lfpoly', -image=>$lf_poly_img, -anchor=>'nw');
	}
	if ($what eq 'rf') {
		$rf_canvas->delete('rfpoly');
		($rf_poly_plot,$rf_poly_data) = poly_res_plot(\@rf_seq_ok,$rf_poly_res,"Poly $rf_poly_res in the right flanks"); 
		$rf_poly_img = $mw->Photo(-format=>'GIF', -data=>$rf_poly_plot->gif);
		$rf_canvas->createWindow(50,335,-window=>$rf_poly_log_label);
		$rf_canvas->createWindow(80,335,-window=>$rf_poly_log);
		$rf_canvas->createWindow(160,335,-window=>$rf_poly_selector);
		$rf_canvas->createWindow(260,335,-window=>$rf_poly_play);
		$rf_canvas->createWindow(335,335,-window=>$rf_poly_play_time);
		$rf_canvas->createImage(20,350,-tag=>'rfpoly', -image=>$rf_poly_img, -anchor=>'nw');
#		$ff_canvas->createImage(450,350,-tag=>'plot',-image=>$rf_poly_plot, -anchor=>'nw');
	}
	if ($what eq 'ff') {
		$ff_canvas->delete('ffpoly');
		@ff_seq_ok = (@lf_seq_ok,@rf_seq_ok);
		($ff_poly_plot,$ff_poly_data) = poly_res_plot(\@ff_seq_ok,$ff_poly_res,"Poly $ff_poly_res in both flanks"); 
		$ff_poly_img = $mw->Photo(-format=>'GIF', -data=>$ff_poly_plot->gif);
		$ff_canvas->createWindow(50,335,-window=>$ff_poly_log_label);
		$ff_canvas->createWindow(80,335,-window=>$ff_poly_log);
		$ff_canvas->createWindow(160,335,-window=>$ff_poly_selector);
		$ff_canvas->createWindow(260,335,-window=>$ff_poly_play);
		$ff_canvas->createWindow(335,335,-window=>$ff_poly_play_time);
		$ff_canvas->createImage(20,350,-tag=>'ffpoly', -image=>$ff_poly_img, -anchor=>'nw');
	}
}	
sub poly_res_plot {
	print "poly_res_plot sub\n" if ($verbose);
	my $seq = shift;
	my $res = shift;
	my $title = shift;
	my $thick_n = shift;
	my $mode = 'count';
	$mode = 'log' if ($title =~ /stretches/ && $st_poly_islog);
	$mode = 'log' if ($title =~ /gaps/ && $gap_poly_islog);
	$mode = 'log' if ($title =~ /left/ && $lf_poly_islog);
	$mode = 'log' if ($title =~ /right/ && $rf_poly_islog);
	$mode = 'log' if ($title =~ /flanks/ && $ff_poly_islog);
	my $type = 'stretch';
	$type = 'gaps' if ($title =~ /gaps/);
	$type = 'flank' if ($title =~ /flanks/);
	my $x = '';
	my $y = '';
	my $gr = '';
	my $img = '';
	my $plot = '';
	my %init = ();
	my @data = ();
	($x, $y) = poly_analysis($seq,$res,$mode,$type); #$res is a pointer, no need for dereferenceing firts...
	$init{'x_label'} = "Length of poly $res";
	$init{'y_label'} = "Counts" if ($mode eq 'count');
	$init{'y_label'} = "Log10 counts" if ($mode eq 'log');
	$init{'title'} = $title;
	$init{'x_tick_number'} = $thick_n if ($thick_n);
	$gr = GD::Graph::bars->new(400, 300);
	$gr->set(%init);
	$gr->set(dclrs=>[qw/black/]);
	$gr = giantize($gr);
	@data = ($x,$y);
	$plot = $gr->plot(\@data);
#	$img = $mw->Photo(-format=>'GIF', -data=>$plot->gif);
	return ($plot,\@data);
}
sub poly_analysis {
	print "poly_analysis sub\n" if ($verbose);
	my $sequences = shift;
	my @sequences = @$sequences;
	my $res = shift;
	my $mode = shift;
	my $type = shift;
	@tmp = split (/-/,$res) if ($graph_mode =~ /cod/);
	$res = $tmp[1] if ($graph_mode =~ /cod/);
	my %cnt = ();
	my @tup_x = ();
	my @tup_y = ();
	my $maxlen = 0;
	my $len = '';
	foreach my $seq (@sequences) {
		while($seq =~ /((:?[$res])+)/g) {
			$match = $1;
			if ($graph_mode =~ /cod/) {
				$pos = pos($seq)-length($match)+1;
				if (($pos-1)%3 != 0) {
					pos($seq)++;
					next;
			}
			}
			$len = length($match);
			$len /= 3 if ($graph_mode =~ /cod/);
			$cnt{$len}++;
			$maxlen = $len if ($len > $maxlen);
#			print "SEQ:$seq\nMATCH: $match at $pos\nLEN: ",length($match)," = $len ($cnt{$len})\n" if ($graph_mode =~ /cod/ && $res eq 'CAG');
#			<STDIN>  if ($graph_mode =~ /cod/ && $res eq 'CAG');
		}
	}
	$maxlen = $gap_max_size if ($type eq 'gaps'); #this uniforms the length of the abscissa for gaps
	$maxlen = $flank_length if ($type eq 'flank'); #this uniforms the length of the abscissa for flanks
	foreach (1..$maxlen) {
		push (@tup_x, $_);
		push (@tup_y, $cnt{$_})	if ($cnt{$_} && $mode eq 'count');
		push (@tup_y, log($cnt{$_})/log(10)) if ($cnt{$_} && $mode eq 'log');
		push (@tup_y, 0) if (!$cnt{$_});
	}
	@tup_x = qw/1 2 3/ if (!@tup_y);
	@tup_y = qw/0 0 0/ if (!@tup_y);
	return (\@tup_x,\@tup_y);
}

sub topo_play {
	print "poly_play sub\n" if ($verbose);
	my $what = shift;
	my @labs = @res;
	@labs = @cods if ($graph_mode =~ /cod/);
#	if ($what eq 'st') {
		foreach(@labs) {
			$st_topo_res = $_ if ($what eq 'st');
			$gap_topo_res = $_ if ($what eq 'gap');
			$lf_topo_res = $_ if ($what eq 'lf');
			$rf_topo_res = $_ if ($what eq 'rf');
			$ff_topo_res = $_ if ($what eq 'ff');
			update_topology($what);
			$mw->update;
			select(undef,undef,undef,$st_t_play_time) if ($what eq 'st');
			select(undef,undef,undef,$gap_t_play_time) if ($what eq 'gap');
			select(undef,undef,undef,$lf_t_play_time) if ($what eq 'lf');
			select(undef,undef,undef,$rf_t_play_time) if ($what eq 'rf');
			select(undef,undef,undef,$ff_t_play_time) if ($what eq 'ff');
		}
	#}
}
sub update_topology {
	print "update_topology sub\n" if ($verbose);
	my $what = shift;
	if ($what eq 'stXXX') {
		$st_canvas->delete('sttopo');
		($st_topo_plot,undef) = topology_plot(\@st_seq_ok,$st_topo_res,"Topology of $st_poly_res in the stretches",'str',10);
		$st_topo_img = $mw->Photo(-format=>'GIF', -data=>$st_topo_plot->gif);
#		$st_topo_img = topology_plot(\@st_seq_split,$st_topo_res,"Poly $st_poly_res in the stretch",'str') if ($st_topo_res ne $residue);
		$st_canvas->createWindow(450,335,-window=>$st_topo_log_label);
		$st_canvas->createWindow(480,335,-window=>$st_topo_log);
		$st_canvas->createWindow(560,335,-window=>$st_topo_selector);
		$st_canvas->createWindow(660,335,-window=>$st_topo_play);
		$st_canvas->createWindow(735,335,-window=>$st_topo_play_time);
		$st_canvas->createImage(420,350,-tag=>'sttopo', -image=>$st_topo_img, -anchor=>'nw');
	}
	if ($what eq 'gapXXX') {
		$gap_canvas->delete('gaptopo');
		($gap_topo_plot,undef) = topology_plot(\@st_seq_ok,$gap_topo_res,"Topology of $gap_poly_res in the gaps",'str',10);
		$gap_topo_img = $mw->Photo(-format=>'GIF', -data=>$gap_topo_plot->gif);
#		$st_topo_img = topology_plot(\@st_seq_split,$st_topo_res,"Poly $st_poly_res in the stretch",'str') if ($st_topo_res ne $residue);
		$gap_canvas->createWindow(450,335,-window=>$gap_topo_log_label);
		$gap_canvas->createWindow(480,335,-window=>$gap_topo_log);
		$gap_canvas->createWindow(560,335,-window=>$gap_topo_selector);
		$gap_canvas->createWindow(660,335,-window=>$gap_topo_play);
		$gap_canvas->createWindow(735,335,-window=>$gap_topo_play_time);
		$gap_canvas->createImage(420,350,-tag=>'gaptopo', -tag=>'sttopo',-image=>$gap_topo_img, -anchor=>'nw');
	}
	if ($what eq 'lf') {
		$lf_canvas->delete('lftopo');
		my @lf_seq_rev_ok = ();
		foreach (@lf_seq_ok) {
			@tmp = ();
			if ($graph_mode =~ /cod/) {
				while ($_ =~ /(...)/g) {
					$s = '';
					$s = $1;
					push @tmp,$s;
				}
			} else {
				@tmp = split(//,$_);
			}
			@tmp = reverse @tmp;
			$rev = join "",@tmp;
			push (@lf_seq_rev_ok, $rev); #distance is to be interopreted in the opposite direction for left flank...
		}
		($lf_topo_plot,$lf_topo_data) = topology_plot(\@lf_seq_rev_ok,$lf_topo_res,"Topology of $lf_topo_res in the left flanks",'fla'); 
		$lf_topo_img = $mw->Photo(-format=>'GIF', -data=>$lf_topo_plot->gif);
		$lf_canvas->createWindow(450,335,-window=>$lf_topo_log_label);
		$lf_canvas->createWindow(480,335,-window=>$lf_topo_log);
		$lf_canvas->createWindow(560,335,-window=>$lf_topo_selector);
		$lf_canvas->createWindow(660,335,-window=>$lf_topo_play);
		$lf_canvas->createWindow(735,335,-window=>$lf_topo_play_time);
		$lf_canvas->createImage(420,350,-tag=>'lftopo', -image=>$lf_topo_img, -anchor=>'nw');
	}
	if ($what eq 'rf') {
		$rf_canvas->delete('rftopo');
		($rf_topo_plot,$rf_topo_data) = topology_plot(\@rf_seq_ok,$rf_topo_res,"Topology of $rf_topo_res in the right flanks",'fla'); 
		$rf_topo_img = $mw->Photo(-format=>'GIF', -data=>$rf_topo_plot->gif);
		$rf_canvas->createWindow(450,335,-window=>$rf_topo_log_label);
		$rf_canvas->createWindow(480,335,-window=>$rf_topo_log);
		$rf_canvas->createWindow(560,335,-window=>$rf_topo_selector);
		$rf_canvas->createWindow(660,335,-window=>$rf_topo_play);
		$rf_canvas->createWindow(735,335,-window=>$rf_topo_play_time);
		$rf_canvas->createImage(420,350,-tag=>'rftopo', -image=>$rf_topo_img, -anchor=>'nw');
#		$ff_canvas->createImage(450,350,-tag=>'plot',-image=>$rf_img, -anchor=>'nw');
	}
	if ($what eq 'ff') {
		$ff_canvas->delete('fftopo');
		my @lf_seq_rev_ok = ();
		foreach (@lf_seq_ok) {
			@tmp = ();
			if ($graph_mode =~ /cod/) {
				while ($_ =~ /(...)/g) {
					$s = '';
					$s = $1;
					push @tmp,$s;
				}
			} else {
				@tmp = split(//,$_);
			}
			@tmp = reverse @tmp;
			$rev = join "",@tmp;
#			print " $_ -> $rev \n";
			push (@lf_seq_rev_ok, $rev); #distance is to be interopreted in the opposite direction for left flank...
		}
#		<STDIN>;
		@ff_seq_ok = (@lf_seq_rev_ok,@rf_seq_ok);
		($ff_topo_plot,$ff_topo_data) = topology_plot(\@ff_seq_ok,$ff_topo_res,"Topology of $ff_topo_res in both flanks",'fla'); 
		$ff_topo_img = $mw->Photo(-format=>'GIF', -data=>$ff_topo_plot->gif);
		$ff_canvas->createWindow(450,335,-window=>$ff_topo_log_label);
		$ff_canvas->createWindow(480,335,-window=>$ff_topo_log);
		$ff_canvas->createWindow(560,335,-window=>$ff_topo_selector);
		$ff_canvas->createWindow(660,335,-window=>$ff_topo_play);
		$ff_canvas->createWindow(735,335,-window=>$ff_topo_play_time);
		$ff_canvas->createImage(420,350,-tag=>'fftopo', -image=>$ff_topo_img, -anchor=>'nw');
	}
}
sub topology_plot {
	print "topology_plot sub\n" if ($verbose);
	my $seq = shift;
	my $res = shift;
	my $title = shift;
	my $mode = shift;
	my $thick_n = shift;
	my $logmode = 'count';
	$logmode = 'log' if ($title =~ /stretches/ && $st_topo_islog);
	$logmode = 'log' if ($title =~ /gaps/ && $gap_topo_islog);
	$logmode = 'log' if ($title =~ /left/ && $lf_topo_islog);
	$logmode = 'log' if ($title =~ /right/ && $rf_topo_islog);
	$logmode = 'log' if ($title =~ /both/ && $ff_topo_islog);
	my $type = 'stretch';
	$type = 'gaps' if ($title =~ /gaps/);
	$type = 'flank' if ($title =~ /flanks/);
	my $x = '';
	my $y = '';
	my $color = '';
	my $gr = '';
	my $img = '';
	my $plot = '';
	my %init = ();
	my @data = ();
#	print "\n --- $type ---\n";
	($x, $y, $color) = topology_analysis($seq,$res,$mode,$logmode,$type); #$res is a pointer, no need for dereferenceing firts...
	$init{'x_label'} = "Position of $res";
	$init{'x_label'} = "% Position of $res" if ($mode eq 'str');
	$init{'y_label'} = "Background ratio" if ($logmode eq 'count');
	$init{'y_label'} = "Log10 background ratio" if ($logmode eq 'log');
	$init{'title'} = $title;
	$init{'x_tick_number'} = $thick_n if ($thick_n);
	$gr = GD::Graph::bars->new(400, 300);
	$gr->set(%init);
#	$gr->set(dclrs=>[qw/black/]);	
	$gr->set(dclrs=>$color, cycle_clrs => 1);	
	$gr = giantize($gr);
	@data = ($x,$y);
	$plot = $gr->plot(\@data);
	return ($plot,\@data);
}

sub topology_analysis {
	print "topology_analysis sub\n" if ($verbose);
	my $sequences = shift;
	my @sequences = @$sequences;
	my $totseq = scalar @sequences;
	my $res = shift;
	my $mode = shift;
	my $logmode = shift;
	my $type = shift;
	my $maxlen = 0;
	my $syn_cod = '';
	my $res_ok = $res;
	my $res_tmp = $res;
	$res_tmp =~ s/-...// if ($graph_mode =~ /cod/); #this catches the residue and decides wether to use glob (with Qs) or glob_gap (no Qs)
	my $glob = $global_perc_gap{"$tuple"."@"."$res"} if ($res_tmp ne $residue);
	$glob = $global_perc{"$tuple"."@"."$res"} if ($res_tmp eq $residue);
#	foreach (sort keys %global_perc) {
#		print "--> $_ -> $global_perc{$_}\t-> $global_perc_gap{$_}\n";
#	}
#	print "\n$mode -> $tuple @ $res -> $glob\n";
	$res_tmp = $res;
	$res_tmp =~ s/.-// if ($graph_mode =~ /cod/); #this catches the residue and decides wether to use glob (with Qs) or glob_gap (no Qs)
	my %cnt = ();
	my %syn_cnt = ();
	my @pos_x = ();
	my @pos_y = ();
	my @color = ();
	my $position = '';
	foreach my $seq (@sequences) {
		@tmp = ();
		@tmp = split(//,$seq) if ($graph_mode =~ /res/); #an array with residues
		if ($graph_mode =~ /cod/) {
			while ($seq =~ /(...)/g) {
				push(@tmp,$1); # an array with codons
			}
		}
		$maxlen = scalar(@tmp) if ($mode eq 'fla' && scalar(@tmp) > $maxlen); # scalar(@tmp) expresses length of sequence or n\B0 of codons...
		$maxlen = 100 if ($mode eq 'str');
		foreach (0..$#tmp) {
			print "$tmp[$_] =~ $res_tmp\n" if ($res_tmp =~ /AV/);
			if ($res_tmp =~ $tmp[$_]) { #this is for residue (or codon) in use
				$position = $_+1;
				$position = int($position/scalar(@tmp)*100) if ($mode eq 'str');
				$cnt{$position}++;
			}
		}
	}
	$maxlen = $gap_max_size if ($type eq 'gaps'); #this uniforms the length of the abscissa for gaps
	$maxlen = $flank_length if ($type eq 'flank'); #this uniforms the length of the abscissa for flanks
	foreach my $posi (1..$maxlen) { #was $maxlen+1, dunno why...
		$val = 0;
		$perc = 0;
		push (@pos_x,$posi);
		$cnt{$posi} = 0 if (!$cnt{$posi});
		$perc = ($cnt{$posi}/$totseq*100);
		$val = $perc/$glob;
#		($pval,undef,undef) = p_value($cnt{$posi},$totseq,$res_ok,'st');
#		push (@color,'lgreen') if ($pval <= $ratio_t && $perc >= $global_perc{$tuple."@".$res_ok}); 
#		push (@color,'lred') if ($pval <= $ratio_t && $perc < $global_perc{$tuple."@".$res_ok}); 
#		push (@color,'black') if ($pval > $ratio_t); 
		push (@color,'lgreen') if ($perc/$global_perc{$tuple."@".$res_ok} >= $ratio_t); 
		push (@color,'lred') if ($perc/$global_perc{$tuple."@".$res_ok} <= 1/$ratio_t); 
		push (@color,'black') if ($perc/$global_perc{$tuple."@".$res_ok} > 1/$ratio_t && $perc/$global_perc{$tuple."@".$res_ok} < $ratio_t); 
		push (@pos_y,$val) if ($val && $logmode eq 'count');
		push (@pos_y,log($val)/log(10)) if ($val && $logmode eq 'log');
		push (@pos_y,0) if (!$val);
	}
	return (\@pos_x,\@pos_y,\@color);
}

sub go_analysis {
	$go_canvas->delete('go_graph');
	my $content = $selected_text1->get('1.0','end');
	my @content = split (/\n/,$content);
	shift @content;
	my $go_ind = $go_func_col if ($go_sel eq 'go_func');
	$go_ind = $go_proc_col if ($go_sel eq 'go_proc');
	$go_ind = $go_comp_col if ($go_sel eq 'go_comp');
	$go_ind = $omim_col if ($go_sel eq 'omim');
	my %go_cnt = ();
	my %go_conv = ();
	my @go_x = ();
	my @go_y = ();
	my $tot = 0;
	foreach(@content) {
		@tmp1 = split (/\t/,$_);
		next if ($tmp1[$go_ind] eq '---');
		$tot++;
		@tmp2 = split(/;/,$tmp1[$go_ind]);
		foreach(@tmp2) {
			if ($_ =~ /GO/) {
				@tmp3 = split (/:/,$_);
				$go_cnt{$tmp3[1]}++;
				$go_conv{$tmp3[1]} = $tmp3[2]; #substr($tmp3[2],0,50);
			}
			if ($_ =~ /COG/) { # NCBI bacteria have COG instead of GO in the go_fun field...
				$_ =~ /^(COG\d\d\d\d)(\w)$/;
				$go_cnt{$1}++;
				$go_conv{$1} = $2; #substr($tmp3[2],0,50);
			}
		}
	}
	return if (!%go_cnt);
	my @go_extremes = sort {$a <=> $b} values(%go_cnt);
	$go_extrem_label = "$tot records, count range $go_extremes[0] - $go_extremes[$#go_extremes]";
	
	foreach(sort {$go_cnt{$b} <=> $go_cnt{$a}}keys(%go_cnt)) {
		$go_perc = sprintf("%.2f",$go_cnt{$_}/$tot*100);
		next if ($go_mode eq 'raw' && $go_cnt{$_} < $go_count);
		next if ($go_mode eq 'perc' && $go_perc < $go_count);
		push (@go_x,$_) if ($go_what eq 'code');
		push (@go_x,$go_conv{$_}) if ($go_what eq 'name');
		push (@go_y, $go_cnt{$_}) if ($go_mode eq 'raw');
		push (@go_y, $go_perc) if ($go_mode eq 'perc');
		
	}
	$go_init{'x_labels_vertical'} = 1;
	$go_init{'y_label'} = "Counts" if ($go_mode eq 'raw');
	$go_init{'y_label'} = "Percent" if ($go_mode eq 'perc');
	$go_init{'title'} = "distribution of $go_sel";
	$xdim = '800' if ((scalar(@go_x)*10) <= 800);
	$xdim = scalar(@go_x)*10 if ((scalar(@go_x)*10) > 800);
	$go_gr = GD::Graph::bars->new($xdim, 600);
	$go_gr->set(%go_init);
	$go_gr = giantize($go_gr,'1');
	@go_data = (\@go_x,\@go_y);
	$go_plot = $go_gr->plot(\@go_data);
	$go_img = $mw->Photo(-format=>'GIF', -data=>$go_plot->gif);
	$go_canvas->configure(-scrollregion=>[40,40,$xdim,600], -xscrollincrement => 1, -xscrollcommand=>['set',$go_scroll]);
	$go_canvas->createImage(40,40,-tags=>'go_graph',-image=>$go_img, -anchor =>'nw');
}
sub go_scroll{
 my $fraction = $_[1];
 $go_canvas->xviewMoveto($fraction);
}

sub write_all {
	print "write_all sub\n" if ($verbose);
	my $which = $nb->info("focus");
	foreach (qw/go_res go_cod gaps left right both stretch/) {
		next if ($_ eq  'summary_cod' && !$summary_cod1_plot);
		$nb->raise($_);
		&write_current;
	}
	$nb->raise($which);
}
sub write_current {
	print "write_current sub\n" if ($verbose);
	my $which = $nb->info("focus");
	$filter_full_file = '';
	if ($filter) {
		foreach(0..$#filter_choices) {
			$filter_mode_file = $filter_to_file[$_] if ($filter_choices[$_] eq $filter_mode);
		}
		$filter_full_file = ' (filter='.$filter_on."_".$filter_mode_file."_".$filter.')';
	}
	if ($which eq 'left') {
		$fname1 = "left_flanks_tup_$tuple Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname2 = "left_flanks_poly_$lf_poly_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname3 = "left_flanks_topology_$lf_topo_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		printout($fname1,$lf_plot,'gif');
		printout($fname2,$lf_poly_plot,'gif');
		printout($fname3,$lf_topo_plot,'gif');
	}
	if ($which eq 'right') {
		$fname1 = "right_flanks_tup_$tuple Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname2 = "right_flanks_poly_$rf_poly_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname3 = "right_flanks_topology_$rf_topo_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		printout($fname1,$rf_plot,'gif');
		printout($fname2,$rf_poly_plot,'gif');
		printout($fname3,$rf_topo_plot,'gif');
	}
	if ($which eq 'both') {
		$fname1 = "both_flanks_tup_$tuple Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname2 = "both_flanks_poly_$ff_poly_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname3 = "both_flanks_topology_$ff_topo_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		printout($fname1,$ff_plot,'gif');
		printout($fname2,$ff_poly_plot,'gif');
		printout($fname3,$ff_topo_plot,'gif');
	}
	if ($which eq 'stretch') {
		$fname1 = "stretches_tup_$tuple Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname2 = "stretches_poly_$st_poly_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname3 = "stretches_topology_$st_topo_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		printout($fname1,$st_plot,'gif');
		printout($fname2,$st_poly_plot,'gif');
#		printout($fname3,$st_topo_plot,'gif');
	}
	if ($which eq 'gaps') {
		$fname1 = "gaps_tup_$tuple Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname2 = "gaps_poly_$gap_poly_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		$fname3 = "gaps_topology_$gap_topo_res Len_$len1-to-$len2 on $avail_records records".$filter_full_file.".gif";
		printout($fname1,$gap_plot,'gif');
		printout($fname2,$gap_poly_plot,'gif');
#		printout($fname3,$gap_topo_plot,'gif');
	}
	if ($which eq 'summary_res') {
		$fname1 = "summary_res_len_dist_bin_$bin1 on $avail_records records".$filter_full_file.".gif";
		$fname2 = "summary_res_len_vs_$residue% on $avail_records records".$filter_full_file.".gif";
		$fname3 = "summary_res_len_vs_pos% on $avail_records records".$filter_full_file.".gif";
		printout($fname1,$go1_plot,'gif');
		printout($fname2,$go2_plot,'draw');
		printout($fname3,$go3_plot,'draw');
	}
	if ($which eq 'summary_cod') {
		$fname1 = "summary_cod_dist_pure%_bin_$bin2 on $avail_records records".$filter_full_file.".gif";
		$fname2 = "summary_cod_len_vs_pure% on $avail_records records".$filter_full_file.".gif";
		printout($fname1,$summary_cod1_plot,'gif');
		printout($fname2,$summary_cod2_plot,'draw');
	}
	if ($which eq 'go') {
		$fname1 = "go distribution on $avail_records records".$filter_full_file.".gif";
		printout($fname1,$summary_cod1_plot,'gif');
	}
}

sub printout {
	print "printout sub\n" if ($verbose);
	my $fname = shift;
	my $what = shift;
	my $mode = shift;
	open (OUT,">$path/$fname");
	binmode OUT;
	print OUT $what->gif if ($mode eq 'gif');
	print OUT $what if ($mode eq 'draw');
	close OUT;
}

sub printout_one {
	print "printout_one sub \n"  if ($verbose);
	my $arg = shift;
	&associate;
	my @what = $arg->gettags('current');
	my $plot = $label_2_img{$what[0]};
	my $mode = $label_2_mode{$what[0]};
	my $fname = $mw->getSaveFile;
	return if (!$fname);
	$fname .= ".gif" if ($fname !~ /\.gif/);
	open (OUT,">$fname");
	binmode OUT;
	print OUT $plot->gif if ($mode eq 'gif');
	print OUT $plot if ($mode eq 'draw');
	close OUT;
}

sub get_data {
	print "get_data sub \n"  if ($verbose);
	my $arg = shift;
	&associate;
	my @what = $arg->gettags('current');
	print "$go_canvas -> $arg -> ",join " ", @what;
	my $data = $label_2_data{$what[0]};
	my @data = @$data;
	my @data1 = @{$data[0]};
	my @data2 = @{$data[1]};
	my @data3 = @{$data[2]} if (scalar @data == 3);
	my $seldata = '';
	foreach(0..$#data1) {
		$seldata .= $data1[$_]."\t".sprintf("%.2f",$data2[$_])."\n" if (scalar @data < 3);
		$seldata .= $data1[$_]."\t".sprintf("%.2f",$data2[$_])."\t".sprintf("%.2f",$data3[$_])."\n" if (scalar @data == 3);
	}
	$selected_text2->Contents($seldata);
	$nb->raise('selected');
}

sub save {
	print "save sub\n" if ($verbose);
	my $what = shift;
	&write_current if ($what eq 'current');
	&write_all if ($what eq 'all');
}
sub count { # useless, the count_new is better since can catch singletons, couplets triplets and so on 
	print "count sub\n" if ($verbose);
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
	print "count_new sub\n" if ($verbose);
	my $seq = shift;
	my $tup = shift;
	$seq =~ s/ //g;
#	$seq =~ s/-//g;
	my $num;
	my $res = '';
	my $list = '';
	my @list = ();
	foreach my $tuple (1..$tup) { #this should allow the count procedure to cope for couplets, triplets and so on
		foreach $search (@res) {
			$num = 0;
			$key = $search;
			$key .= '+' if ($tuple > 1);
			while ($seq =~ /($key)/g) {
				$num++ if (length($1) == $tuple);
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

sub associate {
	$label_2_img{'lfmain'} = $lf_plot;
	$label_2_img{'lfpoly'} = $lf_poly_plot;
	$label_2_img{'lftopo'} = $lf_topo_plot;
	$label_2_img{'rfmain'} = $rf_plot;
	$label_2_img{'rfpoly'} = $rf_poly_plot;
	$label_2_img{'rftopo'} = $rf_topo_plot;
	$label_2_img{'ffmain'} = $ff_plot;
	$label_2_img{'ffpoly'} = $ff_poly_plot;
	$label_2_img{'fftopo'} = $ff_topo_plot;
	$label_2_img{'stmain'} = $st_plot;
	$label_2_img{'stpoly'} = $st_poly_plot;
	$label_2_img{'gapmain'} = $gap_plot;
	$label_2_img{'gappoly'} = $gap_poly_plot;
	$label_2_img{'sumres1'} = $go1_plot;
	$label_2_img{'sumres2'} = $go2_plot;
	$label_2_img{'sumres3'} = $go3_plot;
	$label_2_img{'sumcod1'} = $summary_cod1_plot;
	$label_2_img{'sumcod2'} = $summary_cod2_plot;
	$label_2_img{'go_graph'} = $go_plot;
	$label_2_mode{'lfmain'} = 'gif';
	$label_2_mode{'lfpoly'} = 'gif';
	$label_2_mode{'lftopo'} = 'gif';
	$label_2_mode{'rfmain'} = 'gif';
	$label_2_mode{'rfpoly'} = 'gif';
	$label_2_mode{'rftopo'} = 'gif';
	$label_2_mode{'ffmain'} = 'gif';
	$label_2_mode{'ffpoly'} = 'gif';
	$label_2_mode{'fftopo'} = 'gif';
	$label_2_mode{'stmain'} = 'gif';
	$label_2_mode{'stpoly'} = 'gif';
	$label_2_mode{'gapmain'} = 'gif';
	$label_2_mode{'gappoly'} = 'gif';
	$label_2_mode{'sumres1'} = 'gif';
	$label_2_mode{'sumres2'} = 'draw';
	$label_2_mode{'sumres3'} = 'draw';
	$label_2_mode{'sumcod1'} = 'gif';
	$label_2_mode{'sumcod2'} = 'draw';
	$label_2_mode{'go_graph'} = 'gif';
	$label_2_data{'lfmain'} = $lf_gdata;
	$label_2_data{'lfpoly'} = $lf_poly_data;
	$label_2_data{'lftopo'} = $lf_topo_data;
	$label_2_data{'rfmain'} = $rf_gdata;
	$label_2_data{'rfpoly'} = $rf_poly_data;
	$label_2_data{'rftopo'} = $rf_topo_data;
	$label_2_data{'ffmain'} = $ff_gdata;
	$label_2_data{'ffpoly'} = $ff_poly_data;
	$label_2_data{'fftopo'} = $ff_topo_data;
	$label_2_data{'stmain'} = $st_gdata;
	$label_2_data{'stpoly'} = $st_poly_data;
	$label_2_data{'gapmain'} = $gap_gdata;
	$label_2_data{'gappoly'} = $gap_poly_data;
	$label_2_data{'sumres1'} = \@summary1_data;
	$label_2_data{'sumres2'} = \@summary2_data;
	$label_2_data{'sumres3'} = \@summary3_data;
	$label_2_data{'sumcod1'} = \@summary_cod1_data;
	$label_2_data{'sumcod2'} = \@summary_cod2_data;
	$label_2_data{'go_graph'} = \@go_data;
	}
