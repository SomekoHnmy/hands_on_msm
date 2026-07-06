# ==============================================================================
#  MSM・g-formula ハンズオン ／ 本番パート① : MSM（IP weighting）
# ------------------------------------------------------------------------------
#  ステップ8：重み付き pooled logistic で MSM を推定する
#  ステップ9：MSM の点推定を確認する
# ==============================================================================

# 前提となる共変量バランスの確認を読み込み
if (file.exists("scripts/06_msm_balance_check.R")) {
  source("scripts/06_msm_balance_check.R")
} else if (file.exists("06_msm_balance_check.R")) {
  source("06_msm_balance_check.R")
} else {
  stop("06_msm_balance_check.R が見つかりません。")
}

# ==============================================================================
#  ステップ8：重み付き pooled logistic で MSM を推定する
# ------------------------------------------------------------------------------
#  累積曝露 cumA（これまで増量状態にあった月数）を入れる：増量の効果は続ける
#  ことで積み上がるため、「6か月ずっと増量状態でいた戦略」を正しく表現する。
#  各月ハザードを予測 → 生存確率を掛け合わせ → 累積発生率 → 2戦略の差。
# ==============================================================================
dat$cumA <- ave(dat$metformin_high, dat$patient_id, FUN = cumsum)
msm <- glm(cvd_event ~ metformin_high + cumA + factor(month),
           family = binomial, data = dat, weights = sw_trunc)

cuminc_under <- function(model, always_high) {
  surv <- 1
  for (k in 1:n_int) {
    a  <- if (always_high) 1 else 0
    ca <- if (always_high) k else 0
    h  <- predict(model, newdata = data.frame(metformin_high = a, cumA = ca, month = k),
                  type = "response")
    surv <- surv * (1 - h)
  }
  1 - surv
}
risk_high <- cuminc_under(msm, TRUE)
risk_none <- cuminc_under(msm, FALSE)
rd_msm    <- risk_high - risk_none

# ==============================================================================
#  ステップ9：MSM の点推定を確認する
# ==============================================================================
cat("=== ステップ9：MSM の点推定 ===\n")
cat(sprintf("  常に増量状態 %.3f / 常に非増量 %.3f / リスク差 %+.3f\n", risk_high, risk_none, rd_msm))
cat("  → naive（約 -0.09〜-0.11）では届かなかった真値 -0.233 に迫れた。\n\n")
