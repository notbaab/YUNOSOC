#!/usr/bin/perl
use strict;
use warnings;
use Term::ANSIColor;
use Time::HiRes qw/ time sleep /;
use POSIX qw(strftime);
use Getopt::Long qw(GetOptions);

Getopt::Long::Configure qw(gnu_getopt);
no warnings 'uninitialized';
# This is the directory where all tests exist.
my $RC_sh             = "RC";
my $ref_rc            = "testrunner_client";
my $html_output       = "results.html";
my $testing_directory = "tests";
my $rc_output_suffix  = "out";
my $rc_suffix         = "rc";
my $failedDir         = "failedTests";
my $p1_directory      = "project1";  # directory where all the project 1 tests are
my $p2_directory      = "project2";  # directory where all the project 2 tests are
my $start_date_text   = "";
my $finish_date_text  = "";
my $total_passed      = 0;
my $total_failed      = 0;
my $start_time        = 0;
my $finish_time       = 0;
my %rangePrefixes     = ();
my $project;
my $html;
my $index;
my $rc_counter;
my @rc_files;
my $rc_output_counter;
my @rc_output_files;
my @compile_times;
my @diff_outputs;
my @results; # An array of bools => true if passed, false if failed.
my $force;
my @skip;
my @only;
my $pass;
my $dir;
my $resultFile;
# Clean up any temporary files leftover since last time.
`rm -f $testing_directory/*.tmp`;
`rm -f $testing_directory/*.tmp1`;
`rm -f $testing_directory/*.tmp2`;
`rm $failedDir/*`; # could fail, nothing bad happens though

DoCommandLineArguments();
print "testing dir is $testing_directory";

if($resultFile){
  $html_output = $resultFile . ".html"
}
# can't test if we don't have a compiler to run...
if(!(-e $RC_sh)){
  print color "red";
  print "No RC executable found, please put one in the same directory\n";
  print color "reset";
  exit;
}

# make failed dir
if(!(-e $failedDir)) {
  print "Making dir";
  mkdir $failedDir, 0777;
}

# Let the user know what's happenin'
print color "blue";
print " Gathering list of files...";
print color "reset";

# Actually open the directory
opendir(DIR, $testing_directory) or die $!;

# Iterate through all rc files in the directory
$rc_counter = 0;

while (my $file = readdir(DIR)) {
  # We only want files
  next unless (-f "$testing_directory/$file");
  if ($file =~ m/\.$rc_suffix$/ && !CheckSkip($file)) {
    # Files matches regex, add to array.
    $rc_files[$rc_counter] = $file;
    $rc_counter++;
  } 
}
close(DIR);

# Did we find any rc files?
if (scalar(@rc_files) == 0) {
  print "no rc files found! Exiting.\n";
  exit 0;
} 

@rc_files = sort @rc_files;

# Finished checking that all files have output files associated with them.
print "done.\n";
print color "reset";


# We doin tests now
print " " . colored("Performing " . scalar(@rc_files) . " tests:", "underline") . "\n";

