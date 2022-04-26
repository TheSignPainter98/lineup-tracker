import stderr from io

statuses = {
	FAIL: 1
	EXIT: -1
	PASS: 0
}

import FAIL, PASS from statuses
problem = (msg, fatal=false) ->
	stderr\write msg .. '\n'
	fatal and FAIL or PASS

{ :statuses, :problem }
