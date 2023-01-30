#!/bin/bash

source ./log.sh

log_info "log info"

# 查找起始标志 <server 获取sed搜索范围的起始行号, = 用于打印行号
begin_line=$(sed -n '/<server/=' defaultConfig.xml)
# begin_line 为 6
# 查找结束标志</server>获取sed搜索范围的结束行号
end_line=$(sed -n '/<\/server>/=' defaultConfig.xml)
# end_line为 12
# 在line 6-12之间搜索招待正则表达式替换
sed -i -r "$begin_line,${end_line}s/(<start.*>).*(<\/start>)/\1false\2/1" defaultConfig.xml

ONTENT='    <student>\
    <name>NewName</name>\
    <id>NewID</id>\
</student>'

sed '/<\/Students>/i\'"$CONTENT" file
