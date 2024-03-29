#!/bin/bash

here="/home/charlotte/.config/nvim/lua/custom"
there="/home/charlotte/.config/nvim-custom"

cd $there
git pull

cd $here
cd ..
rm -rf custom/

cp -r $there $here
cd custom/
rm -rf .git
