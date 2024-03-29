#!/bin/bash

here="/home/charlotte/.config/nvim/lua/custom"
there="/home/charlotte/.config/nvim-custom"

cd $there
rm -rf *
cp -r $here/* "$there"

cd $there
git add .
git commit -m "automated backup"
git push --force-with-lease
