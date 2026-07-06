# ==============================================================================
#  MSM・g-formula ハンズオン ／ 本番パート① : MSM（IP weighting）
# ------------------------------------------------------------------------------
#  ステップ1：治療（増量状態）の確率をモデル化する
#  ステップ2：治療モデルが収束したかを確認する
# ==============================================================================

# 前提となるデータの読み込み
if (file.exists("scripts/03_msm_load_data.R")) {
  source("scripts/03_msm_load_data.R")
} else if (file.exists("03_msm_load_data.R")) {
  source("03_msm_load_data.R")
} else {
  stop("03_msm_load_data.R が見つかりません。")
}

# ==============================================================================
#  ステップ1：治療（増量状態）の確率をモデル化する
# ------------------------------------------------------------------------------
#  安定化重みの分子・分母を作るための2つのモデル。
#    分母：交絡をすべて入れて治療状態を予測（時間依存交絡 hba1c_high と履歴も）
#    分子：baseline と治療履歴だけ（hba1c_high は入れない）＝重みを安定化する
# ==============================================================================
den <- glm(metformin_high ~ hba1c_high + hba1c_high_prev + metformin_high_prev +
             age_z + smoking + hypertension + dyslipidemia + factor(month),
           family = binomial, data = dat)
num <- glm(metformin_high ~ metformin_high_prev +
             age_z + smoking + hypertension + dyslipidemia + factor(month),
           family = binomial, data = dat)

# 予測確率は 0/1 に貼りつかないようクリップしておく
pd <- pmax(pmin(predict(den, type = "response"), 1 - 1e-8), 1e-8)
pn <- pmax(pmin(predict(num, type = "response"), 1 - 1e-8), 1e-8)
dat$f_den <- ifelse(dat$metformin_high == 1, pd, 1 - pd)
dat$f_num <- ifelse(dat$metformin_high == 1, pn, 1 - pn)

# ==============================================================================
#  ステップ2：治療モデルが収束したかを確認する
# ------------------------------------------------------------------------------
#  収束＝係数を求める反復計算が一つの答えに落ち着いたか。落ち着かない（未収束）
#  モデルから作った重みは信用できないので、重みを作る前にここで確認する。
# ==============================================================================
cat("=== ステップ2：治療モデルの収束 ===\n")
cat(sprintf("  分母モデル: %s / 分子モデル: %s\n\n",
            ifelse(den$converged, "収束", "未収束！"),
            ifelse(num$converged, "収束", "未収束！")))

# --- 追加：モデルの summary の出力 ---
cat("=== 分母モデル (den) の要約 (summary) ===\n")
print(summary(den))
cat("\n=== 分子モデル (num) の要約 (summary) ===\n")
print(summary(num))


# ==============================================================================
#  ステップ2 補足：傾向スコアの群別密度プロットとバランス確認
# ------------------------------------------------------------------------------
#  実務では ggplot2 で傾向スコアの overlap を確認し、
#  cobalt::bal.tab / love.plot で共変量バランスを視覚的に確認します。(cobaltを使うのは次のステップ)
#  ※ パッケージは 03_msm_load_data.R でインストール・ロード済み
# ==============================================================================

# 分母モデルの予測確率（傾向スコア）を付与
dat$ps <- predict(den, type = "response")

# --- 傾向スコアの overlap plot（各月）---
cat("=== ステップ2 補足：ggplot2 による傾向スコアの overlap plot ===\n")
for (m in 1:n_int) {
  dm <- dat[dat$month == m, ]
  if (length(unique(dm$metformin_high)) < 2) next

  p <- ggplot(dm, aes(x = ps, fill = factor(metformin_high,
    labels = c("非増量(0)", "増量(1)")
  ))) +
    geom_density(alpha = 0.4) +
    theme_minimal() +
    labs(
      title = sprintf("月%d: 傾向スコアの overlap", m),
      x = "P(metformin_high = 1 | covariates)",
      y = "密度",
      fill = "治療状態"
    )
  print(p)
}
