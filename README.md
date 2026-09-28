# CH552-SERIAL HID Bridge

[CH552-SERIAL](https://booth.pm/ja/items/4326008) を、シリアル通信で操作できる USB キーボード・マウスにするファームウェアと Windows 用コマンドです。Codex などのエージェントが、通常の Computer Use では操作できない Windows の UAC 確認画面に、外部 USB キーボードとして入力する用途を想定しています。

**現在の UAC 承認手順はキーボード操作です。** UAC が背面で待機している場合は、タスクバーの盾アイコンにフォーカスを合わせて `Enter` で前面に出し、`←` → `Enter` で「はい」を選びます。2026-09-29 に、この Windows 11 PC で背面待機からの一連の操作を 2 回実施し、起動したテストプロセスが管理者権限（High Mandatory Level、`S-1-16-12288`）になったことを確認しました。画像取得やマウスクリックは使っていません。

この方法は、エージェント自身が直前に起動した、ユーザーが承認を指示した処理に使います。Windows API で UAC の待機状態と入力先デスクトップを調べ、起動前後の状態を照合します。既に表示されている不明な UAC の内容を、画面なしで読み取る機能ではありません。

## 接続と必要なもの

接続は 1 台の Windows PC 内で完結します。USB-C 側の CH340 がシリアル通信を受信し、基板内の UART を経由して USB-A 側の CH552 が同じ PC にキーボード・マウス入力を送ります。基板の USB-A と USB-C の両方を接続してください。

- CH552-SERIAL 基板と USB-A / USB-C の接続。両方を操作対象 PC に接続します。
- Windows と Windows PowerShell。動作確認は Windows 11 で実施しました。
- 上記のキーボードによる UAC 操作には、キャプチャボードも FFmpeg も不要です。別途画面を確認する場合にだけ使います。映像取得テストでは Cam Link 4K を使用しました。
- ファームウェア書き込み時のみ、Python 3、`pyusb`、`libusb`、[Zadig](https://zadig.akeo.ie/) が必要です。

## 導入

1. 基板から USB-A と USB-C を両方抜き、10 秒待ちます。基板のスイッチを押したまま USB-A **だけ**を接続し、スイッチを離します。ブートローダーの USB ID は `4348:55E0` です。
2. USB-C は抜いたまま、Zadig で **`4348:55E0` にだけ WinUSB** を割り当てます。USB-C 側の CH340（`1A86:7523`）は書き込み対象ではありません。
3. Python の依存を入れ、同梱のファームウェアを書き込みます。

```powershell
python -m pip install pyusb libusb
python .\flash_when_ready.py
```

`flash_when_ready.py` は `4348:55E0` を最大 2 分待ち、[dist/SerialHidBridge.bin](dist/SerialHidBridge.bin) を書き込んで照合します。成功後、デバイスマネージャーで USB キーボードとマウスが増えたら USB-C を接続します。まだ USB ハードウェア ID `4348:55E0` が表示される場合は、USB-A を一度抜き、スイッチを押さずに挿し直してから USB-C を接続してください。書き込みには [chprog](https://github.com/wagiminator/MCU-Flash-Tools) を同梱しています。

## 操作

デバイスマネージャーで CH340 の COM 番号を調べてください。以下は実機で使った `COM5` の例です。

Codex から使う場合は、このリポジトリを作業場所として開き、[AGENTS.md](AGENTS.md) の手順でコマンドを実行します。これは通常の Computer Use 操作に加えて使うシリアル HID 経路です。COM 番号は、その PC に合わせて指定します。

### 基本の入力コマンド

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action ping -Port COM5
powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action combo -Keys WIN+R -Port COM5
powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action text -Text 'abc 123' -Port COM5
powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action move -X 100 -Y 50 -Port COM5
powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action click -Button left -Port COM5
powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action key -Key ESC -Port COM5
powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action release -Port COM5
```

`key`、`keydown`、`keyup`、`combo`、`text`、`move`、`click`、`mousedown`、`mouseup`、`scroll`、`release` に対応します。`text` は英字・数字・空白・改行向けです。その他のキーは `-Key` に HID Usage ID を 16 進数で指定できます（例: `-Key 0x2B` は Tab）。マウス移動は相対値で、Windows のポインター加速により画面上の移動量が変わります。

入力を止めるには `release` を送るか、CH552 の USB-A を抜きます。ファームウェアも 5 秒間コマンドがなければ保持中のキーとボタンを離します。

### UAC をキーボードで承認する

この PC の管理者アカウント向け UAC では、最初に「いいえ」にフォーカスがあり、「はい」はその左にありました。`uac-yes` は `LEFT` と `ENTER` を同じシリアル接続で続けて送ります。起動前に UAC がないことを確認し、対象を明示して管理者起動を要求したうえで、その要求の UAC が前面にあると確認できた場合に使います。

`uac-yes` は UAC が前面にある状態で使います。タスクバーの盾アイコンで待機している場合は、後述の補助コマンドで前面に出してから承認します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action uac-yes -Port COM5
```

実機では `uac-yes` による承認後、起動した処理が High Mandatory Level（`S-1-16-12288`）になったことを確認しました。シリアルの `OK` や UAC が閉じたことだけでは成功とせず、対象プロセスや処理結果まで確認してください。「はい」が最初から選ばれている場合や選択状態が不明な場合は、この固定キー列を使わず、画面確認またはユーザー操作に切り替えます。標準ユーザーの資格情報入力型 UAC は未検証です。

### 背面の UAC をスクリーンショットなしで前面に出す

自分が直前に起動した、承認対象が明確な UAC に限って使います。起動前に UAC がなかったことを確認してください。`Get-UacState.ps1` は現在の入力先デスクトップ、および同一ログインセッションの `consent.exe` を調べます。通常デスクトップ（`inputDesktop: "Default"`）に、名前を読み取れる UAC が 1 件だけ待機している場合、次のコマンドで UI Automation（UIA）によりタスクバーのボタンにフォーカスを合わせ、CH552 の Enter で開きます。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Get-UacState.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Bring-PendingUacToFront.ps1 -Port COM5
```

前面化コマンドは「はい」を押しません。同じ UAC の PID がセキュアデスクトップへ移ったことを確認して成功を返します。対象が不明、複数の候補がある、フォーカスを確認できない場合は停止します。状態取得だけでは UAC 内のアプリ名・発行元・ボタン選択状態を読めないため、既に出ていた不明な UAC の承認には使わないでください。

2026-09-29 に、この PC で背面に待機する Windows PowerShell の UAC を再現し、盾アイコンの前面化、`LEFT` → `ENTER` による承認、起動したテストプロセスの High Mandatory Level を確認しました。画像取得は使っていません。ほかの Windows 環境や UAC 表示形式では未検証です。

### 必要な場合だけ画面を取得する

UAC の対象やボタンの選択状態が不明な場合は、キャプチャボードで画面を確認する方法もあります。PC の映像出力をキャプチャボードに入力し、そのキャプチャボードも PC に接続します。FFmpeg が使える状態で、DirectShow のデバイス名を指定してください。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\control.ps1 -Action capture -CaptureDevice 'Cam Link 4K' -Output .\capture.png
```

![以前の映像取得テストでキャプチャした Windows の UAC 画面](assets/uac-yes-hover.png)

*以前の映像取得テストの参考画像です。ポインターは「はい」の上にありますが、現在の実機検証ではキーボードで承認しています。*

### ping は成功するのにキーが届かない場合

`ping` はシリアル通信の確認です。USB-A 側から Windows にキーが届いているかは、次のテストで確認します。小さなテスト画面が開き、その画面にだけ `F24` キーを送ります。テスト中は手元のキーボードを触らず、テスト画面を前面に置いてください。

```powershell
powershell -NoProfile -STA -ExecutionPolicy Bypass -File .\scripts\Test-HidKeyboard.ps1 -Port COM5
```

`passed: true` は Windows がキーの押下と解放を受け取ったことを表します。テスト画面は自動で閉じます。UAC の操作結果は別途、対象プロセスの昇格を確認してください。

`status 3` が出る場合は、USB-A の接続が未完了か、基板の HID 送信が停止している可能性があります。旧ファームウェアには USB バスリセット後に送信待ちフラグが残る不具合があり、現在の [dist/SerialHidBridge.bin](dist/SerialHidBridge.bin) には修正を含めています。「導入」の手順で書き込み直し、上記テストで確認してください。COM ポート自体が見つからない場合は USB-C の接続と CH340 の COM 番号を確認します。

2026-09-28 に、この PC で修正版の書き込み・照合と `A` キーの押下・解放を確認しました。基板だけを Windows の PnP 機能で再起動した後にも、`Test-HidKeyboard.ps1` で `F24` の押下・解放を受信し、`passed: true` になりました。UAC は `LEFT` → `ENTER` で承認し、テストプロセスが High Mandatory Level で実行されたことを確認しました。この確認は PC 全体の再起動やスリープ復帰の検証ではありません。

### Jev に通常画面のボタンを選ばせる（試作）

`jev_hid.py` は Windows UI Automation から前面ウィンドウの有効なボタンを読み、TypeSafe Jev に目的に合うボタンを選ばせ、CH552 のマウス入力でクリックします。UAC の保護された画面には使えません。前面ウィンドウ名とボタン名が設定済みの Jev プロバイダーに送信されるため、画面内容が適切な場合に使用してください。

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-jev.txt
.\.venv\Scripts\python.exe .\jev_hid.py --goal 'Close the Run dialog without launching anything'
.\.venv\Scripts\python.exe .\jev_hid.py --goal 'Close the Run dialog without launching anything' --execute
```

Jev 実行時は `--execute` を省くと予測のみ、付けるとクリックします。この PC では「ファイル名を指定して実行」の「キャンセル」を Jev が選び、CH552 がクリックしてダイアログを閉じることを確認しました。用途は名前の付いた通常のボタンに限られ、テキスト入力や複雑な画面操作は未実装です。

## 構成と検証範囲

- `firmware/SerialHidBridge/`: CH552 用ファームウェア。CH55xDuino の HID キーボード・マウス例を基にしています。UART0 と UART1 の両方を 9600 bps、8N1 で受け付けます。
- `control.ps1`: CH340 にコマンドを送る Windows PowerShell スクリプト。シリアルポートを開き直すたびに接続を確認します。
- `scripts/Get-UacState.ps1`: 入力先デスクトップと、同一ログインセッションで待機中の UAC を取得。
- `scripts/Bring-PendingUacToFront.ps1`: 背面待機の UAC を特定し、UI Automation によるタスクバーへのフォーカスと CH552 の Enter で前面化。
- `scripts/Test-HidKeyboard.ps1`: テスト画面で `F24` の押下・解放を受け取り、USB キーボード入力を検証。
- `flash_when_ready.py`: ブートローダー待機、書き込み、照合。
- `dist/`: このPCで書き込みと照合に成功したファームウェア。再ビルド方法は [BUILD.md](BUILD.md) を参照してください。

最新の UAC 検証は、Windows 11 の管理者アカウント向け承認画面で行いました。前面 UAC のキーボード承認と、背面 UAC の盾アイコン前面化・キーボード承認を確認済みです。対象プロセスの管理者権限、High Mandatory Level、承認後に UAC が残っていないことまで確認しています。

通常画面でのマウス入力と Jev のボタン選択は、別の補助機能です。最新の UAC 検証には使っていません。他の PC・Windows 環境・キーボード配列、資格情報入力型 UAC、PC 全体の再起動やスリープ復帰は未検証です。

## ライセンスと開発支援

本リポジトリのコードは LGPL-2.1 に従います。CH55xDuino 由来の HID コードは [そのライセンス](licenses/CH55xDuino-LGPL-2.1.txt)、同梱の `third_party/chprog.py` は [MIT ライセンス](third_party/chprog-LICENSE.txt) です。

初期の実装・検証には Codex の **GPT-6 Sol（Medium／中）**、2026-09-28〜29 の不具合修正とキーボード・UAC の実機検証には **GPT-6 Astra（High／高）**、公開文面の校正には **Gemini 3.8 Flash（High）** を使用しました。最新の UAC 検証結果は、Windows API による状態取得、シリアル応答、起動したテストプロセスの権限確認に基づいています。
