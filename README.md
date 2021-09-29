# dart_get_waveform

[ippee/get_waveform](https://github.com/ippee/get_waveform) を Dart 言語で書き直す。

Python と異なる点として、コマンドからの標準出力の扱いが異なるというものがある。  
Python では ffmpeg で読み込んだファイルを wav 形式に変換し、その内容をそのまま標準出力することでバイナリを取得していた。  
しかし、Dart では標準出力の形式が String 型であるため、文字に変換できないコードは無視されるという問題が存在する。  
なので、ffmpeg によって変換されたファイルを一度書き出し、そのファイルをバイナリとして読み込むことで上記の問題を回避した。
