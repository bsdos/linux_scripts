#!/bin/bash

# 这个脚本用于在 Linux 终端中开启或关闭代理，并可以将代理设置命令安装到 ~/.bashrc 文件中。
# 脚本名称: proxy_manager.sh
# 使用方法:
# source ./proxy_manager.sh on     - 开启代理
# source ./proxy_manager.sh off    - 关闭代理
# ./proxy_manager.sh -i            - 将代理设置命令安装到 ~/.bashrc 文件中，一旦安装，会将当前脚本路径记录在.bashrc。
#                                  - 如后续调整当前脚本位置，会造成运行失败。
#                                  - 安装后，可以直接使用命令proxy_on和proxy_off来开关代理
# ./proxy_manager.sh -h            - 显示使用说明

PROXY_URL="http://你的代理ip:port"

SCRIPT_PATH=$(realpath "$BASH_SOURCE")

function usage {
    echo "用法: $0 {on|off|-i|-h}"
    echo "source $0 on     - 开启代理"
    echo "source $0 off    - 关闭代理"
    echo "$0 -i            - 将代理设置命令安装到 ~/.bashrc"
    echo "$0 -h            - 显示此帮助信息"
    exit 1
}

function install_to_bashrc {
    echo "正在将代理命令安装到 ~/.bashrc..."
    grep -qxF "alias proxy_on='source $SCRIPT_PATH on'" ~/.bashrc || echo "alias proxy_on='source $SCRIPT_PATH on'" >> ~/.bashrc
    grep -qxF "alias proxy_off='source $SCRIPT_PATH off'" ~/.bashrc || echo "alias proxy_off='source $SCRIPT_PATH off'" >> ~/.bashrc
    echo "安装完成。"
    source ~/.bashrc
    echo "已执行 source ~/.bashrc 以应用更改。"
}

if [ "$#" -ne 1 ]; then
    usage
fi

case "$1" in
    on)
        export all_proxy="$PROXY_URL"
        echo "代理已开启。"
        ;;
    off)
        unset all_proxy
        echo "代理已关闭。"
        ;;
    -i)
        install_to_bashrc
        ;;
    -h)
        usage
        ;;
    *)
        usage
        ;;
esac
