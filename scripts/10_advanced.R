# ==============================================================================
#  MSM・g-formula ハンズオン ／ 発展パート : 時間依存交絡を 3 個に増やす
# ------------------------------------------------------------------------------
#  ここまでは時間依存交絡を 1 個（HbA1c）に絞ってきました。
#  現実の解析では、時間依存交絡は複数あるのがふつうです。
#  （HAART の古典研究でも、実際には CD4 だけでなく HIV ウイルス量など
#    複数の時間依存交絡を同時に扱っていました。教科書が CD4 一つで説明するのは
#    分かりやすさのための単純化であって、手法の制約ではありません。）
#
#  このパートで見せたいのは、交絡が 1 個から 3 個に増えたとき、
#  MSM と g-formula で「手間のかかり方」がまったく違う、という点です：
#
#    MSM       … 重みのモデルに項を足すだけ。ほぼ手間が変わらない。
#    g-formula … 交絡ごとに「遷移モデル」と「前向きサンプリング」が要る。
#                手書きだと急に重くなる → だから gfoRmula パッケージを使う。
#
#  ＜構成＞
#    前半：MSM を 3 交絡に拡張（式に項を足すだけ）※そのまま動きます
#    後半：g-formula を gfoRmula パッケージで ※パッケージ導入が必要
# ==============================================================================

n_int <- 6
expit <- function(x) 1 / (1 + exp(-x))

# ------------------------------------------------------------------------------
#  0. 時間依存交絡を 3 個に拡張した DGP（状態ベースの治療 A）
#     L1 = HbA1c 高値       （既存）
#     L2 = 腎機能低下（eGFR低下）
#     L3 = 体重増加
#     A  = 増量状態にあるか（month=1 から両群が存在、状態が強く維持される）
#     いずれの L も「A に押され（L→A）」「A の影響を受ける（A→L）」フィードバックを持つ
# ------------------------------------------------------------------------------
b_L1_0  <- c(int=-0.4, age=0.4, smk=0.2, htn=0.3, dys=0.3)
b_L1_tr <- c(int=-0.3, L1prev=1.6, Astate=-1.5, age=0.3, smk=0.15, htn=0.2, dys=0.2)
b_L2_0  <- c(int=-0.6, age=0.5, htn=0.4)
b_L2_tr <- c(int=-0.4, L2prev=1.5, Astate=-0.7, age=0.4, htn=0.3)
b_L3_0  <- c(int=-0.5, dys=0.4)
b_L3_tr <- c(int=-0.3, L3prev=1.4, Astate=0.5, dys=0.3)
b_A1    <- c(int=-0.6, L1=0.8, L2=0.4, L3=0.3, age=0.15, htn=0.2, dys=0.2)   # 初月の増量状態
b_A_tr  <- c(int=-1.2, Aprev=3.0, L1=0.6, L2=0.3, L3=0.2, age=0.1, htn=0.1, dys=0.1)  # 状態遷移
b_Y     <- c(int=-3.7, A=-0.5, L1=1.4, L2=0.7, L3=0.5, age=0.4, smk=0.4, htn=0.3, dys=0.3)

