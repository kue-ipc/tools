# ログマネージャー Log Manager

保管されたログを圧縮・削除したり、リモートからログを集めたりするためのツールです。

## ライセンス

Copyright 2022-2023 Kyoto University of Education
The MIT License

## 動作環境

* Ruby 2.5以上、WindowsのみRuby 3.0以上
* gzip (zip_pwを使用する場合はPowerShellで代替可能)
* rsync (rsyncを使用する場合のみ)
* OpenSSH (scpを使用する場合のみ)

## 使い方

### インストール方法

1. [Ruby](https://www.ruby-lang.org/ja/)をインストールします。
2. 適当なところをに置きます。
3. `etc/log_manager.yml.linux_sample`等を参考に`etc/log_manager.yml`を作成します。ファイルは、`/etc`、`/usr/local/etc`に置いても認識されます。

### 実行

`bin/lmg`がコマンドで、四つのコマンドが用意されています。

* `check`  ... ログディレクトリのディスクの空き容量をチェックする。
* `clean`  ... 古いログを圧縮・削除する。
* `rsync`  ... rsyncを用いてリモートからログファイルを取得する。(Windows未テスト)
* `scp`    ... scp(ssh)を用いてリモートからログファイルを取得する。(Windows未テスト)
* `show`   ... 設定の表示する。

c`-n`をつけるとファイルの変更がないモード(noop mode)になります。テストなどの確認に使ってください。また、`rsync`と`scp`については、`-h ホスト`でコピーするホストを指定できます。

### check

WindowsとLinuxのみ対応しています。Linuxではi-nodeの空き容量も確認します。その他のOSで実行した場合、エラーになります。

デフォルトの閾値は80%です。閾値を超えるとエラーになります。各閾値は`check.block_threshold`と`check.inode_threshold`に小数点数で設定できます。

### clean

デフォルトの圧縮しない期間は2日間、削除せずに保持する期間は2年間です。各期間は、`clean.period_retention`と`clean.period_nocompress`に秒数で設定できます。

#### Windowsでの圧縮

デフォルトでは、圧縮にgzipコマンドを用いますが、Windows環境のためにPowerShell経由でZIP圧縮を行う`bin/zip_ps`を用意しています。PowerShellがインストールされていればLinuxでも使用可能です。使用する場合は、`clean.compress.cmd`に`bin/zip_ps`への絶対パスを設定してください。

### rysnc

ローカル側とリモート側の両方にrysncコマンドが必要です。あらかじめインストールしておいてください。

リモート接続はSSHを使用し、コマンドの実行ユーザーのSSHの設定を利用します。そのユーザーがパスワード無しでリモート先にアクセスできることを確認しておいてください。

リモート先にrootでログインすることは推奨されません。取得するログファイルのアクセス権の関係で、どうしてもrootでログインする必要がある場合は、下記の対策を実施してください。

#### リモート先にrootでログインする場合のセキュリティ対策

リモートにrootでログインする必要がある場合は、"sshd_config"でコマンド実行のみにしてください。

```sshd_config
PermitRootLogin forced-commands-only
```

どのようなアクセスをしても"authorized_keys"の`command`に書かれたコマンドが実行されるようになります。また、"authorized_keys"の`from`でローカル側を指定するようにしてください。次のようになります。

```/root/.ssh/authorized_keys
from="{ローカル側のIPアドレス}",command="rsync --server --sender -vvulDtprze.iLsfxC . {同期元のパス}" {ローカル側の鍵情報 ~/.ssh/id_*.pub の中身}
```

通常、リモート側では次のようなコマンドが実行されます。

```shell
rsync --server --sender -vvulDtprze.iLsfxC . /remote/log/path/
```

最後の引数が同期元のディレクトリになります。これを`command`で指定しますが、同期元ディレクトリを複数書くこともできます。

```shell
rsync --server --sender -vvulDtprze.iLsfxC . /log1 /loge2
```

このようにすることで、複数のディレクトリと同期をとることができます。同期元に関しては、ツールのコンフィグで設定している`dir`は無視されますので、ご注意ください。

### ssh

リモート先にrootでログインすることは推奨されません。rsyncのように一つのコマンドに限定することもできません。rootでの取得が必要な場合は、rsyncを検討してください。

## TODO

* ログ取得(同期)
    * [ ] SMB
    * [ ] SFTP
    * [ ] FTP
    * [ ] TFTP
* ディスクチェックの他OS対応
    * [ ] Mac
    * [ ] FreeBSD
    * [ ] OpenIndiana
* 外部コマンド非依存
    * [ ] gzip
    * [ ] rsync
    * [ ] OpenSSH
    * [ ] df (Linuxでcheck時に使用)
* [ ] gem
* [ ] マルチスレッド
