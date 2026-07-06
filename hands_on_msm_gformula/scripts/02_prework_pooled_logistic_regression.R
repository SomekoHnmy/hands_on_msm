# ==============================================================================
#  MSM・g-formula ハンズオン ／ 事前課題②：naive 解析の実行
# ------------------------------------------------------------------------------
#  テーマ： 畳み込んだ person-interval データの上で、
#           「時間依存交絡を調整してもしなくても、ふつうの回帰は真値から外れる」
#           ことを確認します。
# ==============================================================================

library(survival)

# 実行時のワーキングディレクトリ（プロジェクトルートか、scripts/ ディレクトリか）に応じて
# 相対パスを自動的に切り替えます。
if (dir.exists("data")) {
  data_dir <- "data"
} else if (dir.exists("../data")) {
  data_dir <- "../data"
} else {
  stop("data ディレクトリが見つかりません。ワーキングディレクトリを確認してください。")
}

person_interval_path <- file.path(data_dir, "person_interval.csv")
if (!file.exists(person_interval_path)) {
  stop("person_interval.csv が見つかりません。先に事前課題①を実行してデータを作成してください。")
}

d <- read.csv(person_interval_path)
n_int <- 6

# 年齢の標準化（モデルの予測・計算の安定化のため）
d$age_z <- (d$age - mean(d$age)) / sd(d$age)

# 予測から6か月累積発生率・リスク差を出す補助関数
risk_diff_from_glm <- function(model, data, use_L) {
  base <- data[!duplicated(data$patient_id),
               c("patient_id","age_z","smoking","hypertension","dyslipidemia")]
  risks <- sapply(c(0, 1), function(a) {
    surv <- rep(1, nrow(base))
    for (k in seq_len(n_int)) {
      nd <- data.frame(base, month = k, metformin_high = a)
      if (use_L) nd$hba1c_high <- mean(data$hba1c_high[data$month == k])
      h <- predict(model, newdata = nd, type = "response")
      surv <- surv * (1 - h)
    }
    mean(1 - surv)
  })
  risks[2] - risks[1]
}

# naive 1：hba1c_high を入れない
fit_noL <- glm(cvd_event ~ metformin_high + factor(month) +
                 age_z + smoking + hypertension + dyslipidemia,
               family = binomial, data = d)
res_noL <- risk_diff_from_glm(fit_noL, d, use_L = FALSE)

# naive 2：hba1c_high を time-varying 共変量として入れる
fit_wL <- glm(cvd_event ~ metformin_high + hba1c_high + factor(month) +
                age_z + smoking + hypertension + dyslipidemia,
              family = binomial, data = d)
res_wL <- risk_diff_from_glm(fit_wL, d, use_L = TRUE)

# 参考：naive Cox（time-varying hba1c_high あり/なし）
cox_noL <- coxph(Surv(month - 1, month, cvd_event) ~ metformin_high +
                   age_z + smoking + hypertension + dyslipidemia, data = d)
cox_wL  <- coxph(Surv(month - 1, month, cvd_event) ~ metformin_high + hba1c_high +
                   age_z + smoking + hypertension + dyslipidemia, data = d)

# --- 真値のロード ---
if (file.exists(file.path(data_dir, "true_values.csv"))) {
  true_val <- read.csv(file.path(data_dir, "true_values.csv"))
  true_rd  <- true_val$true_rd
} else {
  true_rd <- -0.233
}

cat("=== Part 3: naive（pooled logistic）の結果（リスク差）===\n")
cat(sprintf("  真値（参考）             : RD = %+.3f  ← 当日に導出\n", true_rd))
cat(sprintf("  HbA1c を調整しない       : RD = %+.3f\n", res_noL))
cat(sprintf("  HbA1c を調整する         : RD = %+.3f\n", res_wL))
cat("  → どちらも真値には届かない。調整 of 仕方で値は動くが、正解ではない。\n\n")

cat("  Cox のハザード比（参考）：\n")
cat(sprintf("    naive 1（HbA1c なし）: metformin_high の HR = %.3f\n", exp(coef(cox_noL)["metformin_high"])))
cat(sprintf("    naive 2（HbA1c あり）: metformin_high の HR = %.3f\n", exp(coef(cox_wL)["metformin_high"])))
cat("    → HbA1c を入れるか入れないかで推定値が動く。どちらが正しいとも言えない。\n\n")

cat("==============================================================\n")
cat(" まとめ（事前課題）\n")
cat("--------------------------------------------------------------\n")
cat(" ・L（HbA1c）は『交絡因子』であると同時に『増量の中間変数』でもある。\n")
cat("   この二役があるために、ふつうの回帰では扱いに困る。\n")
cat(" ・実際、L を調整してもしなくても、推定値は真値に届かない。\n")
cat("   （調整の仕方で値は動くが、どちらも正解ではない）\n")
cat(" ・大事なのは『どちらの調整が正しいか』ではなく、\n")
cat("   『ふつうの回帰という枠組みそのものが、この問題には力不足』という点。\n")
cat("\n")
cat(" → では、どうすればよいのか？ 当日、MSM と g-formula を扱います。\n")
cat("==============================================================\n")
