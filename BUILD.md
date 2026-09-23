# ファームウェアの再ビルド

通常の導入では [dist/SerialHidBridge.bin](dist/SerialHidBridge.bin) を使用できます。ソースから再ビルドする場合は Windows 用の [Arduino CLI](https://arduino.github.io/arduino-cli/) をインストールし、次を実行します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1
```

スクリプトは CH55xDuino `0.0.26` を導入し、CH552・内蔵 16 MHz・`user148` の設定でコンパイルします。Arduino CLI `1.5.1` と CH55xDuino `0.0.26` の組み合わせにはコンパイラのシェルスクリプトが BusyBox `ash` と合わない箇所があったため、スクリプトはその箇所をローカルで修正します。元のファイルは同じ場所の `.original` に保存されます。基板上のファームウェアはビルドだけでは変更されません。

生成先は `output/firmware/SerialHidBridge.bin` と `output/firmware/SerialHidBridge.ino.hex` です。公開済み `dist/` の内容は自動で置き換えません。書き込みには `python .\flash_when_ready.py .\output\firmware\SerialHidBridge.bin` を指定してください。

CH55xDuino 由来の HID ソースは `firmware/SerialHidBridge/src/userUsbHidKeyboardMouse/` に含めています。ライセンスは [LGPL-2.1](licenses/CH55xDuino-LGPL-2.1.txt) を参照してください。
