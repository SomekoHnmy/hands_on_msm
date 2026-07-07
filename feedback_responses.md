# フィードバックに対する対応状況レポート

`temp/feedback.txt` に記載された指摘事項（コメント1〜7、および初学者向け説明・軽微な問題）に対する具体的な修正・対応内容を、コメント番号ごとに整理してまとめました。

---

## 🛠️ ① ロジカルエラー・コードの正しさに関わる問題

### 1. 安定化重みの分子と最終MSMの整合が取れていない（理論上の誤り）
* **指摘内容**: 分子モデルに baseline 共変量（年齢・喫煙・高血圧・脂質異常症）が含まれている一方で、最終的な MSM に baseline 共変量が含まれておらず、理論的に交絡を打ち消しきれない。
* **対応内容**:
  * [04_msm_treatment_model.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/04_msm_treatment_model.R) の分子モデル `num` から baseline の4変数を外し、`metformin_high ~ metformin_high_prev + factor(month)` のみに定式化を修正しました。
  * 整合性を保つため、[08_msm_confidence_interval.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/08_msm_confidence_interval.R) の Bootstrap 推定関数 `msm_rd_once` 内の分子モデル `num` も同様に修正しました。
  * 発展パートの [10_advanced.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/10_advanced.R) (3交絡版) でも、分子モデル `num` から同様に baseline 変数を外して `A ~ Aprev + factor(month)` に修正しました。
  * 進行ガイド [course_guide.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/course_guide.md) の §4-2 において、「分子に入れた変数は最終モデルにも含める必要があるため、ここでは治療履歴のみにする」という整合性のための前提条件を明記しました。
  * この修正により、MSM の推定リスク差（RD）は従来の誤った `-0.223` から、正しい理論値に近い **`-0.271`** （真値: `-0.232`）へと修正されました（さらに性別 `sex` を baseline 共変量に加えた後の実測値となります）。

### 2. 自前クラスターロバストSEにIPW重みが掛かっていない（コードのバグ）
* **指摘内容**: [08_msm_confidence_interval.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/08_msm_confidence_interval.R) の簡易クラスターロバスト SE を求めるスコア計算 `ef <- X * u` に、重み付き GLM に必要な prior weights（IPWの重み）が掛けられていないため、SE が小さく評価されている。
* **対応内容**:
  * 簡易実装関数 `cluster_robust_se` 内のスコア定義を `ef <- X * (u * weights(model))` に修正しました。
  * 修正後、`sandwich::vcovCL(..., cadjust = FALSE)` (自由度調整なし) の結果と、簡易実装（`se_cluster_robust_simple`）が小数点第4位まで完全に一致（`(Intercept) = 0.1441`, `metformin_high = 0.1661`, `cumA = 0.0632`）することを確認しました。
  * コメントの誤り（「sandwich は小サンプル補正が入るため、わずかに値が異なる」と書いていた箇所）を、「自由度調整 (cadjust=TRUE) を行うと僅かに差が出るが、調整なし (raw) の場合は完全に一致する」という正確な解説内容へ更新しました。

### 3. 10_advanced.R の gfoRmula の参照介入が間違っている
* **指摘内容**: [10_advanced.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/10_advanced.R) の `gfoRmula::gformula` において `ref_int = 0` (自然経過) が指定されており、直前の MSM の比較（常に増量 vs 常に非増量）と整合していない。
* **対応内容**:
  * パッケージ `gfoRmula` では `1` が「常に非増量（1番目の介入）」を示すため、`ref_int = 1` に修正しました。
  * これにより、出力されるリスク差が「常に非増量」に対する「常に増量」の差（RD: **`-0.286`**, 95%CI `[-0.342, -0.225]`）となり、MSM 側の出力（RD: `-0.270`）と正しく比較できるようになりました。

