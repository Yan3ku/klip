#!/bin/sh
# this is scrapper written in pure POSIX shell because I'm linux purist who
# doesn't touch grass

# it extracts the clippings data from kindle and creates anki cards (in progress)

# also the challenge is to not use awk
# but idk maybe i will

# Here is how kindle clipping record looks like:
# ==========
# また、同じ夢を見ていた (住野よる)
# - Your Highlight on page 3 | Location 14-14 | Added on Sunday, March 17, 2024 8:11:45 PM
#
# 向き合って

input="${1:-My Clippings.txt}"
if ! [ -f "$input" ]; then
    echo "file '$1' doesn't exist"
    exit 1
fi
dos2unix -q "$input"

mkrecord() {
    # work around $() striping newlines
    records=$(printf "%s%s\t%s\t%s\t%s\t%s\nx" "$records" "$@")
    records=${records%x}
}

parse() { # parse clippings into $records
    records=""
    while read -r title; read -r loc; read -r _; read -r note; read -r sep; do
	if test "$sep" != "=========="; then
	    echo "unexpected record separator '$sep'" 1>&2
	    exit 1
	fi
	test -z "$note" && continue

	# shellcheck disable=SC2086
	set -- $loc
	p=$6 l=$9
	shift 13
	date=$*
	mkrecord "$note" "$title" "$p" "$l" "$date"
    done <"$1"
    records=$(printf %s "$records")
}

rmdups() { # remove duplicates
    records=""
    lastnote=""
    while IFS=$(printf "\t") read -r note title page loc date; do
	[ "$note" = "$lastnote" ] && continue
	mkrecord "$note" "$title" "$page" "$loc" "$date"
	lastnote="$note"
    done <<-EOF
$(printf %s "$1" | sort)
EOF
    records=$(printf %s "$records")
}

sortbytitle()
{
    records=""
    while IFS=$(printf "\t") read -r note title page loc date; do
	mkrecord "$title" "$note" "$page" "$loc" "$date"
    done <<-EOF
$1
EOF
    records=$(printf %s "$records" | sort -s)
}

show() {
    while IFS=$(printf "\t") read -r title note page loc date; do
	test "$lasttitle" != "$title" && {
	    test -n "$lasttitle" && printf ")\n"
	    printf "(TITLE: %s" "$title"
	}
	printf "\n\t(:NOTE: %s\n\t\t:PAGE %s :LOC %s :DATE %s)" "$note" "$page" "$loc" "$date"
	lasttitle="$title"
    done<<-EOF
$1
EOF
    printf "\n"
}

parse "$input"
rmdups "$records"
sortbytitle "$records"
show "$records" | xclip -sel clip
