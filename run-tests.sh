#!/usr/bin/env bash

test_success=0
test_errors=0

cd `dirname $0`
cd tests

TEST_FILTER='*.txt'

if [ ! -z "$1" ]
then
	TEST_FILTER=$1
fi

# We cannot use while read line here
# @see http://fvue.nl/wiki/Bash:_Piped_%60while-read'_loop_starts_subshell
# for further information
for file in `ls $TEST_FILTER`
do
	TEST_NAME=`echo "$file" | cut -f 1 -d '.'`
	if [ -f "$TEST_NAME.sh" ]
	then
		bash "$TEST_NAME.sh" $1 > "${TEST_NAME}.result"
		current_exit_code="${?}"
	elif [ -f "$TEST_NAME.lua" ]
	then
		docker run -it -v `pwd`/../src/parse-graphql.lua:/usr/share/lua/5.1/parse-graphql.lua -v `pwd`/../:/usr/src/app --workdir /usr/src/app --rm graphql-hateoas-bridge-nginx lua5.1 tests/$TEST_NAME.lua > "${TEST_NAME}.result"
		current_exit_code=0
	elif [ -f "$TEST_NAME.json" ]
	then

		curl -X POST -sS -H 'Content-Type: application/json' -d @"$TEST_NAME.json" "localhost:4778/${TEST_NAME}/" > "${TEST_NAME}.result"
		current_exit_code="${?}"
	elif [ -f "$TEST_NAME.graphql" ]
	then

		curl -X POST -sS -H 'Content-Type: application/graphql' -d @"$TEST_NAME.graphql" "localhost:4778/${TEST_NAME}/" > "${TEST_NAME}.result"
		current_exit_code="${?}"
	else
		curl -sS "localhost:4778/${TEST_NAME}/" > "${TEST_NAME}.result"
		current_exit_code="${?}"
	fi
	if [ "${current_exit_code}" -ne "0" ]
	then
		echo "  [  ] $TEST_NAME"
		echo "   -> broken! (curl did not 2xx, Exit code: $current_exit_code)"
		let test_errors=test_errors+1
	else
		diff "${TEST_NAME}.txt" "${TEST_NAME}.result"
		current_exit_code="${?}"
		if [ "${current_exit_code}" -ne "0" ]
		then
			echo "  [  ] $TEST_NAME"
			echo "   -> broken! (.txt != .result, Exit code: $current_exit_code)"
			let test_errors=test_errors+1
		else
			echo "  [OK] $TEST_NAME"
			let test_success=test_success+1
		fi
	fi
done

if [ ! $test_errors -eq 0 ]
then
	exit 1
fi

exit 0
