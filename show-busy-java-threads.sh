#!/bin/bash
# @Function
# 找出Java进程中CPU消耗最高的线程，并打印这些线程的堆栈信息。
#
# @Usage
#   $ ./show-busy-java-threads.sh
#
# @Author bsdos

readonly PROG=$(basename "$0")
readonly COMMAND_LINE=("$0" "$@")

usage() {
  cat <<EOF
用法: ${PROG} [选项]...
找出Java进程中CPU消耗最高的线程，并打印这些线程的堆栈信息。
示例: ${PROG} -c 10

选项:
  -p, --pid       指定Java进程，默认查找所有Java进程。
  -c, --count     设置要显示的线程数量，默认是5。
  -h, --help      显示此帮助信息并退出。
EOF
  exit "$1"
}

ARGS=$(getopt -n "$PROG" -a -o c:p:h -l count:,pid:,help -- "$@")
[ $? -ne 0 ] && usage 1
eval set -- "${ARGS}"

while true; do
  case "$1" in
    -c|--count)
      count="$2"
      shift 2
      ;;
    -p|--pid)
      pid="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    --)
      shift
      break
      ;;
  esac
done
count=${count:-5}

colorEcho() {
  local color=$1
  shift
  if [ -t 1 ]; then
    echo -ne "\033[1;${color}m"
    echo -n "$@"
    echo -e "\033[0m"
  else
    echo "$@"
  fi
}

redEcho() {
  colorEcho 31 "$@"
}

yellowEcho() {
  colorEcho 33 "$@"
}

blueEcho() {
  colorEcho 36 "$@"
}

# 检查jstack命令是否存在
if ! command -v jstack &>/dev/null; then
  if [ -z "$JAVA_HOME" ] || [ ! -x "$JAVA_HOME/bin/jstack" ]; then
    redEcho "错误: jstack命令未找到在PATH或JAVA_HOME/bin中!"
    exit 1
  fi
  export PATH="$JAVA_HOME/bin:$PATH"
fi

readonly uuid=$(date +%s)_${RANDOM}_$$

cleanupWhenExit() {
  rm /tmp/${uuid}_* &>/dev/null
}
trap "cleanupWhenExit" EXIT

printStackOfThreads() {
  local line
  local count=1
  while IFS=" " read -a line; do
    local pid=${line[0]}
    local threadId=${line[1]}
    local threadId0x=$(printf '0x%x' "${threadId}")
    local user=${line[2]}
    local pcpu=${line[4]}
    local jstackFile="/tmp/${uuid}_${pid}"

    if [ ! -f "${jstackFile}" ]; then
      if [ "${user}" == "${USER}" ]; then
        jstack "${pid}" > "${jstackFile}"
      elif [ $UID -eq 0 ]; then
        sudo -u "${user}" jstack "${pid}" > "${jstackFile}"
      else
        redEcho "[$((count++))] 无法获取Java进程(${pid})中CPU占用(${pcpu}%)的线程(${threadId}/${threadId0x})堆栈，用户(${user})不同于当前用户(${USER})，需要使用sudo再次运行："
        yellowEcho "    sudo ${COMMAND_LINE[@]}"
        echo
        continue
      fi
    fi

    if [ ! -s "${jstackFile}" ]; then
      redEcho "[$((count++))] 无法获取Java进程(${pid})中CPU占用(${pcpu}%)的线程(${threadId}/${threadId0x})堆栈，用户(${user})不同于当前用户(${USER})。"
      rm -f "${jstackFile}"
      continue
    fi

    blueEcho "[$((count++))] Java进程(${pid})中CPU占用(${pcpu}%)的线程(${threadId}/${threadId0x})堆栈，用户(${user}):"
    sed -n "/nid=${threadId0x} /,/^$/p" "${jstackFile}"
  done
}

ps -Leo pid,lwp,user,comm,pcpu --no-headers | {
  if [ -z "${pid}" ]; then
    awk '$4 == "java" {print $0}'
  else
    awk -v pid="${pid}" '$1 == pid && $4 == "java" {print $0}'
  fi
} | sort -k5 -r -n | head --lines "${count}" | printStackOfThreads
