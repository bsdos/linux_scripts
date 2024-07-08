#!/bin/bash

# 脚本名称: install_containerd.sh
# 版本: 1.8
# 作者: bsdos
# 日期: 2024-07-08

# 说明:
# 这个脚本用于自动下载、校验并安装指定版本的containerd，并配置systemd服务。
# 用户可以通过修改VERSION变量来指定containerd的版本。

# 使用方法:
# ./install_containerd.sh [-v 版本号] [-o 下载路径] [-u 下载地址] [-h]

# 参数:
# -v 版本号     指定containerd的版本号（默认: 1.6.10）
# -o 下载路径   指定下载路径（默认: /tmp）
# -u 下载地址   指定下载地址（优先级高于文件中的地址）
# -h           显示帮助信息

# 默认版本号和下载路径
VERSION="1.6.10"
DOWNLOAD_PATH="/tmp"
DOWNLOAD_URL=""

# 从container_url.txt文件读取下载地址
CONTAINER_URL_FILE="./container_url.txt"
if [ -f "$CONTAINER_URL_FILE" ]; then
  DOWNLOAD_URL=$(grep -v "^#" $CONTAINER_URL_FILE)
fi

# 如果文件中没有有效地址，则使用默认GitHub地址
DEFAULT_GITHUB_URL="https://github.com/containerd/containerd/releases/download"
if [ -z "$DOWNLOAD_URL" ]; then
  DOWNLOAD_URL=$DEFAULT_GITHUB_URL
fi

# 显示帮助信息的函数
usage() {
  echo "用法: $0 [-v 版本号] [-o 下载路径] [-u 下载地址] [-h]"
  echo
  echo "参数:"
  echo "  -v 版本号     指定containerd的版本号（默认: 1.6.10）"
  echo "  -o 下载路径   指定下载路径（默认: /tmp）"
  echo "  -u 下载地址   指定下载地址（优先级高于文件中的地址）"
  echo "  -h           显示帮助信息"
  exit 1
}

# 解析参数
while getopts "v:o:u:h" opt; do
  case $opt in
    v)
      VERSION=$OPTARG
      ;;
    o)
      DOWNLOAD_PATH=$OPTARG
      ;;
    u)
      DOWNLOAD_URL=$OPTARG
      ;;
    h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

# 创建下载路径目录（如果不存在）
mkdir -p $DOWNLOAD_PATH

# 下载文件和校验文件的路径
TAR_FILE="$DOWNLOAD_PATH/containerd-$VERSION-linux-amd64.tar.gz"
SUM_FILE="$DOWNLOAD_PATH/containerd-$VERSION-linux-amd64.tar.gz.sha256sum"

# 检查文件是否已经存在
if [ ! -f "$TAR_FILE" ]; then
  # 第一步：下载containerd压缩包
  wget -P $DOWNLOAD_PATH $DOWNLOAD_URL/v$VERSION/containerd-$VERSION-linux-amd64.tar.gz
else
  echo "$TAR_FILE 已经存在，跳过下载"
fi

if [ ! -f "$SUM_FILE" ]; then
  # 下载校验文件
  wget -P $DOWNLOAD_PATH $DOWNLOAD_URL/v$VERSION/containerd-$VERSION-linux-amd64.tar.gz.sha256sum
else
  echo "$SUM_FILE 已经存在，跳过下载"
fi

# 第二步：校验下载的文件
cd $DOWNLOAD_PATH
sha256sum -c containerd-$VERSION-linux-amd64.tar.gz.sha256sum

# 如果校验失败，退出脚本
if [ $? -ne 0 ]; then
  echo "校验失败，退出脚本"
  exit 1
fi

# 第三步：解压缩文件到/usr/local/bin
tar zxvf containerd-$VERSION-linux-amd64.tar.gz -C /usr/local/bin --strip-components=1

# 第四步：创建/etc/containerd目录
mkdir -p /etc/containerd

# 第五步：生成默认的containerd配置文件（如果不存在）
if [ ! -f /etc/containerd/config.toml ]; then
  containerd config default | sudo tee /etc/containerd/config.toml
else
  echo "/etc/containerd/config.toml 已经存在，跳过生成默认配置文件"
fi

# 第六步：创建systemd服务文件（如果不存在）
if [ ! -f /etc/systemd/system/containerd.service ]; then
  sudo tee /etc/systemd/system/containerd.service <<EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStart=/usr/local/bin/containerd
Restart=always
RestartSec=5
KillMode=process
Delegate=yes
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
else
  echo "/etc/systemd/system/containerd.service 已经存在，跳过创建服务文件"
fi

# 第七步：重新加载systemd守护进程
systemctl daemon-reload

# 第八步：启动containerd服务（注释掉）
# systemctl start containerd

# 第九步：查看containerd服务状态（注释掉）
# systemctl status containerd