generate_data3 <- function(n, intervene = NA, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  age <- rnorm(n); smk <- rbinom(n,1,0.3); htn <- rbinom(n,1,0.4); dys <- rbinom(n,1,0.4)
  L1p <- integer(n); L2p <- integer(n); L3p <- integer(n); Ap <- integer(n)
  at_risk <- rep(TRUE, n); out <- vector("list", n_int)
  for (k in seq_len(n_int)) {
    if (k == 1) {
      l1 <- b_L1_0["int"] + b_L1_0["age"]*age + b_L1_0["smk"]*smk + b_L1_0["htn"]*htn + b_L1_0["dys"]*dys
      l2 <- b_L2_0["int"] + b_L2_0["age"]*age + b_L2_0["htn"]*htn
      l3 <- b_L3_0["int"] + b_L3_0["dys"]*dys
    } else {
      l1 <- b_L1_tr["int"] + b_L1_tr["L1prev"]*L1p + b_L1_tr["Astate"]*Ap +
            b_L1_tr["age"]*age + b_L1_tr["smk"]*smk + b_L1_tr["htn"]*htn + b_L1_tr["dys"]*dys
      l2 <- b_L2_tr["int"] + b_L2_tr["L2prev"]*L2p + b_L2_tr["Astate"]*Ap + b_L2_tr["age"]*age + b_L2_tr["htn"]*htn
      l3 <- b_L3_tr["int"] + b_L3_tr["L3prev"]*L3p + b_L3_tr["Astate"]*Ap + b_L3_tr["dys"]*dys
    }
    L1 <- rbinom(n,1,expit(l1)); L2 <- rbinom(n,1,expit(l2)); L3 <- rbinom(n,1,expit(l3))
    if (is.na(intervene)) {
      if (k == 1) la <- b_A1["int"] + b_A1["L1"]*L1 + b_A1["L2"]*L2 + b_A1["L3"]*L3 +
                        b_A1["age"]*age + b_A1["htn"]*htn + b_A1["dys"]*dys
      else        la <- b_A_tr["int"] + b_A_tr["Aprev"]*Ap + b_A_tr["L1"]*L1 + b_A_tr["L2"]*L2 + b_A_tr["L3"]*L3 +
                        b_A_tr["age"]*age + b_A_tr["htn"]*htn + b_A_tr["dys"]*dys
      A <- rbinom(n,1,expit(la))
    } else A <- rep(as.integer(intervene), n)
    ly <- b_Y["int"] + b_Y["A"]*A + b_Y["L1"]*L1 + b_Y["L2"]*L2 + b_Y["L3"]*L3 +
          b_Y["age"]*age + b_Y["smk"]*smk + b_Y["htn"]*htn + b_Y["dys"]*dys
    Y <- rbinom(n,1,expit(ly)); Y[!at_risk] <- 0L
    out[[k]] <- data.frame(id = seq_len(n), month = k, age, smk, htn, dys,
                           L1, L2, L3, A, L1prev = L1p, L2prev = L2p, L3prev = L3p,
                           Aprev = Ap, Y, at_risk)
    L1p <- L1; L2p <- L2; L3p <- L3; Ap <- A; at_risk <- at_risk & (Y == 0)
  }
  d <- do.call(rbind, out); d <- d[d$at_risk | d$Y == 1, ]
  d <- d[order(d$id, d$month), ]; d$at_risk <- NULL; rownames(d) <- NULL; d
}

# 真値（3 交絡版）
d_all1 <- generate_data3(100000, intervene = 1, seed = 111)
d_all0 <- generate_data3(100000, intervene = 0, seed = 111)
risk1 <- length(unique(d_all1$id[d_all1$Y == 1])) / 100000
risk0 <- length(unique(d_all0$id[d_all0$Y == 1])) / 100000
cat("=== 真値（時間依存交絡 3 個版）===\n")
cat(sprintf("  常に増量状態 %.3f / 常に非増量 %.3f / RD %+.3f\n\n", risk1, risk0, risk1 - risk0))

# 観察データ
dat <- generate_data3(1000, intervene = NA, seed = 123)


# ==============================================================================
#  前半：MSM を 3 交絡に拡張する ―― 「式に項を足すだけ」を体感する
# ------------------------------------------------------------------------------
#  1 交絡版（02_msm.R）と見比べてください。変わったのは、分母モデルの右辺に
#  L2, L3, L2prev, L3prev を足しただけ。手続きは何も変わりません。
# ==============================================================================

den <- glm(A ~ L1 + L2 + L3 + L1prev + L2prev + L3prev + Aprev +
             age + smk + htn + dys + factor(month),
           family = binomial, data = dat)
num <- glm(A ~ Aprev + age + smk + htn + dys + factor(month),
           family = binomial, data = dat)

dat$fd <- ifelse(dat$A == 1, predict(den, type="response"), 1 - predict(den, type="response"))
dat$fn <- ifelse(dat$A == 1, predict(num, type="response"), 1 - predict(num, type="response"))
dat <- dat[order(dat$id, dat$month), ]
dat$sw   <- ave(dat$fn / dat$fd, dat$id, FUN = cumprod)
dat$cumA <- ave(dat$A, dat$id, FUN = cumsum)

msm <- glm(Y ~ A + cumA + factor(month), family = binomial, data = dat, weights = sw)
cuminc <- function(a) {
  s <- 1
  for (k in 1:n_int) {
    ca <- if (a == 1) k else 0
    h <- predict(msm, newdata = data.frame(A = a, cumA = ca, month = k), type = "response")
    s <- s * (1 - h)
  }
  1 - s
}
rd_msm3 <- cuminc(1) - cuminc(0)
cat("=== MSM（3 交絡版）===\n")
cat(sprintf("  リスク差 = %+.3f （真値 %+.3f）\n", rd_msm3, risk1 - risk0))
cat("  → 分母モデルに L2, L3 を足しただけ。MSM は交絡が増えても手間が変わらない。\n\n")