# Now compile and check each rc file.
my $tempTime1    = 0;
my $tempTime2    = 0;
my $compile_sum  = 0;
my $compile_avg  = 0;
$start_date_text = strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time()));
$start_time      = time;
for my $i (0 .. $#rc_files) {
  # Indent every file we test.
  print "   ";
  # Compile the rc file.
  $tempTime1 = time;
  my $in_file;
  my $out_file;
  if ($project == 1){
    # run project 1 command
    `./$RC_sh $testing_directory/$rc_files[$i] > $testing_directory/$rc_files[$i].tmp`;
    
    # Iterate through each line of the output and strip all lines starting with "Error"
    my $compiled_in  = "$testing_directory/$rc_files[$i].tmp";
    my $compiled_out = "$testing_directory/$rc_files[$i].tmp1";
    open $in_file,  "<", $compiled_in  or die "Could't open temporary file \"$compiled_in\": $!";
    open $out_file, ">", $compiled_out or die "Could't open temporary file \"$compiled_out\": $!";

    # Go through each line our compiler spit out into the temp file.
    while (my $line = <$in_file>) {
      if ($line =~ m/^(Error)/i) {
        # Don't save this line!
      } else {
        # Only save the line now.
        print $out_file $line;
      }
    }
  } else {
    # run project 2 command, we are only interested in the a.out output though. 
    # TODO: Need to modify this to take in object files
    `./$RC_sh $testing_directory/$rc_files[$i] &> /dev/null`;
    # system("make", "compile");
    my $tmp = `make compile &> /dev/null"`;
    if (-e "$testing_directory/$rc_files[$i].input") {
      `./a.out < $testing_directory/$rc_files[$i].input > $testing_directory/$rc_files[$i].tmp`;
    }else{
      `./a.out > $testing_directory/$rc_files[$i].tmp`;
    }
  }
  $tempTime2 = time;
  $compile_times[$i] = $tempTime2 - $tempTime1;
  $compile_sum += $compile_times[$i];


  
  # compile with the given test compiler or use matching out file for speed
  if (!(-e "$testing_directory/$rc_files[$i].out") || $force) {
    print color "blue";
    print "No file found or force flag true, making one with ref compiler";
    print color "reset";
    if ($project == 1){
      `$ref_rc $testing_directory/$rc_files[$i] > $testing_directory/$rc_files[$i].out`;
    } else {
      `$ref_rc $testing_directory/$rc_files[$i] &> /dev/null`;
      my $tmp = `make compile &> /dev/null"`;
      if (-e "$testing_directory/$rc_files[$i].input") {
        `./a.out < $testing_directory/$rc_files[$i].input > $testing_directory/$rc_files[$i].out`;
      } else {
        `./a.out > $testing_directory/$rc_files[$i].out`;
      }
    }
  }

  # Do the same for the reference output if we are testing project 1
  if ($project == 1) {
    my $compare_in  = "$testing_directory/$rc_files[$i].out";
    my $compare_out = "$testing_directory/$rc_files[$i].tmp2";
    open $in_file,  "<", $compare_in  or die "Couldn't open the correct output file \"$compare_in\": $!";
    open $out_file, ">", $compare_out or die "Couldn't open temporary file \"$compare_out\": $!";

    # Go through each line our compiler spit out into the temp file.
    while (my $line = <$in_file>) {
      if ($line =~ m/^(Error)/i) {
        # Don't save this line!
      } else {
        # Only save the line now.
        print $out_file $line;
      }
    }    
  }

  if ($project == 1) {
    # Close the intermediary files we've opened.
    close $in_file;
    close $out_file;    
  }

  # Perform a diff on the two files you've created.
  my $diff_result;
  if ($project == 1) {
    $diff_result = `diff $testing_directory/$rc_files[$i].tmp1 $testing_directory/$rc_files[$i].tmp2`;
  } else {
    $diff_result = `diff $testing_directory/$rc_files[$i].tmp $testing_directory/$rc_files[$i].out`;
  }

  # Print out a hyphen and then the number of this test.
  print "- Test " . ($i + 1) . ": ";

  # Make it look purdy. Format the output a little.
  if (($i + 1) <= 9) {
    print "  ";
  } elsif (($i + 1) <= 99) {
    print " ";
  }
  print "[";

  # Did the diff come up with anything?
  if ($diff_result ne "") {
    $diff_outputs[$i] = $diff_result;
    $results[$i]      = 0;
    print color "red";
    print "Failed";
    print color "reset";
    $total_failed++;
    # copy the failed file to a failed directory, along with the out files
    `cp $testing_directory/$rc_files[$i] $testing_directory/$rc_files[$i].tmp $testing_directory/$rc_files[$i].out $failedDir`
    
  } else {
    $diff_outputs[$i] = "";
    $results[$i]      = 1;
    print color "green";
    print "Passed";
    print color "reset";
    $total_passed++;
  }

  # Output the file name.
  print "] $rc_files[$i]\n";
}
$finish_time      = time;
$finish_date_text = strftime("%a, %d %b %Y %H:%M:%S %z", localtime(time()));
$compile_avg      = $compile_sum / scalar(@compile_times);

