# ==============================================================================
#  MSM・g-formula ハンズオン ／ 本番パート② : parametric g-formula
# ------------------------------------------------------------------------------
#  MSM が「治療の側」から重み付けで反実仮想に迫ったのに対し、
#  g-formula は「アウトカムの側」から、前向きシミュレーションで反実仮想の
#  世界を組み立てます。同じ推定量（常に増量状態 vs 常に非増量のリスク差）に、
#  別ルートから迫ります。
#
#  データ：data/person_interval.csv
#    metformin_high = 増量状態にあるか（治療 A）
#    hba1c_high     = HbA1c 7.5%以上か（時間依存交絡 L）
#    cvd_event      = 心血管イベント（アウトカム Y）
# ==============================================================================

# --- 0. データ読み込み ---
if (file.exists("data/person_interval.csv")) {
  dat <- read.csv("data/person_interval.csv")
} else if (file.exists("../data/person_interval.csv")) {
  dat <- read.csv("../data/person_interval.csv")
} else {
  stop("data/person_interval.csv が見つかりません。")
}
n_int <- max(dat$month)
dat$age_z <- (dat$age - mean(dat$age)) / sd(dat$age)
dat <- dat[order(dat$patient_id, dat$month), ]


# ==============================================================================
#  1. g-formula の2つの部品
# ------------------------------------------------------------------------------
#  (A) アウトカムモデル（ハザードモデル）
#      その月にイベントが起きる確率を、治療状態 A・交絡 L・baseline で予測。
#  (B) L の遷移モデル ★g-formula の心臓★
#      次の月の HbA1c 高値を、前月の治療状態・前月の L・baseline で予測。
#      「増量状態を続けると次の HbA1c が下がる（A→L）」を、このモデルが担う。
#      ＝MSM にはなかった部品。
# ==============================================================================

# (A) アウトカムモデル
out_model <- glm(cvd_event ~ metformin_high + hba1c_high +
                   age_z + sex + smoking + hypertension + dyslipidemia + factor(month),
                 family = binomial, data = dat)

# (B) L 遷移モデル（month=1 は baseline のみ、month>=2 は前月の治療状態と L も）
L_model_init  <- glm(hba1c_high ~ age_z + sex + smoking + hypertension + dyslipidemia,
                     family = binomial, data = dat[dat$month == 1, ])
L_model_trans <- glm(hba1c_high ~ metformin_high_prev + hba1c_high_prev +
                       age_z + sex + smoking + hypertension + dyslipidemia,
                     family = binomial, data = dat[dat$month >= 2, ])


# ==============================================================================
#  2. 前向きシミュレーション：3ステップを月1から6まで繰り返す
# ------------------------------------------------------------------------------
#  各月でやること：
#    ステップ1：この月の L をサンプリング（L 遷移モデルから）
#    ステップ2：この月のハザード h_k を計算（その L と、固定した治療 A で）
#    ステップ3：生存確率 (1 - h_k) を掛けていく
#  → 6か月すべてを生き延びる確率の余事象が、累積発生率。
# ==============================================================================

g_formula <- function(always_high, mc = 50) {
  # baseline をモンテカルロ複製（シミュレーションを安定させる）
  base <- dat[!duplicated(dat$patient_id),
              c("age_z","sex","smoking","hypertension","dyslipidemia")]
  base <- base[rep(seq_len(nrow(base)), mc), ]
  N <- nrow(base)

  surv <- rep(1, N); cuminc <- rep(0, N)
  L_prev <- integer(N); A_prev <- integer(N)

  for (k in 1:n_int) {
    # ステップ1：この月の L をサンプリング
    if (k == 1) {
      pL <- predict(L_model_init, base, type = "response")
    } else {
      pL <- predict(L_model_trans,
                    data.frame(base, metformin_high_prev = A_prev, hba1c_high_prev = L_prev),
                    type = "response")
    }
    L_k <- rbinom(N, 1, pL)

    # 治療は介入で固定（常に増量状態 = 1 / 常に非増量 = 0）
    A_k <- rep(if (always_high) 1L else 0L, N)

    # ステップ2：この月のハザード
    h <- predict(out_model, data.frame(base, metformin_high = A_k, hba1c_high = L_k, month = k),
                 type = "response")

    # ステップ3：生存確率を掛けていく
    cuminc <- cuminc + surv * h
    surv   <- surv * (1 - h)

    L_prev <- L_k; A_prev <- A_k
  }
  mean(cuminc)
}

set.seed(123)
risk_high <- g_formula(TRUE)
risk_none <- g_formula(FALSE)
rd_gf <- risk_high - risk_none

cat("=== g-formula による推定 ===\n")
cat(sprintf("  常に増量状態 %.3f / 常に非増量 %.3f / リスク差 %+.3f\n\n",
            risk_high, risk_none, rd_gf))


# ==============================================================================
#  3. 【伏線の回収】g-formula は「真値を出したコード」とそっくり
# ------------------------------------------------------------------------------
#  事前課題で真値を出したとき、真の係数を使って介入世界をシミュレーションしました。
#  本番の g-formula がやっているのは、まったく同じこと。違いは「真の係数」を使うか、
#  「データから推定した係数」を使うかだけ。
#  ここで、真の係数をそのまま前向きシミュレーションに入れてみます。
# ==============================================================================

