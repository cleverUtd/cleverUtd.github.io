#!/bin/sh

ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

echo ${ROOT}
rsync -avzh --delete ${ROOT}/public/* zclau@106.186.31.57:/home/zclau/blog/  
