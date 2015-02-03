# Y YUNO So Complicated!?
Do you want a very power testing framework? One that will show you your regression? Want a way automatically save test suites for latter?
How about a tool that allows for easy sharing of tests? 

If all those sound great, **your on the wrong fucking page**. You probably want [YUNO](https://github.com/bulatb/yuno). 

This is YYUNOSOC. A perl script for those to lazy to learn how YUNO works. It loops over a directory called
tests, runs anything that has a .rc extension and compares the output your compiler got with an rc.out file. It then makes
a pretty html page with the results. There are some arguments you can pass the script to make it not run the entire suite, see usage or type

    perl runTests.pl -h. 

However if you don't want to learn YUNO you probaly are lazy and won't scroll down to the usage section. Just run 

    perl runTests.pl
In you compiler directory with the test directory provided here and then you don't have to read anything else if you 
really don't want to, then open results.html.

If you are even more lazy, you don't have to run the perl script and look at an individual comparision with 

    chmod +x compare.sh
    ./compare.sh p00a.rc

and that will give you vimdiff of that individual test. To exit vimdiff hit [ESC] :qall. It's a very boring script but it helps with giving you a better look at the compaision when you are working on one specific test. 

## Example Structure.
Notice publicTest.pl needs to be in the same directory as RC and the test directory


    +CompilerCode
    +--src/
    +--lib/
    +--bin/
    +--tests/
    +--RC
    +--RCdbg
    +--build.xml
    +--runTests.pl

##Tests Directory
There are two files needed for testing. The first is the rc file, which is the actual source code to be tested 
against. The next is the rc.out file, which will be the expected output. The rc.out file will be auto generated with 
the reference compiler if it does not exist. 

###Test Names
The tests need to be named with one letter followed by 2 numbers to work with the command flags e.g. p00.rc(I 
did some very lazy string manipulation to get the flags in)


##Usage
The simplest way is to just run 
    
    perl publicTests.pl

This will run through your tests directory and run all the tests and output a html page with the results.
It also accepts a few command line arguments if you want to limit the tests you are running, test a certain directory 
or force creation of a new rc.out file.

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
