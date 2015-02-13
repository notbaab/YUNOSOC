# Y YUNO So Complicated!?
Do you want a very power testing framework? One that will show you your regression? Want a way automatically save test suites for latter?
How about a tool that allows for easy sharing of tests? 

If all those sound great, **your on the wrong fucking page**. You probably want [YUNO](https://github.com/bulatb/yuno). 

This is YYUNOSOC. A perl script for those to lazy to learn how YUNO works. Depending on your project It loops over a directory called project1/tests or project2/tests runs anything that has a .rc extension and compares the output your compiler got with an rc.out file. It then makes a pretty html page with the results. There are some arguments you can pass the script to make it not run the entire suite, see usage or type

    perl runTests.pl -h. 

However if you don't want to learn YUNO you probaly are lazy and won't scroll down to the usage section. Just run 

    perl runTests.pl
    
in you compiler directory with the project1 and project2 directories. It will ask if you want to run project 1 tests or 2, type in a number. Then you don't have to read anything else if you really don't want to, then open results.html.

#Things you should know even if you are lazy
For project1, it will only run 

    ./RC testfile.rc
and compare the error outputs to the rc.out file. That should be straightforward and hard to mess up. For project2, it will run the following.  

    ./RC testfile.rc
    make compile
    ./a.out
And compare **only** the executable output. It does not care if ./RC compiles successfully(which it should, we are testing only semantically correct code), and will try to run make compile and execute your program. This will cause it to run the last sucessfully compiled program, even if it's not the current test case. Try to avoid that but if this does happen, the tool will keep running, but the result in results.html isn't valid for that specific test. The rest of the tests should be valid.

**Do not write infinite loop code.** It makes the tool cry. Check and make sure your executable doesn't produce an infinite loop. The good news is it will be very obvious which test has one as there will be a half gig large .tmp file.

## Example Structure.
Notice publicTest.pl needs to be in the same directory as RC and the test directory


    +CompilerCode
    +--src/
    +--lib/
    +--bin/
    +--project1/
    +--project2/
    +--RC
    +--RCdbg
    +--build.xml
    +--runTests.pl

##Tests Directory
There are two or three files needed for testing. The first is the rc file, which is the actual source code to be tested 
against. The next is the rc.out file, which will be the expected output. The rc.out file will be auto generated with 
the reference compiler if it does not exist. For tests that test cin in project 2, you will also need a rc.input file to specify the input.

###Test Names
The tests need to be named with one identifier followed by 2 numbers to work with the command flags e.g. p00.rc, 200.rc(I 
did some very lazy string manipulation to get the flags in)


##Usage
The simplest way is to just run 
    
    perl publicTests.pl

This will run through your tests directory and run all the tests and output a html page with the results.
It also accepts a few command line arguments if you want to limit the tests you are running, test a certain directory 
or force creation of a new rc.out file.

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
               
    -o --only   only run tests that have the passed in prefix. A range 
                is also accepted. See -s for range examples

    -s --skip   skip files that have the passed in prefix. A range is also 
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
    -d --dir    Run tests from a different directory other than the default
                $testing_directory
                EX: ./runTests -d testDir  <- runs only files in testDir
                    ./runTests -d testDir -s p08  <- runs only files in 
                                                           testDir and skips p08
                    ./runTests -d testDir -o p08 <- runs only p08 tests in 
                                                          testDir

    -f --force  force output files to be generated with the reference compilers

    -p --pass   automatically pass compilers

    -r --result Specify a result file other than result.html. Appends html automatically
                EX: ./runTests -r otherresult

After the test is run it will give you a nice diff output in html called results.html

##Origins
The script was seems to originally be made by someone named Ben Fiola and Thomas Gray in the 2013 Winter Quarter. It was modified extensively by me in order to work with our project specification, use our reference compiler, and to allow command line arguments. The only thing untouched from the original script is the the html output. Thomas and Ben, you generate HTML beautifly and I thank you for making compiler test results easy to digest. 

##Complaints 
Any complaints please send a box of cookies and a blood sacrifice to 
699 8th Street, San Francisco, CA 94103