expit <- function(x) 1 / (1 + exp(-x))
b_L0  <- c(int=-0.4, age=0.4, smk=0.2, htn=0.3, dys=0.3)
b_Ltr <- c(int=-0.3, Lprev=1.6, Astate=-1.5, age=0.3, smk=0.15, htn=0.2, dys=0.2)
b_Y   <- c(int=-3.6, A=-0.5, L=1.4, age=0.4, smk=0.4, htn=0.3, dys=0.3)

g_formula_true <- function(up, N = 50000) {
  age <- rnorm(N); smk <- rbinom(N,1,0.3); htn <- rbinom(N,1,0.4); dys <- rbinom(N,1,0.4)
  surv <- rep(1, N); cuminc <- rep(0, N); L_prev <- integer(N); A_prev <- integer(N)
  for (k in 1:n_int) {
    if (k == 1) lpL <- b_L0["int"]+b_L0["age"]*age+b_L0["smk"]*smk+b_L0["htn"]*htn+b_L0["dys"]*dys
    else        lpL <- b_Ltr["int"]+b_Ltr["Lprev"]*L_prev+b_Ltr["Astate"]*A_prev+
                       b_Ltr["age"]*age+b_Ltr["smk"]*smk+b_Ltr["htn"]*htn+b_Ltr["dys"]*dys
    L_k <- rbinom(N, 1, expit(lpL)); A_k <- rep(up, N)
    lpY <- b_Y["int"]+b_Y["A"]*A_k+b_Y["L"]*L_k+b_Y["age"]*age+b_Y["smk"]*smk+b_Y["htn"]*htn+b_Y["dys"]*dys
    h <- expit(lpY); cuminc <- cuminc + surv*h; surv <- surv*(1-h); L_prev <- L_k; A_prev <- A_k
  }
  mean(cuminc)
}
set.seed(123)
rd_true_params <- g_formula_true(1) - g_formula_true(0)
cat("=== 伏線の回収：真の係数で回すと真値になる ===\n")
cat(sprintf("  真の係数版 RD = %+.3f （真値 -0.232 とほぼ一致）\n", rd_true_params))
cat("  → g-formula とは、DGP をデータから推定して、それを介入下で回す手法。\n")
cat("    真の係数を使えば真値そのもの。推定した係数を使うのが実際の g-formula。\n\n")


# ==============================================================================
#  4. bootstrap で信頼区間
# ==============================================================================
gf_rd_once <- function(d) {
  d <- d[order(d$patient_id, d$month), ]
  om  <- glm(cvd_event ~ metformin_high + hba1c_high +
               age_z + sex + smoking + hypertension + dyslipidemia + factor(month), binomial, d)
  Li  <- glm(hba1c_high ~ age_z + sex + smoking + hypertension + dyslipidemia,
             binomial, d[d$month == 1, ])
  Lt  <- glm(hba1c_high ~ metformin_high_prev + hba1c_high_prev +
               age_z + sex + smoking + hypertension + dyslipidemia, binomial, d[d$month >= 2, ])
  sim <- function(high, mc = 50) {
    base <- d[!duplicated(d$patient_id), c("age_z","sex","smoking","hypertension","dyslipidemia")]
    base <- base[rep(seq_len(nrow(base)), mc), ]
    N <- nrow(base); surv <- rep(1,N); cum <- rep(0,N); Lp <- integer(N); Ap <- integer(N)
    for (k in 1:n_int) {
      pL <- if (k==1) predict(Li, base, type="response")
            else predict(Lt, data.frame(base, metformin_high_prev=Ap, hba1c_high_prev=Lp), type="response")
      Lk <- rbinom(N,1,pL); Ak <- rep(if(high)1L else 0L, N)
      h <- predict(om, data.frame(base, metformin_high=Ak, hba1c_high=Lk, month=k), type="response")
      cum <- cum + surv*h; surv <- surv*(1-h); Lp <- Lk; Ap <- Ak
    }
    mean(cum)
  }
  sim(TRUE) - sim(FALSE)
}

set.seed(123)
ids <- unique(dat$patient_id); B <- 300
boot_rd <- numeric(B)
for (b in seq_len(B)) {
  samp <- sample(ids, length(ids), replace = TRUE)
  bd <- do.call(rbind, lapply(seq_along(samp), function(i) {
    x <- dat[dat$patient_id == samp[i], ]; x$patient_id <- i; x
  }))
  boot_rd[b] <- suppressWarnings(tryCatch(gf_rd_once(bd), error = function(e) NA))
}
ci <- quantile(boot_rd, c(0.025, 0.975), na.rm = TRUE)
cat("=== bootstrap 95%CI（患者単位）===\n")
cat(sprintf("  g-formula リスク差 = %+.3f  95%%CI [%+.3f, %+.3f]  (B=%d)\n\n",
            rd_gf, ci[1], ci[2], B))


