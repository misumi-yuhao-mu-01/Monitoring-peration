set -e
psql -U postgres postgres << EOSQL

/* misumi データベースを利用 */

\c misumi;

/* スキーマはデフォルトのpublicを一旦使う */
/* スキーマ変更する場合、このあたりに記載 */

/* 冪等性管理テーブル */

CREATE TABLE idempotent_requests(
  id        BIGSERIAL PRIMARY KEY,        -- 主キー
  key       VARCHAR(256) NOT NULL,     -- 冪等性キー
  target_id VARCHAR(128) NOT NULL,     -- 冪等性キーを発行した者の認証済みID
  method    VARCHAR(16) NOT NULL,      -- 処理方式(REST, EVENT, BATCHなど)
  status    VARCHAR(32) NOT NULL,      -- 処理状態(初期:CREATED, 終了:COMPLETED or FAILEDは固定)
  processor_name  VARCHAR(256),        -- このリクエストを処理するIdempotentRequestProcessorの名前(クラス名ではない)
  result    TEXT,                      -- 処理状態に紐付いたデータ(JSON)、COMPLETED or FAILEDであればレスポンスデータ
  result_type_name VARCHAR(256),              -- resultの完全修飾クラス名
  retry_count SMALLINT NOT NULL DEFAULT 0, -- リトライ回数
  request_context   TEXT,                              -- typeによってはNULL
  request_context_type_name  VARCHAR(256),             -- request_contextの完全修飾クラス名
  request_data   TEXT,                                 -- typeによってはNULL
  request_data_type_name  VARCHAR(256),                -- request_dataの完全修飾クラス名
  last_run_at TIMESTAMP WITH TIME ZONE default now(), -- 最終実行日時
  register_date_time  TIMESTAMP WITH TIME ZONE NOT NULL default now(),    -- 登録日時
  register_user  VARCHAR(256) NOT NULL,    -- 登録者
  register_user_type  VARCHAR(15) NOT NULL,    -- 登録者区分
  register_client_program  VARCHAR(15) NOT NULL,    -- 登録呼び出し元プログラム
  register_program  VARCHAR(15) NOT NULL,    -- 登録プログラム
  update_date_time  TIMESTAMP WITH TIME ZONE  NOT NULL default now(),    -- 更新日時
  update_user  VARCHAR(256) NOT NULL,    -- 更新者
  update_user_type  VARCHAR(15) NOT NULL,    -- 更新者区分
  update_client_program  VARCHAR(15) NOT NULL,    -- 更新呼び出し元プログラム
  update_program  VARCHAR(15) NOT NULL,    -- 更新プログラム
  update_count  INTEGER NOT NULL DEFAULT 0,  -- 更新回数
  delete_flag  CHAR(1) NOT NULL default '0',  -- 削除フラグ
  state_data   TEXT,                                   -- typeによってはNULL
  state_data_type_name  VARCHAR(256),                  -- state_dataの完全修飾クラス名
  running boolean default false, -- trueなら実行中
  auto_retry_enabled boolean default false,   -- 自動リトライを行うか
  status_log  VARCHAR(512),                -- statusの遷移ログ
  version BIGINT NOT NULL DEFAULT 0       -- 楽観ロック用のバージョン
);

CREATE UNIQUE INDEX idempotency_requests_key_target_id_idx ON idempotent_requests (key, target_id);
CREATE INDEX idempotency_last_run_at_status_idx ON idempotent_requests (last_run_at, status);

/* イベントテーブル */
/* event.producer.databaseの設定と合わせること */

