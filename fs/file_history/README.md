# ファイルアクセスログ

TODO: スクリプトで取り出すのはやめる

## 監査ポリシー

- オブジェクト アクセス
    - ファイル システム  {0CCE921D-69AE-11D9-BED3-505054503030}
    - ハンドル操作       {0CCE9223-69AE-11D9-BED3-505054503030}
    - ファイルの共有     {0CCE9224-69AE-11D9-BED3-505054503030}
    - 詳細なファイル共有 {0CCE9244-69AE-11D9-BED3-505054503030}

```cmd
auditpol /set /subcategory:"{0CCE921D-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
auditpol /set /subcategory:"{0CCE9223-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
auditpol /set /subcategory:"{0CCE9224-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
auditpol /set /subcategory:"{0CCE9244-69AE-11D9-BED3-505054503030}" /success:enable /failure:enable
auditpol /get /category:*
```

## 監査のエントリ

- プリンシパル: Everyone
- 種類: すべて
- 適用先: このフォルダー、サブフォルダーおよびファイル
- 基本のアクセス許可: フルコントロール
- [ ] このコンテナー内のオブジェクトまたはコンテナ―のみにこれらの監査設定を適用する

## イベントID

- 4624 S - Logon ログオン成功
- 4625 - F Logon ログオン失敗
- 4634 S - Logoff ログオフ
- 4656 S F File System ハンドル開く
- 4658 S - File System ハンドル閉じる
- 4663 S - File System アクセス試行
- 4670 S - Authorization Policy Change ACL変更
- 5140 S F File Share 共有アクセス
- 5145 S F Detailed File Share 共有オブジェクトチェック

MSのドキュメントの間違い？(Windows Server 2022での検証結果)

- 「ハンドル操作」の監査を有効にしないと4656はでない。
- 4660(オブジェクト削除)はでないみたい。

## 準備

1. vCenterにログイン
2. 仮想マシンのハードウェアの「編集」を開く
3. 「新規デバイスを追加」で128GBのハードディスクを追加
4. サーバーにログイン
5. 「ディスクの管理」を開く
6. 新しく追加されたディスクをオンライン
7. 新しく追加されたディスクをGPTで初期化
8. 新しく追加されたディスクに新しいシンプルボリュームを作成
    * シンプル ボリューム サイズ: 最大値
    * [x] 次のドライブ文字を割り当てる: L
    * [x] このボリュームを次の設定でフォーマットする
        * ファイルシステム: ReFS
        * アロケーション ユニット サイズ: 規定値
        * ボリューム ラベル: LOG
        * [x] クリック フォーマットする
9.  「L:\Logs」を作成し、所有者を「SYSTEM」、セキュリティを下記に編集
    * NT SERVICE\EventLog:(OI)(CI)(F)
    * NT AUTHORITY\SYSTEM:(OI)(CI)(F)
    * BUILTIN\Administrators:(OI)(CI)(F)
    * NT AUTHORITY\Authenticated Users:(CI)(R)
11. 「イベント ビューア―」を開く
12. Windows ログ > セキュリティ のプロパティを開き、下記に変更し、「ログの消去」から「保存と消去」を選択して、現在のログを保存してから、「適用」を押す。
    * ログのパス: L:\Logs\Security.evtx
    * 最大ログ サイズ (KB): 131072 (128GiB)
    * イベント ログ サイズが最大値に達した時:
        * [x] イベントを上書きしないでログをアーカイブする

## Ruby

rubyinstaller without devkit
1. Select install mode: Install for all users
2. Ruby x.y.z-n-x64 License Agreement: I accept the License
3. Installation Destination and Optional Tasks: C:\Apps\Ruby
    * [x] Add Ruby executables to your PATH
    * [ ] Associate .rb and .rbw files with this Ruby installation
4. Select Components:
    * [x] Ruby-x.y.z base files
    * [ ] Ruby RI and HTML documentation
5. Completing the Ruby x.y.z-n-x64 Setup Wizard
    * [ ] Run 'ridk install' to setup MSYS2 and development toolchain.

## スケジュール

- 全般
    - 名前: log_manager
    - 説明: ログを保管する領域の状態確認と古いログの圧縮や削除を行う。
    - セキュリティ オプション
        - タスクの事項時に使うユーザー アカウント: (サーバー名)\ipcadmin,(サーバー名)/jimuadmin
        - ( ) ユーザーがログオンしているときのみ実行する
        - (x) ユーザーがログオンしているかどうかにかかわらず実行する
            - [ ] パスワードを保存しない
        - [ ] 最上位の特権で実行する
- トリガー: 毎日
    - 開始: 2023/12/07 4:30:00
    - 間隔: 1 日
- 操作: プログラムの開始
    - プログラム/スクリプト: C:\Apps\log_manager\bin\lmg.cmd
    - 引数の追加: -m check clean check

## テスト

失敗はlogoffの方に出る