# =============================================================================================
# ================================= GENERATION OF HTML FILE ===================================
# =============================================================================================
`rm -f $html_output`;
open $html, ">", $html_output or die "Couldn't open $html_output to generate HTML breakdown: $!";
print $html '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">';
print $html '<html xmlns="http://www.w3.org/1999/xhtml">';
print $html '<head>';
print $html '<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />';
print $html "'<title>" . $testing_directory . " Compiler Test Results</title>'";
print $html "<script type='text/javascript'>";
print $html 'function changeTab(n){for(var r,i,t=1;t<=4;t++)r="tab"+t,i="tab"+t+"link",t==n?(document.getElementsByClassName(r)[0].style.display="block",document.getElementById(i).className="current_page_item"):(document.getElementsByClassName(r)[0].style.display="none",document.getElementById(i).className="")}function toggleRow(n){var i="test"+n+"deets",t=document.getElementById(i);t!=null&&(t.style.display=t.style.display=="block"?"none":"block")}function expandAll(n){for(var r,i,t=1;t<=n;t++)r="test"+t+"deets",i=document.getElementById(r),i!=null&&(i.style.display="block")}function collapseAll(n){for(var r,i,t=1;t<=n;t++)r="test"+t+"deets",i=document.getElementById(r),i!=null&&(i.style.display="none")};';
print $html '</script>';
print $html '<meta name="keywords" content="" />';
print $html '<meta name="description" content="" />';
print $html '<link href="http://fonts.googleapis.com/css?family=Open+Sans:400,300,600" rel="stylesheet" type="text/css" />';
print $html '<style type="text/css">';
print $html "html,body{height:100%}body{margin:0;padding:0;font-family:'Open Sans',sans-serif;background-color:#000;font-size:13px;font-weight:200;color:#454545}h1,h2,h3{margin:0;padding:0;font-weight:300;color:#221d1d}h2{font-size:2.5em}p,ol,ul{margin-top:0}p{line-height:200%}a{color:#2f2f2f}a:hover{text-decoration:none}a img{border:0}img.alignleft{float:left}img.alignright{float:right}img.aligncenter{margin:0 auto}hr{display:none}#expand_all,#collapse_all{font-size:12px;float:right}#detailed_results_row{padding-left:15px;padding-right:15px}#detailed_results_row:hover{background-color:#eee}#detailed_results_row_text{width:100%;cursor:pointer}.failed{background-color:#ffcece}#failed_text{float:right;color:red}#passed_text{float:right;color:#0c0}#diff_table{width:100%;border:0}#diff_left_header,#diff_right_header{text-align:center;border-bottom:1px solid #666;width:50%}#diff_yourcode,#diff_refcode{vertical-align:text-top;text-align:left}#diff_yourcode{border-right:1px solid #666}.diff_output{display:none}.tab1{display:block}.tab2{display:none}.tab3{display:none}.tab4{display:none}#wrapper{width:1200px;margin:0 auto;padding:0;background:#fff;box-shadow:0 0 10px 5px rgba(0,0,0,.1)}.container{width:980px;margin:0 auto}.clearfix{clear:both}#logo{width:960px;height:150px;margin:0 auto 30px auto;color:#000}#logo h1,#logo p{margin:0;padding:0}#logo h1{line-height:100px;letter-spacing:-1px;text-align:center;text-transform:lowercase;font-size:5em;color:#1f1f1f}#logo h1 span{color:#1f1f1f}#logo p{text-align:center;font-size:16px;color:#595959}#logo p a{color:#595959}#logo a{border:0;background:0;text-decoration:none;color:#1f1f1f}#menu{overflow:hidden;width:1100px;height:70px;margin:0 50px;background:#000;font-size:20px;color:#000}#menu ul{margin:0;padding:0 0;list-style:none;line-height:normal;text-align:center}#menu li{display:inline-block}#menu a{display:block;padding:0 40px;line-height:70px;text-decoration:none;text-align:center;font-size:14px;font-weight:200;color:#fff;border:0}#menu a:hover,#menu .current_page_item a{text-decoration:none;background-color:#333}#menu .last{border-right:0}#footer{overflow:hidden;width:1100px;height:100px;margin:0 auto;border-top:1px solid #cbcbcb}#footer p{margin:0;padding-top:40px;line-height:normal;text-align:center;color:#454545}#footer a{color:#2f2f2f}#footer-content{overflow:hidden;width:1100px;padding:50px;background:#ececec;text-shadow:1px 1px 0 #fff;color:#666}#footer-content h2{padding:0 0 30px;text-transform:uppercase;font-size:24px}#footer-content #fbox1{float:left;width:600px;margin-right:30px}#footer-content #fbox2{float:left;width:220px}#footer-content #fbox3{float:right;width:220px}#welcome{width:1100px;margin:0 auto;padding:30px 50px}#welcome .content{padding:0 0 40px}#welcome h2{padding:0 0 20px}#welcome h2 a{text-decoration:none;color:#000}#three-columns{overflow:hidden;width:1100px;margin:0 auto;padding:50px 50px 0}#three-columns .content{overflow:hidden;padding:0 0 50px}#artistic_box{margin-top:10px;margin-right:10px;float:left;background-color:#000;width:25px;height:25px}#three-columns h2{padding:0 0 20px;color:#000}#three-columns #column1{float:left;width:300px;margin-right:40px}#three-columns #column2{float:left;width:290px}#three-columns #column3{float:right;width:430px}#two-columns{overflow:hidden;width:1100px;margin:0 auto;padding:40px 50px 50px}#two-columns h2{padding:0 0 20px;color:#000}#two-columns #col1{float:right;width:740px}#two-columns #col2{float:left;width:320px}.list-style1{margin:0;padding:0;list-style:none}.list-style1 li{padding:20px 0;border-top:1px solid #d4d4d4}.list-style1 .date{font-weight:700;color:#212121}.list-style1 img{float:left;margin-right:25px}.list-style1 .first{padding-top:0;border-top:0}.list-style2{margin:0;padding:0 0 20px;list-style:none}.list-style2 li{padding:10px 0;border-top:1px solid #d4d4d4}.list-style2 .first{padding-top:0;border-top:0}.link-style{display:inline-block;margin-top:10px;padding:5px 15px;background:#000;border-radius:5px;letter-spacing:1px;text-decoration:none;text-shadow:1px 0 1px #5c1111;color:#fff}.link-style:hover{background:#333}#banner{width:1100px;margin:10px auto 0 auto}#src_table{width:100%;background-color:#FFFFFF;}#even_src_row:hover,#odd_src_row:hover{background-color:#DDDDDD;}#even_src_row{padding:2px;background-color:#FFF8DC;}#odd_src_row{padding:2px;background-color:#FFFFFF;}#line_col{width: 1px;border-right:1px solid #DDDDDD;}#src_col{padding-left:3px}";
print $html '</style>';
print $html '</head>';
print $html '<body>';
print $html '<div id="wrapper">';
print $html '<div id="header">';
print $html '<div id="logo">';
print $html '<h1><a href="#">compilers</a></h1>';
print $html '<p>Results from compiling ' . scalar(@rc_files) . ' test files</p>';
print $html '</div>';
print $html '</div>';
print $html '<div id="menu">';
print $html '<ul>';
print $html '<li id="tab1link" class="current_page_item"><a href="#" onclick="changeTab(1);">Overview</a></li>';
print $html '<li id="tab2link"><a href="#" onclick="changeTab(2);">Details</a></li>';
print $html '<li id="tab3link"><a href="#" onclick="changeTab(3);">Help</a></li>';
print $html '</ul>';
print $html '</div>';
print $html '<div id="three-columns" class="tab1">';
print $html '<div class="content">';
print $html '<div id="column1">';
print $html '<div id="artistic_box">&nbsp;</div>';
print $html '<h2>Results Overview</h2>';
print $html '<ul class="list-style2">';
print $html '<li class="first"><u>Total Tests:</u> ' . scalar(@rc_files) . '</li>';
print $html '<li><u>Total Passed:</u> ' . $total_passed . '</li>';
print $html '<li><u>Total Failed:</u> ' . $total_failed . '</li>';
print $html '<li><u>Score:</u> ' . (sprintf "%.2f", (($total_passed / scalar(@rc_files)) * 100.0)) . '%</li>';
print $html '</ul>';
print $html '<p><a href="#" class="link-style" onclick="changeTab(2);">Read More</a></p>';
print $html '</div>';
print $html '<div id="column2">';
print $html '<div id="artistic_box">&nbsp;</div>';
print $html '<h2>Compilation Info</h2>';
print $html '<ul class="list-style2">';
print $html '<li class="first"><u>Time Started:</u> ' . $start_date_text . '</li>';
print $html '<li><u>Time Ended:</u> ' . $finish_date_text . '</li>';
print $html '<li><u>Total Time:</u> ' . (sprintf "%.2f", ($finish_time - $start_time)) . ' seconds</li>';
print $html '<li><u>Average Time/File:</u> ' . (sprintf "%.3f", $compile_avg) . ' seconds</li>';
print $html '</ul>';
print $html '</div>';
print $html '<div id="column3">';
print $html '<div id="artistic_box">&nbsp;</div>';
print $html '<h2>What do I do now?</h2>';
print $html '<p>If you\'d like to review your results in greater detail, navigate to the <a href="#" onclick="changeTab(2);">Details</a> tab for a complete breakdown of the diffs between your code and the reference .out files in the testing directory.</p>';
print $html '<p>For more information on how to get the most from this HTML breakdown of your code, navigate to the <a href="#" onclick="changeTab(3);">Help</a> tab at the top or hit the Read More button below.</p>';
print $html '<p><a href="#" class="link-style" onclick="changeTab(3);">Read More</a></p>';
print $html '</div>';
print $html '</div>';
print $html '</div>';
print $html '<div id="welcome" class="tab2">';
print $html '<div class="content">';
print $html '<div id="expand_all"><a href="#" onclick="expandAll(' . scalar(@rc_files) . ');">Expand All</a>&nbsp;|&nbsp;<a href="#" onclick="collapseAll(' . scalar(@rc_files) . ');">Collapse All</a></div>';
print $html '<h2>Detailed Results</h2>';
print $html '<ul class="list-style2">';