# ==============================================================================
#  後半：g-formula を gfoRmula パッケージで
# ------------------------------------------------------------------------------
#  1 交絡版（03_gformula.R）では、L の遷移を自分で書き、前向きに L をサンプリング
#  しながらハザードを積みました。交絡が 3 個になると、L1・L2・L3 それぞれに
#  遷移モデルが必要で、各区間で 3 つを順にサンプリングする必要があり、手書きの
#  ループは急に複雑になります。
#
#  ここで gfoRmula パッケージの出番です。大事なのは―――
#    「パッケージが中でやっていることは、03_gformula.R であなたが手で書いた
#      あの前向きシミュレーションと、まったく同じ」だということ。
#    中身を知ったうえで使うので、これはブラックボックスではありません。
#
#  ＜このコードは gfoRmula パッケージの導入が必要です＞
#    install.packages("gfoRmula")   # 未導入の場合
# ==============================================================================

library(gfoRmula)
library(data.table)

# --- gfoRmula 用にデータを整形する ---
#  gfoRmula の約束ごと：
#    ・時間変数は 0 始まりで 1 刻み（month 1..6 → t0 = 0..5）
#    ・lag 変数（前区間の値）はパッケージが自動生成するので、自分で作った
#      L1prev などは渡さない（histories でパッケージに任せる）
#    ・治療 A も covnames に含め、介入時に static で固定する（Never/Always）
gdat <- dat[, c("id", "month", "age", "smk", "htn", "dys", "L1", "L2", "L3", "A", "Y")]
gdat$t0 <- gdat$month - 1
gdat <- data.table::as.data.table(gdat)
data.table::setorder(gdat, id, t0)

# --- gfoRmula の引数 ---
id           <- "id"
time_name    <- "t0"
time_points  <- n_int
covnames     <- c("L1", "L2", "L3", "A")   # 時間依存交絡 3 個 + 治療（状態）
covtypes     <- c("binary", "binary", "binary", "binary")
outcome_name <- "Y"
basecovs     <- c("age", "smk", "htn", "dys")

# 各共変量の遷移モデル（lag1_ はパッケージが作る「前区間の値」）
#  ＝ 03_gformula.R の L 遷移モデルを、L1・L2・L3・A それぞれについて書いたもの
covparams <- list(covmodels = c(
  L1 ~ lag1_A + lag1_L1 + age + smk + htn + dys + t0,
  L2 ~ lag1_A + lag1_L2 + age + htn + t0,
  L3 ~ lag1_A + lag1_L3 + dys + t0,
  A  ~ lag1_A + L1 + L2 + L3 + age + htn + dys + t0
))

# アウトカム（ハザード）モデル ＝ 03_gformula.R の out_model に相当
ymodel <- Y ~ A + L1 + L2 + L3 + age + smk + htn + dys + t0

# 履歴：lag1（前区間の値）を A・L1・L2・L3 について作らせる
histories <- c(lagged)
histvars  <- list(c("A", "L1", "L2", "L3"))

# 介入：常に非増量（A=0, Never）と 常に増量状態（A=1, Always）
intvars       <- list("A", "A")
interventions <- list(list(c(static, rep(0, time_points))),
                      list(c(static, rep(1, time_points))))
int_descript  <- c("常に非増量", "常に増量状態")

# --- 実行（前向きシミュレーションも bootstrap もパッケージ内で処理）---
gf3 <- gformula(
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
  ref_int       = 0,          # 参照は「常に非増量」
  nsimul        = 10000,
  nsamples      = 200,        # bootstrap 標本数
  parallel      = FALSE,
  seed          = 123
)

print(gf3)

cat("\n")
cat("==============================================================\n")
cat(" 発展パートのまとめ\n")
cat("--------------------------------------------------------------\n")
cat(" ・MSM は、時間依存交絡が 3 個に増えても、重みのモデルに項を\n")
cat("   足すだけ。手続きはほとんど変わらない。\n")
cat(" ・g-formula は、交絡ごとに遷移モデルと前向きサンプリングが要る。\n")
cat("   手書きだと急に重くなるので、gfoRmula パッケージに任せる。\n")
cat("   ただしパッケージが中でやっているのは、1 交絡版で自分が手で\n")
cat("   書いたのと同じ前向きシミュレーション。中身を知って使えば、\n")
cat("   これはブラックボックスではない。\n")
cat(" ・この『手間の非対称性』が、実務でどちらの手法を選ぶかの\n")
cat("   判断材料の一つになる（正解は状況次第。両方できるのが理想）。\n")
cat("==============================================================\n")
