#!/bin/bash
for i in $(ls -d */)
do
    if [ -d "$i".git ]
    then
	REPOURL=`cat $i.git/config | grep url | tr -d " " | tr -d "\t" | sed 's/url=//'`
	echo git submodule add "$REPOURL" "SDKs/$i"
        #git submodule add $i $i
    fi
done
