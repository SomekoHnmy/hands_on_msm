# プロジェクト固有の AI エージェント用指示書 (AGENTS.md)

このファイルは、エージェント型 AI アシスタント（Claude Code、Gemini CLI、GitHub Copilot など）が、このリポジトリ内で迷わずに作業を行うための指示書です。ユーザー（ハンズオン参加者）が「環境構築して」「事前課題のコードを実行して」「Word に変換して」とチャットで依頼するだけで、自分でコマンドを打たずに体験できるようにしてください。

## 0. 大前提

- ユーザーの OS は **Windows または macOS** のどちらかです。作業を始める前に、まず OS を判定してください。
- ユーザーは **R・Quarto・git をインストールしていない可能性があります**。「入っていない」ことをエラーではなく通常のケースとして扱い、インストールの提案から始めてください。
- **参加者に必須なのは R だけ**です。Quarto（pandoc）が必要になるのは Word（docx）変換を頼まれたときだけで、これは通常講師側の作業です。
- コマンドはユーザーに打たせず、エージェント側で組み立てて**実行を提案**してください（ユーザーは承認ボタンを押すだけ）。

## 1. 環境の探索とセットアップ (Environment)

### 1-1. Rscript の探索

以下の順で Rscript を探し、見つかった絶対パスを以後のコマンドで使ってください。

1. PATH 上の `Rscript`（`Rscript --version` で確認）
2. OS 別の標準インストールパス:
   - **Windows**: `C:\Program Files\R\R-4.*\bin\Rscript.exe`（バージョン部分はワイルドカードで探索し、複数あれば最新版を使う）
   - **macOS**: `/opt/homebrew/bin/Rscript`、`/usr/local/bin/Rscript`、`/Library/Frameworks/R.framework/Resources/bin/Rscript`

### 1-2. R が見つからない場合（インストールの提案）

ユーザーに一言確認したうえで、以下を提案・実行してください。

- **Windows**: `winget install --id RProject.R -e`
  - インストール後、PATH が反映されないことがあるため、新しいターミナルを開くか 1-1 の標準パスを直接探索する。
- **macOS**:
  - Homebrew があれば: `brew install --cask r`
  - なければ CRAN（https://cran.r-project.org/bin/macosx/）から `.pkg` をダウンロードして開くよう案内する。**Apple Silicon は arm64 版、Intel Mac は x86_64 版**を選ぶこと（`uname -m` で判定できる。`arm64` なら Apple Silicon）。

### 1-3. スクリプトの実行

- 実行は原則**リポジトリのルート**で行ってください（スクリプトはルート／`scripts/` どちらからでも動くよう相対パスを自動判定しますが、ルートが基本です）。
- 実行例:
  - **Windows (PowerShell)**: `& "C:\Program Files\R\R-4.4.2\bin\Rscript.exe" scripts/01_prework_generate_person_data.R`
  - **macOS (zsh/bash)**: `Rscript scripts/01_prework_generate_person_data.R`

### 1-4. R パッケージ

- 本番スクリプト（03・09）は必要パッケージを自動インストールしますが、当日の回線トラブルを避けるため、環境構築の段階で以下をまとめて入れておくことを推奨します:

  ```r
  install.packages(c("ggplot2", "cobalt", "sandwich", "gfoRmula", "data.table"),
                   repos = "https://cloud.r-project.org")
  ```

### 1-5. Pandoc の探索（Word 変換を頼まれたときだけ）

以下の順で探索してください。

1. PATH 上の `pandoc`
2. `quarto pandoc`（Quarto がインストール済みの場合、この形で pandoc を呼べる）
3. OS 別の標準パス:
   - **Windows**: `C:\Users\<UserName>\AppData\Local\Programs\Quarto\bin\tools\pandoc.exe`
   - **macOS**: `/Applications/quarto/bin/tools/` 配下の `pandoc`
4. どれも無ければ pandoc 単体のインストールを提案する（Windows: `winget install --id JohnMacFarlane.Pandoc -e` ／ macOS: `brew install pandoc`）。

- 変換例: `pandoc course_guide.md -o course_guide.docx`

## 2. コマンドレス体験の提供ルール (Zero-Command Experience)

1. **自動提案と実行**:
   ユーザーの依頼に対し、エージェント側で必要なコマンド（環境パスを考慮した絶対パス形式）を組み立て、直接実行を提案してください（ユーザーが承認するだけで実行される状態にします）。
2. **中間生成物のクリーンアップ**:
   スクリプト実行時の一時ファイルや中間結果は `temp/` フォルダ以下に保存されるよう制御してください。
3. **対話型進行**:
   実行完了後、結果の要約や出力先（`illustrations/` など）へのリンクをチャット上で提示し、次のステップ（例:「次は 03_msm を実行しますか？」）を選択肢として提示してください。

## 3. ユーザーからの代表的な依頼テンプレート (How to Request)

* **「環境構築して」／「準備をお願い」**
  - **エージェントの行動**: OS を判定 → Rscript を探索（§1-1）→ 無ければインストールを提案（§1-2）→ パッケージを一括インストール（§1-4）→ 動作確認として `scripts/01_prework_generate_person_data.R` を実行し、`data/person_interval.csv` が生成されたことを確認して報告します。
* **「事前課題のコードを走らせて」**
  - **エージェントの行動**: `scripts/01_prework_generate_person_data.R` と `scripts/02_prework_pooled_logistic_regression.R` を順番に実行し、出力されたリスク差の結果を要約して提示します。
* **「MSM の点推定を実行して」**
  - **エージェントの行動**: `scripts/03_msm_load_data.R` 〜 `scripts/07_msm_point_estimate.R` を一連のタスクとして順次実行、または `07_msm_point_estimate.R` を直接走らせて推定結果と真値の比較を出力します。
* **「ガイドを Word にして」**
  - **エージェントの行動**: pandoc を探索（§1-5）し、`course_guide.md` を `course_guide.docx` にビルドして通知します。

## 4. トラブルシューティング

- **R パッケージ（cobalt, sandwich, gfoRmula 等）が入っていない**:
  - §1-4 の `install.packages(...)` の実行を提案してください。
- **macOS でパッケージのビルドに失敗する**:
  - コンパイル不要のバイナリ版を使ってください: `install.packages(..., type = "binary")`
- **「data/raw_tables ディレクトリが見つかりません」エラー**:
  - ワーキングディレクトリがリポジトリ外です。リポジトリのルートに移動して再実行してください。
- **Windows でパスにスペースが含まれてエラーになる**:
  - パスをダブルクォーテーションで囲み、PowerShell の呼び出し演算子 `&` を使ってください。
- **winget / brew 自体が使えない**:
  - CRAN（Windows: https://cran.r-project.org/bin/windows/base/ ／ macOS: https://cran.r-project.org/bin/macosx/）のインストーラを案内し、GUI でのインストールをユーザーに依頼してください。