CREATE TABLE produced_events_1 (
  id        BIGSERIAL PRIMARY KEY,       -- 主キー
  idempotency_key VARCHAR(256) NOT NULL, -- 冪等性キー
  target_id VARCHAR(128) NOT NULL,       -- 冪等性キーを発行した者の認証済みID
  destination VARCHAR(128) NOT NULL,     -- 送信先のストリーム(Kinesis）やトピック(Kafka)
  partition_key VARCHAR(128) NOT NULL,   -- パーティションキー
  payload TEXT NOT NULL,                 -- JSON化されたデータ
  created_at  TIMESTAMP NOT NULL,        -- 作成日時
  retry_count SMALLINT,                  -- リトライ回数
  has_error   boolean default false,     -- 送信エラーになったかどうか
  error_reason TEXT                      -- has_errorがtrueの場合のエラー理由
);

CREATE UNIQUE INDEX produced_events_1_idempotency_key_target_id_idx ON produced_events_1 (idempotency_key, target_id);

CREATE TABLE produced_events_position_1 (
  id        BIGSERIAL PRIMARY KEY,       -- 主キー
  position  BIGINT NOT NULL default 0,   -- produced_eventsのどの位置まで送信済みか
  updated_at TIMESTAMP default now()     -- 更新日時
);

INSERT INTO produced_events_position_1 (position) VALUES (0);

CREATE TABLE produced_events_2 (
  id        BIGSERIAL PRIMARY KEY,       -- 主キー
  idempotency_key VARCHAR(256) NOT NULL, -- 冪等性キー
  target_id VARCHAR(128) NOT NULL,       -- 冪等性キーを発行した者の認証済みID
  destination VARCHAR(128) NOT NULL,     -- 送信先のストリーム(Kinesis）やトピック(Kafka)
  partition_key VARCHAR(128) NOT NULL,   -- パーティションキー
  payload TEXT NOT NULL,                 -- JSON化されたデータ
  created_at  TIMESTAMP NOT NULL,        -- 作成日時
  retry_count SMALLINT,                  -- リトライ回数
  has_error   boolean default false,     -- 送信エラーになったかどうか
  error_reason TEXT                      -- has_errorがtrueの場合のエラー理由
);

CREATE UNIQUE INDEX produced_events_2_idempotency_key_target_id_idx ON produced_events_2 (idempotency_key, target_id);

CREATE TABLE produced_events_position_2 (
  id        BIGSERIAL PRIMARY KEY,       -- 主キー
  position  BIGINT NOT NULL default 0,   -- produced_eventsのどの位置まで送信済みか
  updated_at TIMESTAMP NOT NULL  default now() -- 更新日時
);

INSERT INTO produced_events_position_2 (position) VALUES (0);

/* 非同期タスクテーブル */

CREATE TABLE async_tasks (
  id        BIGSERIAL PRIMARY KEY,       -- 主キー
  idempotency_key VARCHAR(256) NOT NULL, -- 冪等性キー
  target_id VARCHAR(128) NOT NULL,       -- 冪等性キーを発行した者の認証済みID
  headers    TEXT NOT NULL,                 -- JSON化されたデータ
  payload    TEXT NOT NULL,                 -- JSON化されたデータ
  created_at  TIMESTAMP NOT NULL,        -- 作成日時
  retry_count SMALLINT,                  -- リトライ回数
  has_error   boolean default false,     -- 送信エラーになったかどうか
  error_reason TEXT                      -- has_errorがtrueの場合のエラー理由
);

CREATE UNIQUE INDEX async_tasks_idempotency_key_target_id_idx ON async_tasks (idempotency_key, target_id);

CREATE TABLE async_tasks_position (
  id        BIGSERIAL PRIMARY KEY,       -- 主キー
  position  BIGINT NOT NULL default 0,   -- async_tasksのどの位置まで送信済みか
  updated_at TIMESTAMP default now()     -- 更新日時
);

INSERT INTO async_tasks_position (position) VALUES (0);

/* 一時ファイル管理テーブル */

CREATE TABLE temporary_files (
  id                  BIGSERIAL PRIMARY KEY,                     -- 主キー
  temporary_file_id   VARCHAR(128) NOT NULL,                     -- 一時ファイルID
  temporary_file_path VARCHAR(256) NOT NULL,                     -- 一時ファイルパス
  auth_user_type      VARCHAR(128) NOT NULL,                     -- 認証ユーザタイプ
  auth_user_name      VARCHAR(128) NOT NULL,                     -- 認証ID
  stored_file_path    VARCHAR(256) NOT NULL,                     -- 保存用パス
  register_date_time  TIMESTAMP WITH TIME ZONE NOT NULL default now(),    -- 登録日時
  register_user  VARCHAR(256) NOT NULL,    -- 登録者
  register_user_type  VARCHAR(15) NOT NULL,    -- 登録者区分
  register_client_program  VARCHAR(15) NOT NULL,    -- 登録呼び出し元プログラム
  register_program  VARCHAR(15) NOT NULL,    -- 登録プログラム
  update_date_time  TIMESTAMP WITH TIME ZONE  NOT NULL default now(),    -- 更新日時
  update_user  VARCHAR(256) NOT NULL,    -- 更新者
  update_user_type  VARCHAR(15) NOT NULL,    -- 更新者区分
  update_client_program  VARCHAR(15) NOT NULL,    -- 更新呼び出し元プログラム
  update_program  VARCHAR(15) NOT NULL,    -- 更新プログラム
  update_count  INTEGER NOT NULL DEFAULT 0,  -- 更新回数
  delete_flag  CHAR(1) NOT NULL default '0'  -- 削除フラグ
);

CREATE UNIQUE INDEX temporary_files_temporary_file_id_auth_user_name ON temporary_files (temporary_file_id, auth_user_name);


/* 運用日付管理テーブル */

CREATE TABLE operation_date_table (
  id                  BIGSERIAL PRIMARY KEY,                     -- 主キー
  operation_date      DATE NOT NULL,                             -- 運用日付
  service_code        VARCHAR(3) NOT NULL,                       -- サービスコード
  created_at          TIMESTAMP WITH TIME ZONE default now(),    -- 作成日時
  updated_at          TIMESTAMP WITH TIME ZONE default now()     -- 更新日時
);

EOSQL
