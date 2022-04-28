#!/usr/bin/bash
#
# This file will allow automated checking of project 3. It requires that you create a git branch with
# the unmodified project 3 starter code (BASEBRANCH), a branch with your modified code (TESTBRANCH) 
# and a directory holding test programs (TESTCASES)
#

export BASEOUTDIR=base_outputs
export TESTOUTDIR=test_outputs
export TESTCASES=test_progs
export BASEBRANCH=base
export TESTBRANCH=master
export ASSEMBLY_EXT=s
export PROGRAM_EXT=c

# Colors for echoing
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No color

function run_tests {
    extension=$1
    output=$2
    type=$3
    echo "$0: Testing $type files"
    for tst in $TESTCASES/*.$extension; do
        testname=$tst
        testname=${testname##${TESTCASES}\/}
        testname=${testname%%.${extension}}
        echo "$0: Test: $testname"
        make clean simv > /dev/null
        make $type SOURCE=$tst > /dev/null
        ./simv > program.out
        # make clean > /dev/null
        grep "@@@" program.out > $2/$testname.program.out
        grep "CPI" program.out > $2/$testname.cpi.out
        mv writeback.out $2/$testname.writeback.out
    done
}

function generate_single_test {
    if [ -d $TESTOUTDIR ]; then
        echo "$0: Deleting old test outputs from $TESTOUTDIR"
        rm -rf $TESTOUTDIR
        mkdir $TESTOUTDIR
    else
        mkdir $TESTOUTDIR
    fi

    extension=$1
    type=$2
    tst=$3
    echo "$0: Testing $type files"
    testname=$tst
    testname=${testname##${TESTCASES}\/}
    testname=${testname%%.$extension}
    echo "$0: Test: $testname"
    make clean simv > /dev/null
    make $type SOURCE=$tst > /dev/null
    ./simv > program.out
    # make clean > /dev/null
    grep "@@@" program.out > $TESTOUTDIR/$testname.program.out
    grep "CPI" program.out > $TESTOUTDIR/$testname.cpi.out
    mv writeback.out $TESTOUTDIR/$testname.writeback.out
}

function generate_test_outputs {
    # create test outputs
    # git checkout $TESTBRANCH
    if [ -d $TESTOUTDIR ]; then
        echo "$0: Deleting old test outputs from $TESTOUTDIR"
        rm -rf $TESTOUTDIR
        mkdir $TESTOUTDIR
    else
        mkdir $TESTOUTDIR
    fi
    echo "$0: Building Test simv on branch [$TESTBRANCH]"
    make clean simv > /dev/null
    echo "$0: Done."
    
    if [[ $1 == "assembly" ]]; then
        run_tests ${ASSEMBLY_EXT} ${TESTOUTDIR} assembly
    elif [[ $1 == "program" ]]; then
        run_tests ${PROGRAM_EXT} ${TESTOUTDIR}  program
    else
        run_tests ${ASSEMBLY_EXT} ${TESTOUTDIR} assembly
        run_tests ${PROGRAM_EXT} ${TESTOUTDIR} program
    fi
}

function compare_results {
    printf "=============================================\n"
    printf "Compare RESULTS\n"
    printf "=============================================\n"
    # compare results
    p_pass_count=$((0))
    p_fail_count=$((0))
    p_total=$((0))
    w_pass_count=$((0))
    w_fail_count=$((0))
    w_total=$((0))
    for tst in $TESTOUTDIR/*.writeback.out; do
        testname=$tst
        testname_bak=${testname%%.writeback.out}
        testname=${testname##${TESTOUTDIR}\/}
        testname=${testname%%.writeback.out}
        if [[ -f $testname_bak.program.out ]]; then
            diff $testname_bak.program.out $BASEOUTDIR/$testname.program.out > /dev/null
            status=$? # 0 -> no difference
            if [[ "$status" -eq "0" ]]; then
                echo -e "program.out:   Test $testname ${GREEN}PASSED${NC}"
                p_pass_count=$(($p_pass_count + 1))
            else
                echo -e "program.out:   Test $testname ${RED}FAILED${NC}"
                p_fail_count=$(($p_fail_count + 1))
            fi
        
            diff $tst $BASEOUTDIR/$testname.writeback.out > /dev/null
            status=$? # 0 -> no difference
            if [[ "$status" -eq "0" ]]; then
                echo -e "writeback.out: Test $testname ${GREEN}PASSED${NC}"
                w_pass_count=$(($w_pass_count + 1))
            else
                echo -e "writeback.out: Test $testname ${RED}FAILED${NC}"
                w_fail_count=$(($w_fail_count + 1))
            fi

            echo "BASE PERF `cat $BASEOUTDIR/$testname.cpi.out`"
            echo "TEST PERF `cat $TESTOUTDIR/$testname.cpi.out`"
            echo ""
            p_total=$(($p_total + 1))
            w_total=$(($w_total + 1))
        else
            echo "Test $testname generate failed"
            echo ""
        fi
    done

    echo ""
    echo "program.out:   PASSED $p_pass_count/$p_total tests ($p_fail_count failures)."
    echo "writeback.out: PASSED $w_pass_count/$w_total tests ($w_fail_count failures)."
}

changes=`git status --porcelain | grep -v "??"`

# if [ -n "$changes" ]; then
#     echo "Please commit/revert pending changes on current branch before running $0:"
#     echo $changes
#     exit
# fi

source ~/.bashrc
make clean > /dev/null

if [[ $1 == "program" || $1 == "assembly" || $1 == "all" ]]; then
    if [[ -z $2 ]]; then
        generate_test_outputs $1
    elif [[ $1 == "program" ]]; then
        generate_single_test ${PROGRAM_EXT} $1 $2
    elif [[ $1 == "assembly" ]]; then
        generate_single_test ${ASSEMBLY_EXT} $1 $2
    fi
fi

compare_results
