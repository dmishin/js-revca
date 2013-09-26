#!/bin/sh

set -e

echo Deployment script
ODIR=../js-revca-deploy/js-revca

cp -r images *.html scripts-src *.css LICENSE README.md $ODIR
cp -r scripts/minified.js $ODIR/scripts

cd $ODIR

git add -A
git status

git commit -m "Automatic commit"

git push
