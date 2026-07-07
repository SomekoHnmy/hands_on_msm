# MSM・g-formula ハンズオン

時間依存交絡（time-varying confounding）を扱う2つの標準手法 —— **MSM（周辺構造モデル）** と **parametric g-formula** —— を、シミュレーションデータで手を動かしながら学ぶハンズオン教材です。題材は「メトホルミンを増量する／据え置く」という時間依存の治療判断が心血管イベントに与える因果効果。疫学を一通り学んだ方が「名前は知っているが中身が分からない」を卒業することを目指します。

## 必要なもの

| もの | 必要？ |
|---|---|
| PC（Windows または Mac） | 必要 |
| AI コーディングエージェント（Claude Code / Gemini CLI / GitHub Copilot など、どれか1つ） | 推奨（下記参照） |
| R | **手動インストール不要** —— エージェントが探索・インストール・実行まで代行します |
| Quarto / pandoc | **不要**（Word 変換は講師側の作業です） |
| git の知識 | 不要（ZIP ダウンロードで OK） |

このリポジトリは、参加者が自分でターミナルにコマンドを打たなくても済むよう、AI エージェントへの指示書 [AGENTS.md](AGENTS.md) を同梱しています。R のインストールからスクリプト実行まで、エージェントとのチャットだけで完結します。

## 参加者の進み方

### Step 1. 事前読み物を読む（環境不要）

[prework_introduction.md](prework_introduction.md) を読んでください。ブラウザで読むだけで OK、数式もコードも出てきません。「そもそも因果推論とは何か」から、当日扱う MSM・g-formula が「なぜ必要か」までを、一人の患者をめぐる物語で追います。

### Step 2. リポジトリを手元に用意する

git を知らなくても大丈夫です。このページ上部の緑色の **Code** ボタン → **Download ZIP** でダウンロードし、好きな場所に展開してください（git が使える方は clone でも構いません）。

### Step 3. AI エージェントを用意する

以下のいずれか1つを使える状態にしてください（すでに使っているものがあればそれで OK）。

- [Claude Code](https://claude.com/claude-code)（CLI / VS Code 拡張）
- [Gemini CLI](https://github.com/google-gemini/gemini-cli)（無料枠あり）
- GitHub Copilot（VS Code のエージェントモード）
- その他、リポジトリ内の `AGENTS.md` を読んでコマンドを実行できるエージェントなら何でも可

### Step 4. エージェントに話しかける

展開したフォルダをエージェントで開き、チャットにこう入力します。

> **「AGENTS.md を読んで、環境構築から事前課題の実行までお願いします」**

エージェントが OS を判定し、R がなければインストールを提案し、必要パッケージを入れ、事前課題スクリプト（`scripts/01`・`02`）を実行して結果を要約してくれます。実行の各ステップで承認ボタンを押すだけです。

**準備完了の目安**：`data/person_interval.csv` が生成され、naive 解析のリスク差（−0.110 / −0.094）が表示されれば成功です。

### Step 5. 当日

[course_guide.md](course_guide.md) に沿って `scripts/03` 〜 `10` を順に実行します。「MSM の点推定を実行して」のようにエージェントに頼むだけで進められます。

## エージェントを使わない場合

R と RStudio を自分でインストールして進めることもできます。手順は [SETUP.md](SETUP.md) を参照してください。

## リポジトリ構成

| パス | 内容 |
|---|---|
| `prework_introduction.md` | 事前読み物（環境不要・コードなし） |
| `course_guide.md` | 当日の解説・進行ガイド（講師用台本 兼 参加者用読み物） |
| `AGENTS.md` | AI エージェント用の指示書（環境構築・実行の自動化） |
| `SETUP.md` | 手動セットアップ手順（エージェントを使わない方向け） |
| `scripts/01`〜`02` | 事前課題：生データの畳み込みと naive 解析 |
| `scripts/03`〜`08` | 本番①：MSM（IP weighting） |
| `scripts/09` | 本番②：parametric g-formula |
| `scripts/10` | 発展：時間依存交絡3個版 |
| `data/` | 配布データ（生データ4テーブル・真値） |
| `illustrations/` | 読み物用の挿絵 |

## 講師向けメモ

- `course_guide.md` が進行台本を兼ねます（目安時間つき）。
- Word 版が必要な場合のみ pandoc（Quarto 同梱のものでも可）で変換します：`pandoc course_guide.md -o course_guide.docx`
- `scripts/generate_data (not for participant use).R` はデータ生成用で、参加者には配布・案内しません。