# Iterate over each test now.
for my $i (0 .. $#rc_files) {
  # Did the test pass?
  if ($results[$i] == 1) {
    print $html '<li id="detailed_results_row">' . ($i + 1) . '. <u><strong>' . $rc_files[$i] . '</strong></u> <font style="color: #BBBBBB;">[' . (sprintf "%.4f", $compile_times[$i]) . ' seconds]</font><div id="passed_text">Passed</div></li>';
  } else {
    print $html '<li class="failed" id="detailed_results_row">';
    print $html '<div id="detailed_results_row_text" onclick="toggleRow(' . ($i + 1) . ');">' . ($i + 1) . '. <u><strong>' . $rc_files[$i] . '</strong></u> <font style="color: #BBBBBB;">[' . (sprintf "%.4f", $compile_times[$i]) . ' seconds]</font><div id="failed_text">Failed</div></div>';
    print $html '<div class="diff_output" id="test' . ($i + 1) . 'deets">';

    print $html '<table id="diff_table" cellpadding="2" cellspacing="0">';
    print $html '<tr id="diff_table_header"><td id="diff_left_header">' . $rc_files[$i] . ':</td></tr>';
    print $html '<tr>';
    # Read in the file and split the string by newline characters.
    open FILE, ($testing_directory."/".$rc_files[$i]) or die "Couldn't open file: $!"; 
    my $rc_file_src = join("", <FILE>); 
    close FILE;
    my @rc_file_lines = split(/\n/, $rc_file_src);
    print $html "<td style=\"font-family: Courier, \'Courier New\', monospace; font-size: 12px;\">";

    print $html "<table id=\"src_table\" cellpadding='2' cellspacing='0'>";
    for my $k (0 .. $#rc_file_lines) {
      if ($k % 2) {
        print $html "<tr id=\"even_src_row\">";
      } else {
        print $html "<tr id=\"odd_src_row\">";
      }

      $rc_file_lines[$k] =~ s{\t}{&nbsp;&nbsp;&nbsp;&nbsp;}g;
      $rc_file_lines[$k] =~ s{ }{&nbsp;}g;
      print $html "<td id=\"line_col\">" . ($k + 1) . ".</td>";
      print $html "<td id=\"src_col\">" . $rc_file_lines[$k] . "</td>";
      print $html "</tr>";
    }
    print $html "</table>";

    print $html "</td>";
    print $html '</table><br /><br />';

    print $html '<table id="diff_table" cellpadding="2" cellspacing="0">';
    print $html '<tr id="diff_table_header"><td id="diff_left_header">Diff Result:</td></tr>';
    print $html '<tr>';
    # Make sure all the newline haracters are turned into <br />'s.
    $diff_outputs[$i] =~ s{\n}{<br />}g;
    print $html "<td style=\"font-family: Courier, \'Courier New\', monospace;\">" . $diff_outputs[$i] . "</td>";
    print $html '</table>';
    print $html '</div>';
    print $html '</li>';
  }
}

