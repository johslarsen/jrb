#!/usr/bin/gawk -f
BEGIN {
    in_prolog = 1
}

/^[0-9]+ runs, [0-9]+ assertions/ { test="" } # i.e. run summary after non-passed summaries
/^  [0-9]+\) / { # non-passed summaries in the end
    l = $0
    getline
    test = gensub(/:$/, "", "g", $1)
    body[test] = body[test] "\n" l "\n"
}

test { body[test] = body[test] "\n" $0 }
match($0, /^([A-Za-z0-9_#]+) = (.*)/, header) { # E.g. "TestClass#test_method = "
    in_prolog = 0
    test = header[1]
    order[tests++] = test
    body[test] = header[2]
}
match($0, /([0-9.]+) s = (.)$/, footer) { # E.g. "0.12s = ."
    duration[test] = footer[1]
    status[test] = footer[2]
    body[test] = substr(body[test], 0, length(body[test]) - length(footer[0]) - 1)
    test=""
    next
}

in_prolog { prolog=prolog $0 "\n" }
!in_prolog && !test { epilog=epilog $0 "\n" }

END {
    print "<html><body>"
    print ""
    print "<details close>"
    print "<summary><a href='#prolog'>Prolog</a></summary>"
    print "<pre id='prolog'>" prolog "</pre>"
    print "</details>"
    print ""
    for (i in order) {
        test = order[i]
        if (status[test] == ".") color = "green"
        else if (status[test] == "F") color = "red"
        else if (status[test] == "E") color = "brown"
        else if (status[test] == "S") color = "grey"

        print ""
        print "<details " (body[test] ? "close id='"test"'" : "open") ">"
        print "<summary style='color: "color"'>"status[test], "<a style='color: "color"' href='#"test"'>"test"</a>", "("duration[test]"s)</summary>"
        if (body[test]) {
            print "<pre id='"test"'>" body[test] "</pre>"
        }
        print "</details>"
    }
    print ""
    print "<details close>"
    print "<summary><a href='#epilog'>Epilog</a></summary>"
    print "<pre id='epilog'>" epilog "</pre>"
    print "</details>"
    print "</body></html>"
}
