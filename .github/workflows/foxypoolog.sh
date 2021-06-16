#!/usr/bin/env bash

if [ -d "$HOME/.farmr" ] 
then
    /usr/bin/env farmr foxypoolog package;
else
    ./farmr foxypoolog;
fi
