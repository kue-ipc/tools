# VSS スケジューラー

Windowsのボリュームシャドーコピーに対して月/週/日/時単位での世代管理を行う。

## 動作環境

- Windows 10/11, Windows Server 2016/2019/2022
- Ruby 3.2 以上 (RubyInstaller for Windows推奨)

## 準備

1. Rubyをインストールする。
    1. [RubyInstaller for Windows](https://rubyinstaller.org/)からインストーラーをダウロードする。
    2. インストーラーを実行する。
        - オプション選択で"Add Ruby executables to your PATH"にチェックを入れる。
    3. ターミナル、または、Windows PowerShell上で`ruby -v`を実行し、Rubyがインストールされていることを確認する。
2. 対象のドライブについてシャドウコピーを有効にする。
    1. 対象ドライブ右クリックする。
    2. プロパティを開く。
    3. シャドウ コピーのタブを開く。
    4. シャドー コピーを有効にし、下記のように設定する。
        1. 最大サイズ: 制限なし
        2. スケジュール: 取得したいタイミングを設定

## 登録

1. フォルダー毎サーバーに設置する。
2. sched_vss.yml.sapmle を参考に sched_vss.yml を作成する。
3. タスクスケジューラーで sched_vss.cmd を毎日一回実行する。ただし、シャドウコピーのスケジュールとは時間をずらす。
