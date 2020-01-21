#!/usr/bin/env bash

if [ "$#" -ne 3 ]; then     # number of args
    echo "USAGE: script.sh lang date outdir"
    echo "$ME"
    exit
fi

lang=$1
date=$2
OUTDIR=$3
rm ${OUTDIR}/${lang}wiki-${date}-pages-articles.xml.bz2
rm ${OUTDIR}/${lang}wiki-${date}-page.sql.gz
rm ${OUTDIR}/${lang}wiki-${date}-pagelinks.sql.gz
rm ${OUTDIR}/${lang}wiki-${date}-redirect.sql.gz
rm ${OUTDIR}/${lang}wiki-${date}-categorylinks.sql.gz
rm ${OUTDIR}/${lang}wiki-${date}-langlinks.sql.gz
