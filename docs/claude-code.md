# Claude Code で「管理者として実行」を使う

[スキル雛形](../skills/run-as-administrator/SKILL.md)を用意しています。既存の `control.ps1` と `scripts/` を共用するので、Codex の個人設定への依存はありません。Windows のローカルシェルと接続機器へアクセスできる Claude Code を想定しています。

Claude Code の[公式スキル仕様](https://code.claude.com/docs/en/skills)に従い、個人用は `~/.claude/skills/run-as-administrator/SKILL.md`、このプロジェクトだけで使う場合は `.claude/skills/run-as-administrator/SKILL.md` に配置します。Windows ネイティブ実行では、個人用の `~` は通常ユーザープロファイルです。

内部名・呼び出しは `run-as-administrator` / `/run-as-administrator`、本文の名前は「管理者として実行」です。雛形の `C:\Codex\usb_control` と `COM5` を実際の環境に合わせて置き換えてください。リポジトリのスクリプトを参照するため、導入後もその場所にリポジトリを保持します。

## Claude Code へのコピペ用指示文

使用したいモデルを Claude Code 側で選び、以下を貼り付けてください。スキルはモデル名を固定しません。以下のパスと COM 番号は動作確認環境の例です。

```text
この Windows PC の Claude Code に、個人スキル「管理者として実行」を導入してください。

リポジトリ: https://github.com/hinatamaxxx/codex-ch552-serial-hid
既存の作業場所: C:\Codex\usb_control
接続ポートの例: COM5

既存の作業場所があれば変更を保持して利用してください。なければ上記リポジトリを取得してください。README.md と skills/run-as-administrator/SKILL.md を読み、雛形を ~/.claude/skills/run-as-administrator/SKILL.md に配置してください。同名スキルが既にあれば内容を確認し、既存の設定を保持して統合してください。

実際のリポジトリの絶対パスと接続 COM ポートを確認し、スキル内の例を置き換えてください。Codex の個人スキルフォルダーには依存させず、このリポジトリの control.ps1 と scripts/ を参照してください。

このスキルは、私が依頼した処理について、あなた自身が直前に起動した UAC をキーボードで承認するためのものです。スクリーンショットを常用せず、Get-UacState.ps1 で起動前後の状態を確認してください。背面待機なら Bring-PendingUacToFront.ps1 で盾アイコンを前面化し、同じ consent PID を確認してから uac-yes（←・Enter）を一度送ります。対象プロセスの権限まで確認して完了としてください。

シェルコマンドはシェル実行ツールから Windows PowerShell へ渡し、GUI のターミナルや「ファイル名を指定して実行」にはタイプしないでください。Claude Code の実行許可やサンドボックス設定は変更しないでください。不明な UAC、複数候補、入力エラーでは停止してください。

今回は導入とファイル参照・ポート・ping の確認まで行ってください。HID のキー入力や UAC 承認の実機テストはまだ開始せず、導入先と /run-as-administrator の使い方を報告してください。
```

導入後は、たとえば `/run-as-administrator 管理者権限の確認だけを行うテストを実施して` のように、実行する処理を明示して依頼します。

## 検証状況

既存スクリプトによるキーボード入力と UAC 承認は Codex から実機検証済みです。Claude Code でのスキル読み込み・自動選択・UAC 実行は未検証です。スキルの配置は Claude Code 自体のツール権限を変更しません。クラウド環境や WSL からの機器アクセスも、この導入例では検証していません。
