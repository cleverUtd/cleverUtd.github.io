#!/bin/sh

echo "hexo clean..."
hexo clean 
echo "hexo clean done."

echo "hexo generate..."
hexo g
echo "hexo generate done."

echo "hexo deploy..."
hexo d
echo "hexo deploy done."


ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

echo ${ROOT}
rsync -avzh --delete ${ROOT}/public/* zclau@106.186.31.57:/home/zclau/blog/  