print $html '</ul>';
print $html '</div>';
print $html '</div>';
print $html '<div id="welcome" class="tab3">';
print $html '<div class="content">';
print $html '<h2>Help</h2>';
print $html '<p>asdlkfj asldkjf alksdj flakjsd flkajs dlkfj asldkj flaksjd lfkja slkdjf laj sdlf jals djlkfj alskdj flkaj sdlkfj alksdj flkaj sldkfj alksj dflkaj sdlkfj alksjd flkaj sdlkfj alsjdflkaj sdlkfj alksdj flkaj sdlkfj alskdj flkajs dlfkj aslkdj flaksj dlfj asldjf laksj dflja sldfkj al;skjd f;ajksdf;lkaj sd;lfjk asldkjflksjdfl;kjsldkfjlsdkjflsjdjfkdjfkdjlfksjdkfj lkaj sdlkfj kj sdlfkj sldkjf lajks dlkjf aljskdj ljalksdjlkjlkj ljkl jlkjlkjlkjkljsdkfjaskdfasd jfkjalsdjfjksjaldjfoiweojkcmsklxlasdjlkajlksdjlfkjalskdjflaksmcxz,nvkjashdklfjalskjf   alskdj flasjd flajksd lfajs dlfkjajksjd flkj kjlskdj flkja sldkfj lasdjf</p>';
print $html '<p>asdlkfj asldkjf alksdj flakjsd flkajs dlkfj asldkj flaksjd lfkja slkdjf laj sdlf jals djlkfj alskdj flkaj sdlkfj alksdj flkaj sldkfj alksj dflkaj sdlkfj alksjd flkaj sdlkfj alsjdflkaj sdlkfj alksdj flkaj sdlkfj alskdj flkajs dlfkj aslkdj flaksj dlfj asldjf laksj dflja sldfkj al;skjd f;ajksdf;lkaj sd;lfjk asldkjflksjdfl;kjsldkfjlsdkjflsjdjfkdjfkdjlfksjdkfj lkaj sdlkfj kj sdlfkj sldkjf lajks dlkjf aljskdj ljalksdjlkjlkj ljkl jlkjlkjlkjkljsdkfjaskdfasd jfkjalsdjfjksjaldjfoiweojkcmsklxlasdjlkajlksdjlfkjalskdjflaksmcxz,nvkjashdklfjalskjf   alskdj flasjd flajksd lfajs dlfkjajksjd flkj kjlskdj flkja sldkfj lasdjf</p>';
print $html '<p>asdlkfj asldkjf alksdj flakjsd flkajs dlkfj asldkj flaksjd lfkja slkdjf laj sdlf jals djlkfj alskdj flkaj sdlkfj alksdj flkaj sldkfj alksj dflkaj sdlkfj alksjd flkaj sdlkfj alsjdflkaj sdlkfj alksdj flkaj sdlkfj alskdj flkajs dlfkj aslkdj flaksj dlfj asldjf laksj dflja sldfkj al;skjd f;ajksdf;lkaj sd;lfjk asldkjflksjdfl;kjsldkfjlsdkjflsjdjfkdjfkdjlfksjdkfj lkaj sdlkfj kj sdlfkj sldkjf lajks dlkjf aljskdj ljalksdjlkjlkj ljkl jlkjlkjlkjkljsdkfjaskdfasd jfkjalsdjfjksjaldjfoiweojkcmsklxlasdjlkajlksdjlfkjalskdjflaksmcxz,nvkjashdklfjalskjf   alskdj flasjd flajksd lfajs dlfkjajksjd flkj kjlskdj flkja sldkfj lasdjf</p>';
print $html '</div>';
print $html '</div>';
#print $html '<div id="footer">';
#print $html '<p>Created by <a href="mailto:bfiola@ucsd.edu">Ben Fiola</a> and <a href="mailto:tsgray@ucsd.edu">Thomas Gray</a>, Winter Quarter 2013</p>';
#print $html '</div>';
print $html '</div>';
print $html '</body>';
print $html '</html>';
close $html;
# =============================================================================================
# =============================== END GENERATION OF HTML FILE =================================
# =============================================================================================

