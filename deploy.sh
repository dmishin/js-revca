#!/bin/sh

echo Deployment script
ODIR=../js-revca-deploy/js-revca

cp -r images *.html scripts scripts-src *.css LICENSE README.md $ODIR

cd $ODIR

git status
git add -A

git commit -m "Automatic commit"

git push