### 4. Cox の参考出力がメッセージと食い違う
* **指摘内容**: [02_prework_pooled_logistic_regression.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/02_prework_pooled_logistic_regression.R) の Part 3 で「HbA1c を入れるか入れないかで推定値が動く」と書いてあるが、実際に出力されるハザード比（HR）は 0.656 vs 0.660 でほぼ同じになっておりメッセージと矛盾している。
* **対応内容**:
  * 参加者の混乱を防ぐため、本論とは外れる Cox ハザードモデルによる参考分析のコードおよび出力部分をスクリプトから完全に削除しました。

### 5. 真値・結果数値の版ずれ
* **指摘内容**: CSVに記録されている真値 `-0.2319`（表示上は `-0.232`）に対し、ガイドやコード中で `-0.233` とハードコードされている。また、MSM点推定の値も旧モデル式の `-0.225` のままになっている。
* **対応内容**:
  * スクリプト群（`02_prework`, `07_msm`, `09_gformula`）およびガイド [course_guide.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/course_guide.md) の中にある真値のハードコードをすべて **`-0.232`** に統一しました。
  * 分子モデル修正および性別 `sex` の baseline 追加後の最新の MSM 実測推定値（RD: **`-0.271`**, 95%CI `[-0.354, -0.168]`, 常に増量 ≈0.23 / 常に非増量 ≈0.51）に合わせて、ガイドおよび `09_gformula` 内の推定量比較テーブルの数値をすべて更新し、整合させました。
  * 発展（3交絡）の MSM 推定値も `-0.270`、真値も `-0.275` に修正しました。

### 6. 実行すると必ず出る警告への手当てがない
* **指摘内容**: IPW重みを使用する `binomial glm` で、重みが非整数のために出力される「non-integer #successes in a binomial glm!」警告に対して説明がない。
* **対応内容**:
  * 警告が発生する箇所（`07_msm`, `08_msm`, `10_advanced`）の `glm` 呼び出しの直前に、**「重みが非整数のためこの警告が必ず表示されますが、これは仕様通りの想定された挙動であり、計算結果に影響はないため無視して問題ありません」**というコメント注記を追加しました。

### 7. 細かいが挙動に関わる点
* **データ抽出前提の注記**: [01_prework_generate_person_data.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/01_prework_generate_person_data.R) にて「イベント月でログが止まっている」というデータ生成都合を利用した簡便なフラグ作成に対し、「実データでは日付を正確に突き合わせる必要がある」旨の実務用注記コメントを追加しました。
* **測定誤差の丸めバグ**: [generate_data (not for participant use).R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/generate_data%20%28not%20for%20participant%20use%29.R) の HbA1c 生成ロジックにおいて、L=0 のときに `7.5` に丸まってしまい `hba1c_high = 1` に誤分類されるバグを `pmin(7.4, ...)` で上限を設定することで解消しました。
* **手書き g-formula の時間項**: [09_gformula.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/09_gformula.R) の手書き g-formula のアウトカムモデル `out_model` （および bootstrap 内のモデル）にも **`+ factor(month)`** を追加し、モデル構成を統一させました。それに伴い `predict` 時に `month = k` を指定するように修正しました。
* **手書き g-formula の bootstrap 精度不足**: [09_gformula.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/09_gformula.R) の bootstrap 処理 `gf_rd_once` にて、モンテカルロ複製 `mc = 50` を行ってシミュレーション誤差を小さくするよう修正を施しました。

---

## 💡 ② 初学者視点で分かりづらい説明

### ガイドとファイル名の全面的な不一致の解消
* **対応内容**: [course_guide.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/course_guide.md) の中（§1の対応表や各見出し、本文の解説部分）で、旧ファイル名（`01_prework.R`, `02_msm.R` など）が参照されていた箇所を、すべて現在提供されている `01` 〜 `10` のファイル名へと全置換しました。

