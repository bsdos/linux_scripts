#!/bin/bash

# 调试标志
DEBUG=false

# 使用说明函数
usage() {
    echo "使用方法: $0 [-h] [-d]"
    echo ""
    echo "选项:"
    echo "  -h          显示此帮助信息并退出"
    echo "  -d          启用调试模式"
    echo ""
    echo "此脚本提供了一个菜单驱动的界面，用于运行各种脚本。"
    echo "菜单项和脚本在名为'script_list.json'的JSON文件中定义。"
    echo ""
    echo "主菜单:"
    echo "  1. 初始化脚本"
    echo "  2. 安装软件"
    echo "  0. 退出"
    echo ""
    echo "子菜单（例如'初始化脚本'）:"
    echo "  1. ssh互相信任"
    echo "  2. 修改ip地址"
    echo "  0. 上一级"
    echo ""
}

# 解析命令行选项
while getopts "hd" opt; do
    case ${opt} in
        h )
            usage
            exit 0
            ;;
        d )
            DEBUG=true
            ;;
        \? )
            usage
            exit 1
            ;;
    esac
done

# 打印调试信息的函数
debug() {
    if [ "$DEBUG" = true ]; then
        echo "调试: $1"
    fi
}

# 直接执行脚本的函数
execute_script() {
    local url=$1
    debug "执行脚本 $url"
    bash -c "$(curl -fsSL $url)"
}

# 解析JSON脚本列表并生成菜单的函数
parse_script_list() {
    local file=$1
    if [[ -f "$file" ]]; then
        menu_items=$(jq -c '.[]' "$file")
    else
        debug "$file 文件不存在，从网上下载..."
        menu_items=$(curl -fsSL "https://xxxx.aliyuncs.com/scripts/devops/script_list.json" | jq -c '.[]')
    fi
}

# 显示主菜单的函数
show_main_menu() {
    local choices=("0" "退出")
    local index=1
    for item in $menu_items; do
        displayname=$(echo "$item" | jq -r '.displayname')
        choices+=("$index" "$displayname")
        ((index++))
    done

    debug "主菜单选项: ${choices[@]}"

    CHOICE=$(dialog --clear --backtitle "菜单示例" \
            --title "主菜单" \
            --menu "请选择一个选项：" \
            15 50 8 \
            "${choices[@]}" \
            2>&1 >/dev/tty)

    debug "用户选择: $CHOICE"
    clear
    if [[ -n $CHOICE ]]; then
        if [[ "$CHOICE" == "0" ]]; then
            echo "退出..."
            exit 0
        fi
        index=1
        for item in $menu_items; do
            if [[ "$index" == "$CHOICE" ]]; then
                debug "匹配项: $item"
                show_sub_menu "$item"
                break
            fi
            ((index++))
        done
    else
        echo "退出..."
        exit 0
    fi
}

# 显示子菜单的函数
show_sub_menu() {
    local menu_item=$1
    local choices=("0" "上一级")
    local index=1
    sub_items=$(echo "$menu_item" | jq -c '.sub[]')

    for item in $sub_items; do
        displayname=$(echo "$item" | jq -r '.displayname')
        choices+=("$index" "$displayname")
        ((index++))
    done

    debug "子菜单选项: ${choices[@]}"

    if [ ${#choices[@]} -eq 2 ]; then
        dialog --msgbox "没有可用的选项。" 10 30
        return
    fi

    SUB_CHOICE=$(dialog --clear --backtitle "菜单示例" \
                --title "$(echo "$menu_item" | jq -r '.displayname')" \
                --menu "请选择一个脚本来运行：" \
                15 50 8 \
                "${choices[@]}" \
                2>&1 >/dev/tty)

    debug "用户在子菜单中选择: $SUB_CHOICE"
    clear
    if [[ -n $SUB_CHOICE ]]; then
        if [[ "$SUB_CHOICE" == "0" ]]; then
            show_main_menu
            return
        fi
        index=1
        for item in $sub_items; do
            if [[ "$index" == "$SUB_CHOICE" ]]; then
                url=$(echo "$item" | jq -r '.url')
                debug "执行子项: $item，URL: $url"
                execute_script "$url"
                show_main_menu
                break
            fi
            ((index++))
        done
    else
        show_main_menu
    fi
}

# 解析脚本列表
parse_script_list "script_list.json"

# 调试: 打印解析后的JSON项
debug "解析的菜单项:"
for item in $menu_items; do
    debug "$item"
done

# 显示主菜单
show_main_menu
