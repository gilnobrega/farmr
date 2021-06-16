#!/usr/bin/env bash

if [ -d "$HOME/.farmr" ] 
then
    /usr/bin/env farmr hpool package;
else
    ./farmr hpool;
fi