# Print out a compilation summary.
print "\n ===================================\n";
print "   Compilation Summary:\n";
my $total_tests = $total_passed + $total_failed;
print "     Total tests:  " . $total_tests . "\n";
print "     Total passed: $total_passed\n";
print "     Total failed: $total_failed\n";

if ($total_passed == $total_tests) {
  print color "green";
  print "\n   SUCCESSFULLY PASSED ALL TESTS.\n";
  print color "reset";
}
print " ===================================\n";

# Clean up all temporary files we've created.
`rm -f $testing_directory/*.tmp`;
`rm -f $testing_directory/*.tmp1`;
`rm -f $testing_directory/*.tmp2`;
exit 0;


# handle command line arguments
sub DoCommandLineArguments{
  my $pass;
  my $help;

  GetOptions(
    'force|f' => \$force,
    'skip|s=s' => \@skip,
    'only|o=s' => \@only,
    'help|h' => \$help,
    'win|w' => \$pass,
    'dir|d=s' => \$dir,
    'result|r=s' => \$resultFile,
    'project|p=s' => \$project,
  );
  while ($project != 1 && $project != 2 && !$dir) {
    print "Didn't specify a project, which project suite would you like to run? (1) or (2) ";
    $project = <>;
    if ($project != 1 && $project != 2){
      print color "red";
      print "PICK 1 OR 2!(Better yet use the p flag)\n";
      print color "reset";
    }
  }
  chomp($project);
  $testing_directory = "project$project/$testing_directory";

  # usage message
  if ($help) {
    print "Usage: perlTest [so] range [d] directory [fp] 
  Note: I don't handle command line options well. 
  -p --project specifies the project you are testing. This dictates if the tool will 
               look in $p1_directory for tests or $p2_directory. 
               EX:  ./runTests -p 1   <- runs tests in $p1_directory/$testing_directory
                    ./runTests -p 2   <- runs tests in $p2_directory/$testing_directory
                    ./runTests -p 3   <- Display an angry message and prompt

               It also will  dictate if the tool will be comparing the compiler 
               output (p1) or actually running the program and program output(p2). 
               The command it uses to compile and run the program are:
               ./$RC_sh testfile
               make compile
               ./a.out

  -o --only    only run tests that have the passed in prefix. A range 
               is also accepted. See -s for range examples

  -s --skip    skip files that have the passed in prefix. A range is also 
               accepted. You can also split up arguments with a comma. 
               EX:  ./runTests -s p08  <- skips any file that starts with 
                                                p08
                    ./runTests -s p08-p10  <- skips any file that starts 
                                                 with p08, p09, p10
                    ./runTests -s p08-10,p12-13  <- skips any file that 
                                                          starts with p08, p09,
                                                          p10, p12, p13
                    ./runTests -s p08-10 -s p12-13  <- skips any file that 
                                                             starts with p08 p09
                                                             p10 p12 p13
  -d --dir     Run tests from a different directory other than the default
               $testing_directory
               EX: ./runTests -d testDir  <- runs only files in testDir
                   ./runTests -d testDir -s p08  <- runs only files in 
                                                          testDir and skips p08
                   ./runTests -d testDir -o p08 <- runs only p08 tests in 
                                                         testDir

  -f --force   force output files to be generated with the reference compilers

  -r --result  Specify a result file other than result.html 
               EX: ./runTests -r otherresult

  -w --win     automatically pass compilers

  Tests Files:
  All test files should be named with a leading identifier, followed by two more identifiers
  in order for the command line arguments to work properly. For example: p12, 112, 212 
  are all valid arguments. The first identifier is usually the phase letter or number, 
  and the next 2 identifiers are the check number in the project.

  Doc(ish): YYUNOC test tool. The idiot proof test tool for cse 131.
  Running without any arguments is the simplest way to use the tool. It will look for 
  a folder $testing_directory for any .rc files and .rc.out files and run $RC_sh 
  against the .rc files and compare the output to the .rc.out file. If no .rc.out 
  files it will run the reference compiler $ref_rc against the .rc file and save 
  that output as a .rc.out. There are options for specifying specific tests as well.\n";
    exit;
  
  }
  if ($dir) {
    print color "blue";
    print " Running tests in $dir instead\n"; 
    print color "reset";
    $testing_directory = $dir;
  }

  if ($pass) {
    my $url = "http://youtu.be/V4UfAL9f74I?t=7s";
    my $platform = $^O;
    my $cmd;
    if    ($platform eq 'darwin')  { $cmd = "open \"$url\"";          } # Mac OS X
    elsif ($platform eq 'linux')   { $cmd = "x-www-browser \"$url\""; } # Linux
    elsif ($platform eq 'MSWin32') { $cmd = "start $url";             } # Win95..Win7
    if (defined $cmd) {
      system($cmd);
      exit;
    } else {
      print color "red";
      print "You are probably ssh'd into ieng9, pass flag won't work :(\n";
      print color "reset";
      exit;
    }
  }

  my @argList;
  if (@skip) {
    @argList = @skip;
  }
  if (@only) {
    @argList = @only;
    if (@skip) {
      print color "red";
      print "You think your fucking funny don't you? What the fuck am I supposed to do with the skip and only flag high?\n";
      print color "reset";
      exit;
    }
  }

  # this is a demonstration of my terrible string manipulation
  foreach my $arg (@argList){
    # did they pass multiple arguments or just split with comma
    my @ranges = split(/,/, $arg);
    foreach(@ranges){
      my $letter = substr($_, 0, 1);
      my $numRanges = substr($_, 1);
      my @numRanges = split(/-/, $numRanges);
      my @testRange;
      if (scalar @numRanges == 1){
        # push(@rangePrefixes, $numRanges[1]);
        @testRange = ($numRanges[0]);
      }else{
        @testRange = ($numRanges[0] .. $numRanges[1]);
      }
      foreach my $numRange (@testRange){
        # print $numRange . " " ;
        $rangePrefixes{$letter . $numRange} = 1;
      }
    }
  }
}

sub CheckSkip{
  # checks if the file name passed in is skipable or not by checking the only
  # and skip flag and the rangePrefixes
  my ($file) = @_;
  my $prefix = substr($file, 0, 3);
  if (@skip && $rangePrefixes{$prefix}) {
    return 1;
  }
  if (@only && !$rangePrefixes{$prefix}) {
    return 1;
  } 
  return 0;
}
