#!/bin/bash
#このファイルは削除をお願いします。
#スクリプトに実行権限の付与をお願いします。
# 例：chmod 755 dummy.sh
# xxx-service/xxx-script-batch/scripts/配下に
# スクリプトバッチコンテナで動作させたいスクリプトを配置してください。

# 現法POD集約対応を実施するために、MWAAから起動されるスクリプトの先頭に、次の行をおまじないとして挿入してください。
. $(dirname $0)/apply_subsidiary.sh

echo "infra test"