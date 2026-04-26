#!/bin/sh
set -eu

RULE_DIR="/etc/momo/ruleset"
LOG_FILE="$RULE_DIR/update.log"
TMP_DIR="$RULE_DIR/.tmp"
mkdir -p "$RULE_DIR" "$TMP_DIR"
cd "$RULE_DIR" || exit 1

# 检查 sing-box 是否存在
if ! command -v sing-box >/dev/null 2>&1; then
    echo "$(date +'%F %T') ⚠ sing-box 未安装，跳过规则转换" >> "$LOG_FILE"
    SINGBOX_AVAILABLE=0
else
    SINGBOX_AVAILABLE=1
fi

# 日志截断（超过 1MB）
MAX_SIZE=1048576
[ -f "$LOG_FILE" ] && [ "$(wc -c <"$LOG_FILE")" -gt "$MAX_SIZE" ] && echo "日志超过 1MB，自动清理..." > "$LOG_FILE"

# 并发数
CONCURRENCY=4

# 并发下载函数
parallel_download() {
    max_jobs="$1"; shift
    for pair in "$@"; do
        file="${pair%%|*}"
        url="${pair#*|}"
        (
            tmp="$TMP_DIR/${file}.$$"
            echo "$(date +'%F %T') 下载: $file from $url" >> "$LOG_FILE"
            if wget --no-check-certificate -q -O "$tmp" "$url"; then
                mv -f "$tmp" "$file"
                echo "$(date +'%F %T') ✔ 成功: $file" >> "$LOG_FILE"
            else
                rm -f "$tmp"
                echo "$(date +'%F %T') ✘ 失败: $file" >> "$LOG_FILE"
            fi
        ) &
        while [ "$(jobs -p | wc -l)" -ge "$max_jobs" ]; do
            sleep 1
        done
    done
    wait
}

# 单文件下载
download_once() {
    file="$1"; url="$2"
    tmp="$TMP_DIR/${file}.$$"
    echo "$(date +'%F %T') 下载: $file from $url" >> "$LOG_FILE"
    if wget --no-check-certificate -q -O "$tmp" "$url"; then
        mv -f "$tmp" "$file"
        echo "$(date +'%F %T') ✔ 成功: $file" >> "$LOG_FILE"
        return 0
    else
        rm -f "$tmp"
        echo "$(date +'%F %T') ✘ 失败: $file" >> "$LOG_FILE"
        return 1
    fi
}

# 基础地址
BASE="https://gh-proxy.com/https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo"

pairs=(
"ads.srs|$BASE/geosite/category-ads-all.srs"
"private.srs|$BASE/geosite/private.srs"
"microsoft-cn.srs|$BASE/geosite/microsoft.srs"
"apple-cn.srs|$BASE/geosite/apple.srs"
"google-cn.srs|$BASE/geosite/google.srs"
"youtube.srs|$BASE/geosite/youtube.srs"
"telegram.srs|$BASE/geosite/telegram.srs"
"tencent.srs|$BASE/geosite/tencent.srs"
"cn.srs|$BASE/geosite/cn.srs"
"ai.srs|$BASE/geosite/category-ai-!cn.srs"
"gfw.srs|$BASE/geosite/gfw.srs"
"tld-proxy.srs|$BASE/geosite/tld-!cn.srs"
"games.srs|$BASE/geosite/steam.srs"
"telegramip.srs|$BASE/geoip/telegram.srs"
"cnip.srs|$BASE/geoip/cn.srs"
"github.srs|$BASE/geosite/github.srs"
)

parallel_download "$CONCURRENCY" "${pairs[@]}"

# fakeipfilter.json 下载与转换
FAKEIP_URL="https://gh-proxy.com/https://raw.githubusercontent.com/qichiyuhub/rule/refs/heads/main/rules/fakeipfilter.json"
if download_once "fakeipfilter.json" "$FAKEIP_URL"; then
    if [ "$SINGBOX_AVAILABLE" -eq 1 ]; then
        if sing-box rule-set compile --output geosite-fakeipfilter.srs fakeipfilter.json >/dev/null 2>&1; then
            echo "$(date +'%F %T') ✔ 成功生成 geosite-fakeipfilter.srs" >> "$LOG_FILE"
            rm -f fakeipfilter.json
        else
            echo "$(date +'%F %T') ✘ 转换失败（保留 fakeipfilter.json）" >> "$LOG_FILE"
        fi
    else
        echo "$(date +'%F %T') ⚠ sing-box 不可用，跳过 fakeipfilter 转换" >> "$LOG_FILE"
    fi
fi

# 生成 trackerslist.srs
TRACKERS_URL="https://gh-proxy.com/https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all.txt"
TRACKERS_TXT="$TMP_DIR/trackers_all.txt.$$"
if wget --no-check-certificate -q -O "$TRACKERS_TXT" "$TRACKERS_URL"; then
    awk 'BEGIN { print "{\"version\":1,\"rules\":[" } { gsub(/"/, "\\\""); printf "%s{\"domain\":\"%s\"}", (NR==1?"":","), $0 } END { print "]}" }' "$TRACKERS_TXT" > "$TMP_DIR/trackers_all.json.$$"
    if [ "$SINGBOX_AVAILABLE" -eq 1 ]; then
        if sing-box rule-set compile --output trackerslist.srs "$TMP_DIR/trackers_all.json.$$" >/dev/null 2>&1; then
            echo "$(date +'%F %T') ✔ 成功生成 trackerslist.srs" >> "$LOG_FILE"
        else
            echo "$(date +'%F %T') ✘ 生成 trackerslist.srs 失败" >> "$LOG_FILE"
        fi
    else
        echo "$(date +'%F %T') ⚠ sing-box 不可用，跳过 trackerslist 转换" >> "$LOG_FILE"
    fi
    rm -f "$TRACKERS_TXT" "$TMP_DIR/trackers_all.json.$$"
else
    echo "$(date +'%F %T') ✘ 下载 trackers_all.txt 失败" >> "$LOG_FILE"
fi

rm -rf "$TMP_DIR"

echo "$(date +'%F %T') 规则集更新完成。" >> "$LOG_FILE"
