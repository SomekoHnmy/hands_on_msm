# 中間スクリプト: 仮想データの生成と保存
# C:\Users\sangu\Documents\論文\hands_on_msm_gformula\agent\generate_data.R

n_int <- 6                      # 区間数（6か月）
expit <- function(x) 1 / (1 + exp(-x))   # ロジット逆関数：logオッズ → 確率

# 各モデルの係数（logit スケール）
b_L0  <- c(int = -0.4, age = 0.4, smk = 0.2, htn = 0.3, dys = 0.3)
b_Ltr <- c(int = -0.3, Lprev = 1.8, Aprev = -2.2,
           age = 0.3, smk = 0.15, htn = 0.2, dys = 0.2)
b_A   <- c(int = -1.0, L = 0.9, Aprev = 0.8,
           age = 0.1, smk = 0.0, htn = 0.1, dys = 0.1)
b_Y   <- c(int = -3.6, A = -0.5, L = 1.4,
           age = 0.4, smk = 0.4, htn = 0.3, dys = 0.3)

generate_data <- function(n, intervene = NA, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  age <- rnorm(n)                 # 標準化年齢（平均0）
  smk <- rbinom(n, 1, 0.3)        # 喫煙 30%
  htn <- rbinom(n, 1, 0.4)        # 高血圧 40%
  dys <- rbinom(n, 1, 0.4)        # 脂質異常症 40%

  L_prev  <- integer(n)           # 前区間の L（区間1では0扱い）
  A_prev  <- integer(n)           # 前区間の A
  at_risk <- rep(TRUE, n)         # まだイベントを起こしていないか
  out     <- vector("list", n_int)

  for (k in seq_len(n_int)) {

    if (k == 1) {
      lpL <- b_L0["int"] + b_L0["age"]*age + b_L0["smk"]*smk +
             b_L0["htn"]*htn + b_L0["dys"]*dys
    } else {
      lpL <- b_Ltr["int"] + b_Ltr["Lprev"]*L_prev + b_Ltr["Aprev"]*A_prev +
             b_Ltr["age"]*age + b_Ltr["smk"]*smk + b_Ltr["htn"]*htn + b_Ltr["dys"]*dys
    }
    L_k <- rbinom(n, 1, expit(lpL))

    lpA <- b_A["int"] + b_A["L"]*L_k + b_A["Aprev"]*A_prev +
           b_A["age"]*age + b_A["smk"]*smk + b_A["htn"]*htn + b_A["dys"]*dys
    if (is.na(intervene)) {
      A_k <- rbinom(n, 1, expit(lpA))
    } else {
      A_k <- rep(as.integer(intervene), n)
    }

    lpY <- b_Y["int"] + b_Y["A"]*A_k + b_Y["L"]*L_k +
           b_Y["age"]*age + b_Y["smk"]*smk + b_Y["htn"]*htn + b_Y["dys"]*dys
    Y_k <- rbinom(n, 1, expit(lpY))
    Y_k[!at_risk] <- 0L

    out[[k]] <- data.frame(id = seq_len(n), interval = k,
                           age = age, smk = smk, htn = htn, dys = dys,
                           L = L_k, A = A_k, Lprev = L_prev, Aprev = A_prev,
                           Y = Y_k, at_risk = at_risk)

    L_prev  <- L_k
    A_prev  <- A_k
    at_risk <- at_risk & (Y_k == 0)
  }

  d <- do.call(rbind, out)
  d <- d[d$at_risk | d$Y == 1, ]
  d <- d[order(d$id, d$interval), ]
  d$at_risk <- NULL
  rownames(d) <- NULL
  d
}

# 観察データ (N=1000) の生成
dat <- generate_data(1000, intervene = NA, seed = 2024)

# 保存先ディレクトリの作成
data_dir <- "C:/Users/sangu/Documents/論文/hands_on_msm_gformula/data"
if (!dir.exists(data_dir)) {
  dir.create(data_dir, recursive = TRUE)
}

# CSV形式で保存
write.csv(dat, file.path(data_dir, "observed_data.csv"), row.names = FALSE)

# RDS形式でも保存（Rでの読み込み用）
saveRDS(dat, file.path(data_dir, "observed_data.rds"))

cat("Data generation completed and saved to:", data_dir, "\n")