# ==============================================================================
#  5. MSM と g-formula を並べる
# ==============================================================================
cat("==============================================================\n")
cat(" 推定量の比較（すべてリスク差、同じスケール）\n")
cat("--------------------------------------------------------------\n")
cat("   真値                       -0.232\n")
cat("   naive（HbA1c 非調整）       約 -0.110  （届かない）\n")
cat("   naive（HbA1c 調整）         約 -0.094  （届かない）\n")
cat("   MSM（IP weighting）         約 -0.270  （真値近傍）\n")
cat(sprintf("   g-formula（standardization）%+.3f  （真値近傍）\n", rd_gf))
cat("--------------------------------------------------------------\n")
cat(" MSM は治療側から、g-formula はアウトカム側から迫り、どちらも真値の\n")
cat(" 近傍を指す。別ルートの2手法が同じ結論を支持する。完全一致しないのは\n")
cat(" 小標本ゆえで、その不確実性は bootstrap の CI 幅に表れている。\n")
cat("==============================================================\n")


# ==============================================================================
#  ＜補足＞ 実データ（breakthrough-stroke 論文）との対応
# ------------------------------------------------------------------------------
#  今日の g-formula の心臓は「L の遷移モデル（ステップ1）」でした。増量状態が
#  次の HbA1c を変える（A→L）フィードバックを、このモデルが前向きに再現します。
#  論文では治療が baseline で固定（once-treated-always-treated）なので、
#  「治療がその後の L を動かす」を追う必要がなく、L の遷移シミュレーションが
#  丸ごと不要になり、g-formula は「baseline 共変量での標準化」へと退化します。
#  論文の g-formula は、今日の time-varying 版の特殊ケースにあたります。
# ==============================================================================


# ==============================================================================
#  6. gfoRmula パッケージを用いた実装との比較
# ------------------------------------------------------------------------------
#  上記で手書きした g-formula の前向きシミュレーションおよび bootstrap 処理を、
#  実務で広く使われる R の「gfoRmula」パッケージを用いて再現し、結果を比較します。
# ==============================================================================

# --- パッケージの準備 ---
required_pkgs <- c("gfoRmula", "data.table")
new_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(new_pkgs) > 0) {
  cat(sprintf("以下のパッケージをインストールします: %s\n", paste(new_pkgs, collapse = ", ")))
  install.packages(new_pkgs, repos = "https://cran.r-project.org")
}
library(gfoRmula)
library(data.table)

# gfoRmula パッケージ用のデータ整形
#  ・時間変数は 0 始まりで 1 刻み（month 1..6 → t0 = 0..5）
#  ・lag 変数はパッケージが自動生成するため、dat 内の lag 変数は渡さない
gdat <- dat[, c("patient_id", "month", "age_z", "smoking", "hypertension", "dyslipidemia", "hba1c_high", "metformin_high", "cvd_event")]
gdat$t0 <- gdat$month - 1
gdat <- data.table::as.data.table(gdat)
data.table::setorder(gdat, patient_id, t0)

# gfoRmula 設定
id           <- "patient_id"
time_name    <- "t0"
time_points  <- n_int
covnames     <- c("hba1c_high", "metformin_high")
covtypes     <- c("binary", "binary")
outcome_name <- "cvd_event"
basecovs     <- c("age_z", "smoking", "hypertension", "dyslipidemia")

# 共変量の遷移モデル
covparams <- list(covmodels = c(
  hba1c_high     ~ lag1_metformin_high + lag1_hba1c_high + age_z + smoking + hypertension + dyslipidemia + t0,
  metformin_high ~ lag1_metformin_high + hba1c_high + age_z + smoking + hypertension + dyslipidemia + t0
))

# アウトカムモデル
ymodel <- cvd_event ~ metformin_high + hba1c_high + age_z + smoking + hypertension + dyslipidemia + t0

# 履歴変数の作成ルール
histories <- c(lagged)
histvars  <- list(c("metformin_high", "hba1c_high"))

# 介入シナリオの設定（1 = 常に非増量, 2 = 常に増量状態）
intvars       <- list("metformin_high", "metformin_high")
interventions <- list(list(c(static, rep(0, time_points))),
                      list(c(static, rep(1, time_points))))
int_descript  <- c("常に非増量", "常に増量状態")

cat("=== gfoRmula パッケージによる実行 (B=300) ===\n")
# パッケージによる g-formula の実行
# (少し時間がかかります)
gf_pkg <- gformula(
  obs_data      = gdat,
  id            = id,
  time_name     = time_name,
  time_points   = time_points,
  covnames      = covnames,
  covtypes      = covtypes,
  covparams     = covparams,
  outcome_name  = outcome_name,
  outcome_type  = "survival",
  ymodel        = ymodel,
  histories     = histories,
  histvars      = histvars,
  basecovs      = basecovs,
  intvars       = intvars,
  interventions = interventions,
  int_descript  = int_descript,
  ref_int       = 1, # 参照を「常に非増量 (1)」に設定
  nsimul        = 10000,
  nsamples      = 300, # bootstrap
  parallel      = FALSE,
  seed          = 123
)

print(gf_pkg)
