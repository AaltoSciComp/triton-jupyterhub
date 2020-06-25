#!/bin/bash -l

WRKDIR=/scratch/work/$USER
# Create Jupyter home tree
JHOME=$HOME/.jupyterhub-tree
mkdir -p $JHOME
chmod u+w $JHOME
# Add some useful links
test -e $JHOME/home       || ln -sT $HOME    $JHOME/home
test -e $JHOME/work       || ln -sT $WRKDIR  $JHOME/work
test -e $JHOME/scratch    || ln -sT /scratch $JHOME/scratch
test -e $JHOME/m          || ln -sT /m       $JHOME/m
test -e $JHOME/filesystem || ln -sT /        $JHOME/filesystem
# Make this directory non-modifiable
chmod u-w,g-w,o-w $JHOME
# Clean up old spawner logfiles
find ~/ -maxdepth 1 -regextype egrep -regex '.*jupyterhub_slurmspawner_[0-9]+.log' -mtime '+7' -delete