### ガイドの記述とコードの矛盾の修正
* **対応内容**:
  * [course_guide.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/course_guide.md) の「自前で計算します」と書かれていた箇所を「実務で定番のパッケージ（cobalt, sandwich）を使った方法と、仕組み理解のための自前計算（簡易ロバストSE等）の両方を実装して比較する」という実際の構成と一致する説明に変更しました。
  * 事前課題の true_values.csv の読み込み部分に対し、「この真値（`-0.232`）は、本編の『09_gformula.R』の Part 3（伏線の回収）にて、データ生成時の真のパラメータを用いた前向きシミュレーションを行うことで実際に導出し、伏線を回収します」という案内を追記し、教材全体のストーリー性が繋がるようにしました。

### 「breakthrough-stroke 論文」の明確化
* **対応内容**:
  * 参加者が「どの論文の話か」と迷わないよう、アスピリン既服用の脳卒中症例を対象とした「Breakthrough Stroke 研究（アスピリンコホートに対するMSM解析）」というユーザーご自身の臨床研究プロジェクトであることを説明する注記を [course_guide.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/course_guide.md) の §4-5 に追加しました。それに伴い、各所の「論文」という記述を「Breakthrough Stroke 研究」に置き換えました。

### pooled logistic regression の位置づけの整理
* **対応内容**:
  * [prework_introduction.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/prework_introduction.md) において、「時間依存交絡がある状態で直接回帰に放り込んで調整する pooled logistic は誤りだが、IPW 重みを掛けた上で pooled logistic を回すのが MSM である」という整理を明示し、手法自体と重み付け適用の役割の混同による混乱を解消しました。

### 平均値代入（連続値）に関する注記
* **対応内容**:
  * [02_prework_pooled_logistic_regression.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/02_prework_pooled_logistic_regression.R) の二値変数 `hba1c_high` に対して各月の平均値を代入している点について、周辺化リスクを簡便に近似計算するための設計上の割り切りであることを注記しました。

### positivity の日本語表現の書き直し
* **対応内容**:
  * [prework_introduction.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/prework_introduction.md) の L142-143 にあった不自然な日本語を、「臨床家がいずれの治療戦略（増量・据え置き）も選び得る（＝どの群にもある程度患者が存在する）状態」を解説する分かりやすい自然な日本語に修正しました。

### MSM や g-formula の適用場面の正確化
* **対応内容**:
  * [course_guide.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/course_guide.md) の L51 にあった「唯一の状況」という表現を、「MSM や g-formula が真価を発揮する**代表的な状況（治療-交絡のフィードバック）**」へと修正しました。

### ESS（有効サンプルサイズ）に関する説明の補足
* **対応内容**:
  * [05_msm_stabilized_weight.R](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/scripts/05_msm_stabilized_weight.R) にて「ESS が高い ＝ positivity 良好」と断定するのではなく、ESS は重みのばらつきを捉えるための間接的な positivity 診断の指標であることを補足しました。

### 軽微なスペルミス・タイポの修正
* **対応内容**:
  * `exchangability` を `exchangeability` に修正しました（[prework_introduction.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/prework_introduction.md)）。
  * `marginal structure model` を `marginal structural model` に修正しました（[prework_introduction.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/prework_introduction.md)）。

---

## 📝 書体・成果物ファイルの更新

### 「です・ます調」への語尾の統一
* [course_guide.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/course_guide.md) および [prework_introduction.md](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/prework_introduction.md) に残っていた常体（である調）をすべて丁寧な「です・ます調」へ統一し、講義資料として不揃いがない状態に整えました。

### Word ファイル（.docx）への再コンパイル
* 語尾の統一とフィードバック対応に伴い、Quarto の `pandoc.exe` を使用して、画像が正常に埋め込まれた状態の Word 成果物を再生成しました。
  * [course_guide.docx](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/course_guide.docx)
  * [prework_introduction.docx](file:///C:/Users/sangu/Documents/論文/hands_on_msm_gformula/prework_introduction.docx)
