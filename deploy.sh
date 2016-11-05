#!/bin/sh
SITEDIR=../homepage-sources
ODIR=$SITEDIR/src/js-revca

set -e

echo ===========================
echo ==  Publishing JS-revca  ==
echo ===========================


cp -r *.svg images *.html scripts-src *.css LICENSE README.md $ODIR
cp -r scripts/revca_singlerot.js scripts/minified.js $ODIR/scripts


echo =============================================
echo ==  Done building, now publishing on site  ==
echo =============================================

cd $SITEDIR
sh ./publish.sh
