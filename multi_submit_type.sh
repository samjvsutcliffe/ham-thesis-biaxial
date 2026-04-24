#!/bin/bash
#export OMP_PROC_BIND=spread,close
#export BLIS_NUM_THREADS=1
export REFINE=1
read -p "Do you want to clear previous data? (y/n)" yn
case $yn in
    [yY] ) echo "Removing data";rm -r /nobackup/rmvn14/thesis/biaxial/data; break;;
    qnN] ) break;;
esac
set -e
module load aocc/5.0.0
module load aocl/5.0.0
sbcl --dynamic-space-size 16000 --load "build.lisp" --quit

for m in MC DP RANKINE SE
do
    for r in 1 4
    do
        export REFINE=$r
        export MODEL=$m
        export ANGLE=30
        export TENSION=FALSE
        sbatch batch_bi.sh
    done
done
#for a in 15 30 45 60
#do
#    for r in 1 2 4
#    do
#        export REFINE=$r
#        export MODEL=MC
#        export ANGLE=$a
#        sbatch batch_bi.sh
#    done
#done

#export MODEL=DP
#
#export ANGLE=15
#sbatch batch_bi.sh
#export ANGLE=30
#sbatch batch_bi.sh
#export ANGLE=45
#sbatch batch_bi.sh
#export ANGLE=60
#sbatch batch_bi.sh
