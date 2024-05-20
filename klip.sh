#!/bin/sh
# AUTHOR: Jan Wiśniewki
# LICENSED: 何んでもいい
# COMMENTARY:
#
# This extracts the clippings data from kindle and creates anki cards
#
# EXAMPLE:
# Here is how kindle clipping record looks like:
# ==========
# また、同じ夢を見ていた (住野よる)
# - Your Highlight on page 3 | Location 14-14 | Added on Sunday, March 17, 2024 8:11:45 PM
#
# 向き合って
# CODE:

if [ "$1" = -h ]; then
    cat 1>&2 <<-EOF
    Skrypt extractuje zaznaczony tekst z ebooka (ktory znajduje sie w pliku "My Clippings")
    a nastepenie przetwarza go do odpowiedniego formatu i kopiuje do schowka.
    Nastepnym krokiem jest otworzenie przez uzytkownika texthookera oraz wlaczenie clipboard insertera
    (rozszerzenie chrome) który kopiuje zawartość schowka do strony i pozwala użyc rozszerzenia Yomitan
do podglodu 漢字/kanji (chińskie znaczki). Yomitan posiada funkcjonalność tworzenia "flashcardow"
   korzystajac z programu "Anki".
   Ten skomplikowanych process umożli mi szybkie uczenie sie nowych chińśkich znaczkow.
   Yomitan: https://github.com/themoeway/yomitan
   Clipboard inserter: https://github.com/themoeway/yomitan
   Texthooker: https://anacreondjt.gitlab.io/texthooker.html
   Anki: https://apps.ankiweb.net/
EOF
    exit
fi

if [ "$1" = -v ]; then
    echo "version: 0.1" 1>&2;
    exit
fi

# extract clippings from WSL
input="My Clippings.txt"
disk=$(zenity --title "Kindle Disk" --text "Enter disk letter" --entry) || exit
if ! mkdir -p "/mnt/$disk" ; then
    zenity --error --text "Can't create mounting point for kindle"
    exit 1
fi
# mount device to WSL
sudo -S -s <<EOF
sudo -S umount "/mnt/$disk" &>/dev/null
sudo -S mount -t drvfs "$disk": "/mnt/$disk"
EOF
if ! cp "/mnt/$disk/documents/My Clippings.txt" "./$input"; then
    zenity --error --text "Can't extract clippings from kindle"
    exit 1
fi

if ! [ -f "$input" ]; then
    echo "file '$input' doesn't exist"
    exit 1
fi
dos2unix -q "$input"

# this appends new record and works around $() striping newlines
# the record schema uses \t as separator for each field and \n as new fields
# I don't use array because POSIX don't define them.
mkrecord() {
    records=$(printf "%s%s\t%s\t%s\t%s\t%s\nx" "$records" "$@")
    records=${records%x}	# strip x which circumvents newline striping
}

parse() { # parse clippings into $records
    records=""
    # read each line into separate variable (for each record)
    # and put complete data into $records
    while read -r title; read -r loc; read -r _; read -r note; read -r sep; do
	if test "$sep" != "=========="; then
	    echo "unexpected record separator '$sep'" 1>&2
	    exit 1
	fi
	test -z "$note" && continue

	# shellcheck disable=SC2086
	set -- $loc		# set splits on spaces, often better to use than `cut'
	p=$6 l=$9
	shift 13
	date=$*
	mkrecord "$note" "$title" "$p" "$l" "$date"
    done <"$1"
    records=$(printf %s "$records")
}

# The rest of the code is using the IFS to set the field separator for read
# and then iterates in loop over each record (\n) and processing ironna na koto ()
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

sortbytitle() {
    records=""
    while IFS=$(printf "\t") read -r note title page loc date; do
	mkrecord "$title" "$note" "$page" "$loc" "$date"
    done <<-EOF
$1
EOF
    records=$(printf %s "$records" | sort -s)
}

show() {			# sexp format
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
zenity --info --title "Extraction complete" --text "Prepare texthooker and clipboard inserter"
# the texthooker im using can't handle new lines so I print it with delay
# but it doesn't matter because it takes time to create the flashcards anyway
while read -r line; do
    echo "$line" | xclip -sel clip
    sleep 1
done<<EOF
$records
EOF
echo "おまたせて！";
