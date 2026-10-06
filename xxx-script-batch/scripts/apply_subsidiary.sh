#
# apply_subsidiary.sh
#
# スクリプトバッチ用のシェルを「現法POD集約対応」するための共通スクリプトです。
# MWAA(DAG)からPythonOperator経由で起動される各スクリプトバッチの先頭で、このファイルを含めるようにしてください（以下の「使用法」を参照）。
#
# ■ おもな機能
# (1) MWAA（DAG）からSYSTEM_SUBSIDIARY_CODE環境変数指定で呼び出され、かつ、SCRIPT_BATCH_DATASOURCE_現法コード_ENDPOINT環境変数が
#     設定されていた場合、集約POD上で現法指定で呼び出されたとみなし、以下の環境変数を、当該現法の変数で上書き設定します。
#     SCRIPT_BATCH_DATASOURCE_ENDPOINT
#     SCRIPT_BATCH_DATASOURCE_DBNAME
#     SCRIPT_BATCH_DATASOURCE_PORT
#     SCRIPT_BATCH_DATASOURCE_SCHEMA
#     SCRIPT_BATCH_STOREBUCKET
#     SPRING_DATASOURCE_URL
#     SPRING_DATASOURCE_USERNAME
#     SPRING_DATASOURCE_PASSWORD
#     SUBSIDIARY_CODE
#     SUBSIDIARY_LOW
#
# (2) スクリプト本体内で標準出力・標準エラー出力に出力されているメッセージを捕捉し、必要に応じてDatadogが解釈するタイムスタンプつきのJSON形式に変換した上で
#     標準出力・標準エラー出力に出力しなおします。
#     出力されるJSONは、以下の形式になります。
#
#     (2-1) スクリプトの出力形式がすでにJSON形式だった場合（2024/12時点で、bill01とmm01のsqlCheckスクリプトバッチのみが該当）
#        出力形式をあらためてJSONに変換することはしません。以下の＜追加出力設定＞を参照してください。
#
#     (2-2) スクリプトの出力形式が通常のテキスト形式だった場合（上記以外のすべてのスクリプトバッチ）
#        出力形式が、以下のように変換されます。
#        { "timeStamp":"YYYY-mm-ddTHH:MM:SS.NNN形式のUTC時刻", "level":"ログレベル", "message":"もとのテキスト（をJSONエスケープしたもの）" }
#        "level"は、テキストが [INFO] や [ERROR] など、[] で囲まれた文字列から開始される場合は、その値がセットされ、それ以外の場合は "INFO" がセットされます。
#
#     ＜追加出力設定＞
#     (2-1)、(2-2)のあと、さらに、出力JSONに以下のキー・値が設定されます。
#     ・"applicationType"キーの値が"scriptbatch"に、また"logtype"キーの値が"application-detail"に設定されます。
#     ・SYSTEM_SUBSIDIARY_CODE環境変数（現法コード）が設定されていた場合は "country"キー の値が "国コード（小文字2桁）" に設定されます。
#     ・SCRIPT_BATCH_BATCH_ID環境変数が設定されていた場合は "batchId"キー の値が "$SCRIPT_BATCH_BATCH_IDの値" に設定されます。
#
# ■ 使用法
# 本スクリプトを各サービスの サービス名-script-batch/script 直下に配置し、同じディレクトリの、MWAA(DAG)から起動されるスクリプトバッチについて、
# 以下のように、先頭に本スクリプトを含めるコードを追加してください。
#
# ===== AS IS =====
# #!/bin/bash
# スクリプト本体
# ・・・
# =================
#
# ===== TO BE =====
# #!/bin/bash
# . $(dirname $0)/apply_subsidiary.sh
# スクリプト本体
# ・・・
# =================
#
# なお、batchId属性を指定したい場合（ログのbatchId値を設定したい場合）は、以下のように SCRIPT_BATCH_BATCH_ID環境変数の設定するコードを含めてください。
#
# ===== TO BE（batchId指定） =====
# #!/bin/bash
# export SCRIPT_BATCH_BATCH_ID=MyBatchName
# . $(dirname $0)/apply_subsidiary.sh
# スクリプト本体
# ・・・
# =================
#

