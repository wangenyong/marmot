#!/bin/bash
# 查找xml文件中指定tag的起始和结束标志
# 执行成功 tag_begin 保存起始标志行号,tag_end 保存结束标志行号
# $1 xml file
# $2 tag name
# 正常执行返回0,
# $1 不存在,$2为空返回255
# 有多个相同节点,没找到节点则失败返回255
function find_xml_tags() {
    find_xml_tag_begin=
    find_xml_tag_end=
    if [ -f "$1" ] && [ -n "$2" ]; then
        # 将.分割的节点名转为数组
        local array=(${2//./ })
        local size=${#array[@]}
        #echo size=$size
        if [ $size -ge 1 ]; then
            local tag=${array[0]}
            [ -z "$tag" ] && return 255
            # 查找第一个节点
            tag_begin=$(sed -n -r "/<\s*$tag/=" "$1") &&
                tag_end=$(sed -n -r "/<\/\s*$tag\s*>/=" "$1")
            local ab=($tag_begin)
            local ae=($tag_end)
            # 找到标记数量不是1则失败返回
            if [ ${#ab[@]} -ne 1 ] || [ ${#ae[@]} -ne 1 ]; then return 255; fi
            #echo $tag tag_begin=$tag_begin tag_end=$tag_end
            # 根据第一个顶级节点给定的行号范围循环查找所有其他子节点
            # 以后的每次循环都在上次找到的行号范围内查找,会一步步缩小范围
            for ((i = 1; i < $size; i++)); do
                tag=${array[i]}
                [ -z "$tag" ] && return 255
                # 在$tag_begin,tag_end给定范围的值内查找
                local b=$(sed -n "$tag_begin,${tag_end}p" "$1" | sed -n -r "/<\s*$tag/=")
                local e=$(sed -n "$tag_begin,${tag_end}p" "$1" | sed -n -r "/<\/\s*$tag\s*>/=")
                local ab=($b)
                local ae=($e)
                # 找到标记数量不是1则失败返回
                if [ ${#ab[@]} -ne 1 ] || [ ${#ae[@]} -ne 1 ]; then return 255; fi
                #echo b=$b e=$e
                # b,e都是相对位置,在这里要转换为整文件的行号
                let "tag_end=$tag_begin+$e-1"
                let "tag_begin=$tag_begin+$b-1"
                #echo $tag  tag_begin=$tag_begin tag_end=$tag_end
            done
            return 0
        fi
    fi
    return 255
}
# 设置xml文件中指定property的值
# $1 xml file
# $2 .分割的节点的字符串,如 database.jdbc
# $3 value
# 正常执行返回0
# $1 不存在,$2为空返回255
# 有多个相同节点,没找到节点则失败返回255
# sed 修改文件失败返回sed错误代码
function set_xml_value() {
    find_xml_tags "$1" "$2" || exit
    local last=${2##*.}
    sed -i -r "$tag_begin,${tag_end}s!(<\s*$last.*>).*(</\s*$last\s*>)!\1$3\2!1" "$1" || exit
}
