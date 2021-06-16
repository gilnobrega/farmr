#!/usr/bin/env bash

if [ -d "$HOME/.farmr" ] 
then
    /usr/bin/env farmr package;
else
    ./farmr;
fi
