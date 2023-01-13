#!/bin/bash

rsync ./ -avz --progress --exclude-from='.rsync_exclude' root@hadoop101:~/marmot/