if [[ "${SYSTEM_SUBSIDIARY_CODE:-}" != "" ]]; then
    if [[ $(eval echo \${SCRIPT_BATCH_DATASOURCE_${SYSTEM_SUBSIDIARY_CODE}_ENDPOINT}) != "" ]]; then
        eval export SCRIPT_BATCH_DATASOURCE_ENDPOINT=\${SCRIPT_BATCH_DATASOURCE_${SYSTEM_SUBSIDIARY_CODE}_ENDPOINT}
        eval export SCRIPT_BATCH_DATASOURCE_DBNAME=\${SCRIPT_BATCH_DATASOURCE_${SYSTEM_SUBSIDIARY_CODE}_DBNAME}
        eval export SCRIPT_BATCH_DATASOURCE_PORT=\${SCRIPT_BATCH_DATASOURCE_${SYSTEM_SUBSIDIARY_CODE}_PORT}
        eval export SCRIPT_BATCH_DATASOURCE_SCHEMA=\${SCRIPT_BATCH_DATASOURCE_${SYSTEM_SUBSIDIARY_CODE}_SCHEMA}
        eval export SCRIPT_BATCH_STOREBUCKET=\${SCRIPT_BATCH_STOREBUCKET_${SYSTEM_SUBSIDIARY_CODE}}
        eval export SPRING_DATASOURCE_URL=\${SPRING_DATASOURCE_${SYSTEM_SUBSIDIARY_CODE}_URL}
        eval export SPRING_DATASOURCE_USERNAME=\${SPRING_DATASOURCE_${SYSTEM_SUBSIDIARY_CODE}_USERNAME}
        eval export SPRING_DATASOURCE_PASSWORD=\${SPRING_DATASOURCE_${SYSTEM_SUBSIDIARY_CODE}_PASSWORD}
        eval export SUBSIDIARY_CODE=${SYSTEM_SUBSIDIARY_CODE}
        eval export SUBSIDIARY_LOW=${SYSTEM_SUBSIDIARY_CODE,,}
    fi
fi

# 現法コード -> 国コードのマップ
declare -A _COUNTRY_CODE_MAP=(
    ["TIW"]="tw"
    ["THA"]="th"
    ["MJP"]="jp"
    ["KOR"]="kr"
    ["GRM"]="de"
    ["USA"]="us"
    ["MEX"]="mx"
    ["HKG"]="hk"
    ["SGP"]="sg"
    ["MYS"]="my"
    ["IND"]="in"
    ["JKT"]="id"
    ["VNM"]="vn"
    ["CHN"]="cn"
)

_process_line() {
    local output_target="$1"  # 出力先を指定 (1=STDOUT, 2=STDERR)
    local json_string

    while read line; do
        # JSONのオブジェクト形式かどうかを判定
        if echo "$line" | jq -e 'select(type=="object")' >/dev/null 2>&1; then
            # JSONの場合はそのまま
            json_string="$line"
        else
            # JSONでない場合、新しいJSONを作成
            local timestamp level message
            timestamp=$(date +"%Y-%m-%dT%H:%M:%S.%3N")

            if [[ "$line" =~ ^\[([a-zA-Z0-9]+)\] ]]; then
                level="${BASH_REMATCH[1]}"
            else
                level="INFO"
            fi

            # message は line の内容を、JSON形式で安全にエスケープした上で設定する
            message=$(printf '%s' "$line" | jq -R .)

            # JSON文字列の生成（messageは上記で既にJSONフォーマット済なので "" で囲む必要はない）
            json_string="{\"timeStamp\":\"$timestamp\",\"level\":\"$level\",\"message\":$message}"
        fi

        # 現法コードが設定されていた場合は、それを国コードに変換して country 属性を付与する
        if [[ "${SYSTEM_SUBSIDIARY_CODE:-}" != "" ]]; then
            json_string=$(echo "$json_string" | jq -c --arg country "${_COUNTRY_CODE_MAP[$SYSTEM_SUBSIDIARY_CODE]}" '. + {country: $country}')
        fi

        # SCRIPT_BATCH_BATCH_IDが設定されていた場合は、batchId属性を付与する
        if [[ "${SCRIPT_BATCH_BATCH_ID:-}" != "" ]]; then
            json_string=$(echo "$json_string" | jq -c --arg batchId "${SCRIPT_BATCH_BATCH_ID}" '. + {batchId: $batchId}')
        fi

        # applicationType属性に"scriptbatch"を、またlogtype属性に"application-detail"を設定する
        json_string=$(echo "$json_string" | jq -c '. + {applicationType: "scriptbatch", logtype: "application-detail"}')

        echo "$json_string" >&"$output_target"
    done
}

# 環境変数をチェックしてログ変換を実施
if [[ ! "${SCRIPT_BATCH_DISABLE_LOG_TRANSFORM:-}" =~ ^(true|1|yes)$ ]]; then
    # 環境変数が "true"、"1"、"yes" でない場合のみログ変換を実施
    exec > >(_process_line 1)
    exec 2> >(_process_line 2)
fi
