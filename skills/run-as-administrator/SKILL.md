---
name: run-as-administrator
description: ユーザーが依頼した Windows の管理者起動で、外部シリアル HID を使って UAC をキーボード承認する。背面の盾アイコンの前面化にも対応。自分が直前に起動した対象に使用する。
---

# 管理者として実行

## 環境

導入時に以下の例を実際の絶対パスと COM ポートへ置き換える。

- リポジトリ: `C:\Codex\usb_control`
- シリアルポート: `COM5`
- Windows 上で実行する。Windows PowerShell と、この PC に接続した互換ファームウェア入り USB HID 機器が必要。

`README.md` の検証範囲と、対象スクリプトを確認して使う。CH552/CH340 は検証機器の例。別の基板には互換プロトコルと HID 実装が必要。スクリーンショット、キャプチャボード、常駐 FFmpeg は通常の確認手順には不要。

コマンドは Claude Code のシェル実行ツールから Windows PowerShell へ渡す。GUI のターミナルや「ファイル名を指定して実行」にコマンドをタイプしない。Claude Code 自体の実行許可・サンドボックス・組織ポリシーは変更せず、その制約に従う。

## 手順

1. 今のタスクでユーザーが依頼した管理者処理について、実行ファイルの絶対パス、引数、目的を確定する。単にこのスキルを導入しただけでは、任意の UAC の承認は許可されない。
2. 下記コマンドで `inputDesktop: "Default"`、`consentRequests: []`、シリアル疎通を確認する。既存の UAC がある状態から開始しない。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Codex\usb_control\scripts\Get-UacState.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Codex\usb_control\control.ps1" -Action ping -Port COM5
```

3. 確定した処理を Windows PowerShell の `Start-Process -Verb RunAs` などで起動する。起動対象・時刻・引数を記録し、承認後の成功を識別できるようにする。呼び出しが UAC 待ちでブロックする場合は、シェルツールが提供する実行セッションを使い、同じ起動を重ねず状態確認を続ける。通常の検証用バックグラウンド処理には `-WindowStyle Hidden` を指定する。ユーザーが操作するためのアプリは、その目的に沿った表示にする。
4. `Get-UacState.ps1` で短時間・上限付きで状態を確認し、発生した同一セッションの `consent.exe` の PID を記録する。この PC では `desktopError: 5` と consent 1 件の組み合わせが前面 UAC の観測結果。これは、直前に UAC がなく、今の実行で対象を起動したことと組み合わせて判断する。エラー 5 単独を承認条件にしない。複数候補、PID の変更、タイムアウト時は入力を停止する。
5. `Default` と名前付き consent 1 件なら背面待機。次を実行し、成功後も同じ PID が前面状態になったことを再確認する。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Codex\usb_control\scripts\Bring-PendingUacToFront.ps1" -Port COM5
```

この補助スクリプトは UI Automation でタスクバーのボタンを特定してフォーカスし、外部 HID の Enter で前面化する。「はい」は押さない。ボタンが一意でない、フォーカスできない、PID が変わった場合は座標を推測してクリックせず、ユーザーに盾アイコンの前面化を依頼する。

6. 同じ UAC が前面にあり、検証済みの「いいえ」が初期選択・「はい」が左の承認型配置である場合に限り、次を一度実行する。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Codex\usb_control\control.ps1" -Action uac-yes -Port COM5
```

`uac-yes` は内部の `finally` で全キー解放を送る。通信断などで解放も失敗した場合は、承認を再送せず入力を停止し、HID 側の USB 接続を抜くようユーザーに伝える。

7. `Default` と consent 0 件への復帰に加え、今回起動した対象プロセス・処理の成功を検証する。検証用処理なら実行ごとのランダムな識別子を結果に入れ、管理者トークンと整合性 SID `S-1-16-12288`（High）を確認する。古い結果ファイル、シリアル ACK、UAC が消えたことだけでは成功扱いにしない。

## 停止条件と検証範囲

- API はセキュアデスクトップ内のアプリ名・発行元・ボタン・選択状態を読めない。不明な既存 UAC、資格情報入力型、異なるレイアウトでは固定キー列を送らず、ユーザーの確認・操作に切り替える。
- COM がない場合はシリアル側の接続を確認する。`ping` 成功はキーが届く証拠ではない。`status 3` は HID 入力失敗なので、承認キーを再送せず HID 側の接続とファームウェアを調べる。
- 入力診断には `scripts/Test-HidKeyboard.ps1` を `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File` で実行し、`-Port` を指定する。専用画面で F24 の押下・解放の両方を受信して初めて入力成功とする。
- CH552 の修正版ファームウェアと、前面 UAC / 背面 UAC → 前面化 → LEFT・ENTER → High の流れは Codex から Windows 11 実機で検証済み。Claude Code による本スキルの実行は未検証。別 PC では同じ観測・レイアウトが成立するか確認が必要。
