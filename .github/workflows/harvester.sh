#!/usr/bin/env bash

if [ -d "$HOME/.farmr" ] 
then
    /usr/bin/env farmr harvester package;
else
    ./farmr harvester;
fi
