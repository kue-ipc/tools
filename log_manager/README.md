# ログマネージャー Log Manager

## 動作環境

* Ruby 2.0 以上
* gzip
* rsync
* OpenSSH (ssh, scp)

## 使い方

### インストール方法

1. 適当なところをに置きます。

2. `etc/log_manager.yml.sampl`を参考に`etc/log_manager.yml`を作成します。
    ファイルは、`/etc`、`/usr/etc`、`/usr/local/etc`においてもいいです。

### 実行

`bin/lmg`がコマンドで、四つのサブコマンドが用意されています。

* `lmg config` ... 設定の表示する。
* `lmg clean`  ... 古いログを圧縮・削除する。
* `lmg rsync`  ... rsyncを用いてリモートからログファイルを取得する。
* `lmg scp`    ... scp(ssh)を用いてリモートからログファイルを取得する。

config以外では`-n`をつけるとファイルの変更がないモード(noop mode)になります。テストなどの確認に使ってください。また、rsyncとscpでは`-h ホスト`でホスト指定もできます。

### SSHの鍵などについて

rsyncとscp(ssh)は実行ユーザーのSSHの設定を利用します。秘密鍵などは実行するユーザーに設定しておいてください。
