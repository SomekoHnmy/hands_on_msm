# ==============================================================================
#  MSM・g-formula ハンズオン ／ 本番パート① : MSM（IP weighting）
# ------------------------------------------------------------------------------
#  ステップ10：クラスターロバスト標準誤差を計算する
#  ステップ11：bootstrap で信頼区間を求める
#  ステップ12：最終結果（点推定＋95%CI）を確認する
# ==============================================================================

# 前提となる点推定を読み込み
if (file.exists("scripts/07_msm_point_estimate.R")) {
  source("scripts/07_msm_point_estimate.R")
} else if (file.exists("07_msm_point_estimate.R")) {
  source("07_msm_point_estimate.R")
} else {
  stop("07_msm_point_estimate.R が見つかりません。")
}

# ==============================================================================
#  ステップ10：クラスターロバスト標準誤差を計算する
# ------------------------------------------------------------------------------
#  person-month は同一人物の行が相関する（独立でない）。標準誤差は患者単位の
#  クラスターロバスト SE で評価する。実務では sandwich::vcovCL が定番。
#  下は概念を示す簡易実装と、sandwich パッケージを用いた実務コードの両方を示します。
# ==============================================================================
cluster_robust_se <- function(model, cluster) {
  X <- model.matrix(model); u <- residuals(model, type = "response")
  bread <- vcov(model); ef <- X * (u * weights(model))
  meat <- matrix(0, ncol(X), ncol(X))
  for (cl in unique(cluster)) {
    idx <- cluster == cl; s <- colSums(ef[idx, , drop = FALSE]); meat <- meat + outer(s, s)
  }
  sqrt(diag(bread %*% meat %*% bread))
}
se_cl <- cluster_robust_se(msm, dat$patient_id)

# sandwich パッケージを用いた実務コード
vcov_cl <- sandwich::vcovCL(msm, cluster = dat$patient_id)
se_sandwich <- sqrt(diag(vcov_cl))
vcov_cl_raw <- sandwich::vcovCL(msm, cluster = dat$patient_id, cadjust = FALSE)
se_sandwich_raw <- sqrt(diag(vcov_cl_raw))

cat("=== ステップ10：クラスターロバスト SE（患者単位）===\n")
res_se <- cbind(
  coef = coef(msm)[1:3],
  se_cluster_robust_simple = se_cl[1:3],
  se_sandwich_raw = se_sandwich_raw[1:3],
  se_sandwich_cadjust = se_sandwich[1:3]
)
print(round(res_se, 4))
cat("  → 相関を無視した SE より広くなるのが普通。簡易実装（simple）と sandwich（補正なし: raw）の値が完全に一致することを確認してください。\n")
cat("    (※ sandwich デフォルトの cadjust=TRUE では小サンプル補正・自由度調整が入るため、わずかに値が大きくなります。)\n\n")

# ==============================================================================
#  ステップ11：bootstrap で信頼区間を求める
# ------------------------------------------------------------------------------
#  患者ごと丸ごとリサンプリング → 重み再推定 → MSM 再フィット → RD 再計算。
#  重み推定を内側で繰り返すことで、重み推定の不確実性まで CI に含める。
#  （B=300 は実行に数十秒かかります）
# ==============================================================================
msm_rd_once <- function(d) {
  den <- glm(metformin_high ~ hba1c_high + hba1c_high_prev + metformin_high_prev +
               age_z + sex + smoking + hypertension + dyslipidemia + factor(month),
             family = binomial, data = d)
  num <- glm(metformin_high ~ metformin_high_prev + factor(month), family = binomial, data = d)
  pd <- pmax(pmin(predict(den, type="response"), 1-1e-8), 1e-8)
  pn <- pmax(pmin(predict(num, type="response"), 1-1e-8), 1e-8)
  d$f_den <- ifelse(d$metformin_high==1, pd, 1-pd)
  d$f_num <- ifelse(d$metformin_high==1, pn, 1-pn)
  d <- d[order(d$patient_id, d$month), ]
  d$sw <- ave(d$f_num / d$f_den, d$patient_id, FUN = cumprod)
  q <- quantile(d$sw, c(0.01, 0.99)); d$sw <- pmin(pmax(d$sw, q[1]), q[2])
  d$cumA <- ave(d$metformin_high, d$patient_id, FUN = cumsum)
  # (bootstrap 中も weights による無害な non-integer 警告が出ますが、無視して構いません)
  m <- glm(cvd_event ~ metformin_high + cumA + factor(month),
           family = binomial, data = d, weights = sw)
  cuminc_under(m, TRUE) - cuminc_under(m, FALSE)
}
set.seed(123)
ids <- unique(dat$patient_id); B <- 300
boot_rd <- numeric(B)
for (b in seq_len(B)) {
  samp <- sample(ids, length(ids), replace = TRUE)
  bd <- do.call(rbind, lapply(seq_along(samp), function(i) {
    x <- dat[dat$patient_id == samp[i], ]; x$patient_id <- i; x
  }))
  boot_rd[b] <- suppressWarnings(tryCatch(msm_rd_once(bd), error = function(e) NA))
}
ci <- quantile(boot_rd, c(0.025, 0.975), na.rm = TRUE)

# ==============================================================================
#  ステップ12：最終結果（点推定＋95%CI）を確認する
# ==============================================================================
cat("=== ステップ12：MSM 最終結果 ===\n")
cat(sprintf("  MSM リスク差 = %+.3f  95%%CI [%+.3f, %+.3f]  (B=%d)\n\n", rd_msm, ci[1], ci[2], B))

# ==============================================================================
#  まとめ
# ==============================================================================
cat("==============================================================\n")
cat(" MSM のまとめ\n")
cat("--------------------------------------------------------------\n")
cat(sprintf(" 推定：常に増量状態 vs 常に非増量 のリスク差 = %+.3f\n", rd_msm))
cat(" 通った手順：\n")
cat("   1 治療モデル → 2 収束確認 → 3 重み計算 → 4 重みの意味 →\n")
cat("   5 重み分布/truncation → 6 positivity(ESS) → 7 各月バランス →\n")
cat("   8 MSM推定 → 9 点推定 → 10 クラスターSE → 11 bootstrap → 12 最終結果\n")
cat("\n 次は g-formula で、別ルート（アウトカム側）から同じ推定に迫る。\n")
cat("==============================================================\n")

# ==============================================================================
#  ＜補足＞ 実データ（breakthrough-stroke 論文）との対応
# ------------------------------------------------------------------------------
#  今日の治療重みは時間依存でした（各月 hba1c_high を見て増量状態の確率を
#  モデル化し、履歴を掛け合わせる）。論文は治療が baseline 固定
#  （once-treated-always-treated）なので、この治療重みは baseline の傾向スコア
#  1回分に潰れ、時間依存で残るのは脱落に対する打ち切り重み（IPCW）だけでした。
#  上の手順（収束・positivity・バランス・クラスターSE・bootstrap）は、論文でも
#  そのまま踏んでいます。
# ==============================================================================
