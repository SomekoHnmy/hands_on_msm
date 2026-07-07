# プロジェクト固有の AI エージェント用指示書 (AGENTS.md)

このファイルは、無料版の Gemini Flash などのエージェント型 AI アシスタントが、このリポジトリ内で迷わずに作業を行い、ユーザーからの「事前課題のコードを実行して」「Wordに変換して」といった要求に対して、コマンド不要で体験を提供するための指示書です。

## 1. このプロジェクトの前提知識 (Environment)
エージェントは、作業を開始する前に以下のローカル環境設定を自動的に探索・設定してください。

### Rscript の探索と実行ルール
- R の実行パスが通っていない場合、以下の標準的なインストールパスから `Rscript.exe` を探索し、コマンド実行時にその絶対パスを使用してください。
  - Windowsデフォルト: `C:\Program Files\R\R-4.4.2\bin\Rscript.exe` (または `R-4.4.*` バージョン)
- コマンド実行例:
  `& "C:\Program Files\R\R-4.4.2\bin\Rscript.exe" scripts/01_prework_generate_person_data.R`

### Pandoc (Quarto) の探索と実行ルール
- マークダウンを Word にビルドする際、以下の Pandoc パスを優先的に探索して使用してください。
  - Quartoデフォルト: `C:\Users\<UserName>\AppData\Local\Programs\Quarto\bin\tools\pandoc.exe`
- コマンド実行例:
  `& "C:\Users\<UserName>\AppData\Local\Programs\Quarto\bin\tools\pandoc.exe" input.md -o output.docx`

---

## 2. コマンドレス体験の提供ルール (Zero-Command Experience)
ユーザーが自分でターミナルにコマンドを打ち込む必要がないよう、エージェントは以下のルールを厳守してください。

1. **自動提案と実行**:
   ユーザーが「事前課題のコードを走らせて」や「〇〇をWordにして」と依頼した場合、エージェント側で必要なコマンド（環境パスを考慮した絶対パス形式）を組み立て、`run_command` ツール等を用いて**直接実行を提案**してください（ユーザーが承認ボタンを押すだけで実行されるようにします）。
2. **中間生成物のクリーンアップ**:
   スクリプト実行時の一時ファイルや中間結果は自動的に `temp/` フォルダ以下に保存されるよう、コード引数を制御してください。
3. **対話型進行**:
   実行完了後、結果の要約やグラフの出力先（`illustrations/` など）へのリンクをチャット上で提示し、次のステップ（例: 「次は03_msmを実行しますか？」など）を選択肢として提示してください。

---

## 3. ユーザーからの代表的な依頼テンプレート (How to Request)
ユーザーはエージェントに対し、以下のようにチャットで指示するだけで、環境構築から実行まで自動で行わせることができます。

* **「事前課題のコードを走らせて」**
  - **エージェントの行動**: `Rscript.exe` を使って `scripts/01_prework_generate_person_data.R` と `scripts/02_prework_pooled_logistic_regression.R` を順番に実行し、出力されたリスク差の結果を要約して提示します。
* **「MSMの点推定を実行して」**
  - **エージェントの行動**: `scripts/03_msm_load_data.R` 〜 `scripts/07_msm_point_estimate.R` を一連のタスクとして順次実行、または `07_msm_point_estimate.R` を直接走らせて推定結果と真値の比較を出力します。
* **「ガイドをWordにして」**
  - **エージェントの解説・変換**: `pandoc.exe` のパスを自動特定し、`course_guide.md` を `course_guide.docx` にビルドしてユーザーに通知します。

---

## 4. トラブルシューティング
- **Rパッケージ（cobalt, sandwich, gfoRmula）がインストールされていない場合**:
  - `run_command` を使用して `install.packages(c("cobalt", "sandwich", "gfoRmula"), repos="https://cloud.r-project.org")` を実行することを提案してください。
- **ファイルアクセス権限エラー**:
  - Windows 環境での実行時、パスにスペースが含まれる場合は必ずダブルクォーテーションで囲むか、PowerShell の呼び出し演算子 `&` を用いてください。
