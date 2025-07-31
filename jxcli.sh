#!/bin/bash

GAMEPATH=${GAMEPATH:-/home/jxser_6_bachkim}
PAYSETUP_PATH="/root/serversetup/paysyswin"
LOG_FILE="/var/log/jxserver.log"

# Map process name by index
declare -A PROCESS_MAP=(
  [1]="PaySys"
  [2]="RelayServer"
  [3]="Goddess"
  [4]="Bishop"
  [5]="S3Relay"
  [6]="GameServer"
)

declare -A CMD_MAP=(
  ["PaySys"]="Sword3PaySys.exe"
  ["RelayServer"]="S3RelayServer.exe"
  ["Goddess"]="goddess_y"
  ["Bishop"]="bishop_y"
  ["S3Relay"]="s3relay_y"
  ["GameServer"]="jx_linux_y"
)

declare -A PATH_MAP=(
  ["PaySys"]="$PAYSETUP_PATH"
  ["RelayServer"]="$PAYSETUP_PATH"
  ["Goddess"]="$GAMEPATH/gateway"
  ["Bishop"]="$GAMEPATH/gateway"
  ["S3Relay"]="$GAMEPATH/gateway/s3relay"
  ["GameServer"]="$GAMEPATH/server1"
)

function log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

function start_process() {
    name="$1"
    path="${PATH_MAP[$name]}"
    cmd="${CMD_MAP[$name]}"

    if pgrep -f "$cmd" > /dev/null; then
        echo "$name đang chạy."
    else
        echo "Khởi động $name..."
        cd "$path" || exit

        if [[ "$name" == "S3Relay" || "$name" == "GameServer" ]]; then
            session_name="jx_${name,,}"  # tên phiên tmux: jx_s3relay hoặc jx_gameserver
            chmod +x "./$cmd"
            tmux new-session -d -s "$session_name" "./$cmd"
            echo "$name đã được mở trong cửa sổ tmux [$session_name]."
            echo "Dùng: tmux attach -t $session_name  để xem log"
        else
            nohup ./"$cmd" > /dev/null 2>&1 &
            log "Started $name"
            echo "$name đã được khởi động (nền)."
        fi
    fi
}

function stop_process() {
    name="$1"
    cmd="${CMD_MAP[$name]}"

    if pgrep -f "$cmd" > /dev/null; then
        echo "Tắt $name..."
        pkill -f "$cmd"
        log "Stopped $name"
        echo "$name đã được tắt."
    else
        echo "$name không chạy."
    fi
}

function status_process() {
    name="$1"
    cmd="${CMD_MAP[$name]}"
    if pgrep -f "$cmd" > /dev/null; then
        echo "$name: ✅ ĐANG CHẠY"
    else
        echo "$name: ❌ ĐÃ TẮT"
    fi
}

function start_all() {
    for id in {1..6}; do
        name="${PROCESS_MAP[$id]}"
        start_process "$name"
        sleep 1
    done
}

function stop_all() {
    for id in {6..1}; do
        name="${PROCESS_MAP[$id]}"
        stop_process "$name"
        sleep 1
    done
}

function status_all() {
    for id in {1..6}; do
        name="${PROCESS_MAP[$id]}"
        status_process "$name"
    done
}

function restart_gs_s3relay() {
    echo "Đang thực hiện restart GameServer + S3Relay theo thứ tự chuẩn..."
    stop_process "GameServer"
    sleep 1
    stop_process "S3Relay"
    sleep 2
    start_process "S3Relay"
    sleep 2
    start_process "GameServer"
    echo "Đã restart xong."
}

function numeric_call() {
    x=$1
    y=$2
    name="${PROCESS_MAP[$x]}"
    [[ "$y" == "1" ]] && start_process "$name" || stop_process "$name"
}

function tui_menu() {
    while true; do
        echo ""
        echo "===== MENU QUẢN LÝ SERVER JX ====="
        echo "1. Start toàn bộ"
        echo "2. Stop toàn bộ"
        echo "3. Trạng thái"
        echo "4. Restart (s3relay_y + jx_linux_y)"
        echo "5. Bật/Tắt từng phần theo số"
        echo "0. Thoát"
        echo "=================================="
        read -p "Chọn số: " choice
        case "$choice" in
            1) start_all ;;
            2) stop_all ;;
            3) status_all ;;
            4) restart_gs_s3relay ;;
            5)
                echo "Chọn tiến trình: "
                echo "  1. PaySys"
                echo "  2. RelayServer"
                echo "  3. Goddess"
                echo "  4. Bishop"
                echo "  5. S3Relay"
                echo "  6. GameServer"
                read -p "Tiến trình số: " pid
                read -p "Bật (1) hay Tắt (0): " paction
                numeric_call "$pid" "$paction"
                ;;
            0) echo "Thoát."; break ;;
            *) echo "Lựa chọn không hợp lệ!" ;;
        esac
    done
}

function help_menu() {
    echo "Sử dụng:"
    echo "  $0 start|stop|status                    # Quản lý toàn bộ"
    echo "  $0 start <tên>                          # Khởi động riêng"
    echo "  $0 stop <tên>                           # Tắt riêng"
    echo "  $0 restart gs                           # Restart s3relay_y + jx_linux_y"
    echo "  $0 <số> <0|1>                           # Gọi bằng số"
    echo "  $0 menu                                 # Mở menu dòng lệnh"
}

# ===========================
# XỬ LÝ DÒNG LỆNH
# ===========================
if [[ "$1" =~ ^[1-6]$ && "$2" =~ ^[01]$ ]]; then
    numeric_call "$1" "$2"
    exit 0
fi

case "$1" in
    start)
        if [ -n "$2" ]; then
            start_process "$2"
        else
            start_all
        fi
        ;;
    stop)
        if [ -n "$2" ]; then
            stop_process "$2"
        else
            stop_all
        fi
        ;;
    status)
        status_all
        ;;
    restart)
        if [[ "$2" == "gs" ]]; then
            restart_gs_s3relay
        else
            echo "Chỉ hỗ trợ: restart gs"
        fi
        ;;
    menu)
        tui_menu
        ;;
    help|-h|--help)
        help_menu
        ;;
    *)
        echo "❌ Lệnh không hợp lệ."
        help_menu
        ;;
esac
