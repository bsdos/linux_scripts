#!/bin/bash

# 脚本名称：configure_ssh_access.sh
# 说明：
# 这个脚本用于在一台控制机（A 服务器）上配置多个服务器（B、C、D、E）的免密 SSH 访问。
# 脚本首先检查所有目标服务器是否在线，然后为每台服务器生成 SSH 密钥对（如果不存在），
# 将每台服务器的公钥添加到其他服务器的 authorized_keys 文件中，
# 并确保 known_hosts 文件中包含所有服务器的正确主机指纹，避免重复行。
#
# 脚本作用：
# - 检查目标服务器是否在线。
# - 为每台服务器生成 SSH 密钥对（如果不存在）。
# - 记录每台服务器的公钥。
# - 将所有公钥添加到每台服务器的 authorized_keys 文件中。
# - 获取每台服务器的主机指纹并添加到所有服务器的 known_hosts 文件中。
# - 确保控制机（A 服务器）的 known_hosts 文件没有重复行。
#
# 运行条件：
# - 控制机（A 服务器）和目标服务器（B、C、D、E）必须可以通过网络互相访问。
# - 控制机（A 服务器）上必须安装 sshpass 工具。如果未安装，脚本会自动安装。
#
# 运行前需要修改：
# - 修改 BASE_IP 和 IPS 数组，确保它们包含目标服务器的正确 IP 地址。
# - 修改 PASSWORD 变量，确保它包含目标服务器的正确 root 密码。
#
# 运行后的结果：
# - 目标服务器（B、C、D、E）之间将实现免密 SSH 访问。
# - 控制机（A 服务器）的 known_hosts 文件将包含所有目标服务器的正确主机指纹，并且没有重复行。

# 定义基础IP和root密码
BASE_IP="10.2.17."
IPS=(82 83 84 85 86)
PASSWORD="root密码"

# 服务器数组
SERVERS=("${IPS[@]/#/$BASE_IP}")

# 检查并安装sshpass
if ! command -v sshpass &> /dev/null; then
    echo "sshpass 未安装，正在安装..."
    yum install -y sshpass
else
    echo "sshpass 已安装"
fi

# 检查所有服务器是否在线
for SERVER in ${SERVERS[@]}; do
    echo "检查服务器 $SERVER 是否在线..."
    if ! ping -c 1 -W 1 $SERVER &> /dev/null; then
        echo "无法连接到 $SERVER，请检查网络连接。"
        exit 1
    else
        echo "$SERVER 在线"
    fi
done

# 生成SSH密钥对并记录公钥
declare -A PUB_KEYS

for SERVER in ${SERVERS[@]}; do
    echo "处理服务器 $SERVER..."

    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no root@$SERVER "
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa
    fi
    " 

    if [ $? -ne 0 ]; then
        echo "无法连接到 $SERVER"
        continue
    fi

    PUB_KEYS[$SERVER]=$(sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no root@$SERVER "cat ~/.ssh/id_rsa.pub")

    if [ $? -ne 0 ]; then
        echo "无法获取 $SERVER 的公钥"
        continue
    fi
done

# 将所有公钥添加到每台服务器的authorized_keys文件中
for SERVER in ${SERVERS[@]}; do
    echo "配置服务器 $SERVER..."

    for PUB_KEY in "${PUB_KEYS[@]}"; do
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no root@$SERVER "
        if ! grep -q '$PUB_KEY' ~/.ssh/authorized_keys; then
            echo '$PUB_KEY' >> ~/.ssh/authorized_keys
        else
            echo '公钥已经存在，跳过添加'
        fi
        "
        if [ $? -ne 0 ]; then
            echo "无法将公钥添加到 $SERVER"
            continue
        fi
    done
done

# 获取每台服务器的主机指纹并添加到每台服务器的已知主机文件中
for SERVER in ${SERVERS[@]}; do
    echo "获取和分发服务器 $SERVER 的主机指纹..."

    # 使用 ssh-keyscan 获取主机指纹，并将其保存到本地文件
    ssh-keyscan $SERVER > /tmp/ssh_known_hosts_$SERVER

    # 使用 awk 过滤出 ecdsa-sha2-nistp256 行，并将哈希替换为实际的 IP 地址
    awk -v server="$SERVER" '$2 == "ecdsa-sha2-nistp256" {sub(/\|1\|.*\|.*\|/, server " "); print}' /tmp/ssh_known_hosts_$SERVER > /tmp/ssh_known_hosts_fixed_$SERVER

    # 将替换后的主机指纹添加到 known_hosts 文件中
    cat /tmp/ssh_known_hosts_fixed_$SERVER >> ~/.ssh/known_hosts

    for TARGET_SERVER in ${SERVERS[@]}; do
        sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no root@$TARGET_SERVER "
        if ! ssh-keygen -F $SERVER &>/dev/null; then
            cat >> ~/.ssh/known_hosts
        else
            echo '$SERVER 的主机指纹已经存在，跳过添加'
        fi
        " < /tmp/ssh_known_hosts_fixed_$SERVER

        if [ $? -ne 0 ]; then
            echo "无法将主机指纹添加到 $TARGET_SERVER"
            continue
        fi
    done
done

# 去除 known_hosts 文件中的重复行
awk '!seen[$0]++' ~/.ssh/known_hosts > ~/.ssh/known_hosts.tmp && mv ~/.ssh/known_hosts.tmp ~/.ssh/known_hosts

echo "所有配置完成！"
