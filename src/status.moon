import stderr from io

statuses = {
	WARN: 2
	FAIL: 1
	EXIT: -1
	PASS: 0
}

import FAIL, WARN from statuses
problem = (msg, fatal=false) ->
	stderr\write msg .. '\n'
	fatal and FAIL or WARN

is_bad = (c) -> c == WARN or c == FAIL

{ :is_bad, :statuses, :problem }
