# ==============================================================================
#  MSM・g-formula ハンズオン ／ 本番パート① : MSM（IP weighting）
# ------------------------------------------------------------------------------
#  ステップ7：各時点で共変量のバランス（SMD）を確認する
# ==============================================================================

# 前提となる重みの計算を読み込み
if (file.exists("scripts/05_msm_stabilized_weight.R")) {
  source("scripts/05_msm_stabilized_weight.R")
} else if (file.exists("05_msm_stabilized_weight.R")) {
  source("05_msm_stabilized_weight.R")
} else {
  stop("05_msm_stabilized_weight.R が見つかりません。")
}

# ==============================================================================
#  ステップ7：各時点で共変量のバランス（SMD）を確認する
# ------------------------------------------------------------------------------
#  重み付けで交絡因子の分布がそろったかを標準化平均差（SMD）で見る。|SMD|<0.1
#  が目安。時間依存治療では baseline だけでなく各月で見る（実務では cobalt::bal.tab）。
#  ※ パッケージ（cobalt, ggplot2）は 03_msm_load_data.R でロード済み
# ==============================================================================
cov_list <- c("hba1c_high", "age_z", "smoking", "hypertension", "dyslipidemia")

cat("=== ステップ7：cobalt::bal.tab による各月の共変量バランス ===\n")
summary_list <- list()

for (m in 1:n_int) {
  dm <- dat[dat$month == m, ]
  if (length(unique(dm$metformin_high)) < 2) next

  # 各月における調整前後の SMD の算出
  bt <- bal.tab(
    x = dm[, cov_list],
    treat = dm$metformin_high,
    weights = dm$sw_trunc,
    un = TRUE,
    s.d.denom = "pooled",
    binary = "std",
    thresholds = c(m = 0.1)
  )
  
  cat(sprintf("\n--- 月%d のバランス ---\n", m))
  print(bt)

  # 各月の Love plot の描画
  lp <- love.plot(bt, threshold = 0.1, abs = TRUE, stars = "raw",
                  title = sprintf("月%d: 共変量バランス (Love plot)", m))
  print(lp)

  # 最大|SMD|（重み調整後）の抽出
  bal_df <- bt$Balance
  max_smd <- max(abs(bal_df$Diff.Adj), na.rm = TRUE)
  max_var <- rownames(bal_df)[which.max(abs(bal_df$Diff.Adj))]

  summary_list[[length(summary_list) + 1]] <- data.frame(
    Month = m,
    Max_SMD = max_smd,
    Max_Variable = max_var,
    Balanced = ifelse(max_smd < 0.1, "OK", "要確認"),
    stringsAsFactors = FALSE
  )
}

cat("\n=== ステップ7サマリー：各月の最大 |SMD| トレンド ===\n")
res_tbl <- do.call(rbind, summary_list)
print(res_tbl, row.names = FALSE)

cat("\n  【注】このシミュレーションデータでは、各月の SMD が目安 0.1 を超えて\n")
cat("        しまいます。SMD は本来こうして月次で確認しますが、今回は MSM の\n")
cat("        一連の手順を見てもらうことが目的なので、このまま進めます。\n")
cat("        （positivity はステップ6の ESS で確認済みで、良好です）\n\n")
