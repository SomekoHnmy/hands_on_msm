# ==============================================================================
#  MSM・g-formula ハンズオン ／ 仮想データ生成スクリプト
#  (not for participant use)
# ------------------------------------------------------------------------------
#  このスクリプトは、参加者に配布する生データ（4つのテーブル）をシミュレーションによって
#  生成し、data/ ディレクトリにCSV形式で保存します。
#  また、本番での検証用に「真の因果効果（真値）」も算出して保存します。
# ==============================================================================

n_int <- 6                      # 区間数（6か月）
expit <- function(x) 1 / (1 + exp(-x))   # ロジット逆関数

# 各モデルの真の係数（DGP）
b_L0  <- c(int = -0.4, age = 0.4, smk = 0.2, htn = 0.3, dys = 0.3)
b_Ltr <- c(int = -0.3, Lprev = 1.6, Astate = -1.5, age = 0.3, smk = 0.15, htn = 0.2, dys = 0.2)
b_A1  <- c(int = -0.6, L = 0.9, age = 0.15, htn = 0.2, dys = 0.2)   # 初月の増量状態
b_Atr <- c(int = -1.2, Aprev = 3.0, L = 0.7, age = 0.1, htn = 0.1, dys = 0.1)  # 状態遷移
b_Y   <- c(int = -3.6, A = -0.5, L = 1.4, age = 0.4, smk = 0.4, htn = 0.3, dys = 0.3)

# ------------------------------------------------------------------------------
#  1. 真値計算用の generate_data_for_truth 関数
# ------------------------------------------------------------------------------
generate_data_for_truth <- function(n, intervene = NA, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  age <- rnorm(n)
  smk <- rbinom(n, 1, 0.3)
  htn <- rbinom(n, 1, 0.4)
  dys <- rbinom(n, 1, 0.4)

  L_prev  <- integer(n)
  A_prev  <- integer(n)
  at_risk <- rep(TRUE, n)
  out     <- vector("list", n_int)

  for (k in seq_len(n_int)) {
    if (k == 1) {
      lpL <- b_L0["int"] + b_L0["age"]*age + b_L0["smk"]*smk + b_L0["htn"]*htn + b_L0["dys"]*dys
    } else {
      lpL <- b_Ltr["int"] + b_Ltr["Lprev"]*L_prev + b_Ltr["Astate"]*A_prev +
             b_Ltr["age"]*age + b_Ltr["smk"]*smk + b_Ltr["htn"]*htn + b_Ltr["dys"]*dys
    }
    L_k <- rbinom(n, 1, expit(lpL))

    # 介入時と通常時で分岐
    if (is.na(intervene)) {
      if (k == 1) {
        lpA <- b_A1["int"] + b_A1["L"]*L_k + b_A1["age"]*age + b_A1["htn"]*htn + b_A1["dys"]*dys
      } else {
        lpA <- b_Atr["int"] + b_Atr["Aprev"]*A_prev + b_Atr["L"]*L_k +
               b_Atr["age"]*age + b_Atr["htn"]*htn + b_Atr["dys"]*dys
      }
      A_k <- rbinom(n, 1, expit(lpA))
    } else {
      A_k <- rep(as.integer(intervene), n)
    }

    lpY <- b_Y["int"] + b_Y["A"]*A_k + b_Y["L"]*L_k +
           b_Y["age"]*age + b_Y["smk"]*smk + b_Y["htn"]*htn + b_Y["dys"]*dys
    Y_k <- rbinom(n, 1, expit(lpY))
    Y_k[!at_risk] <- 0L

    out[[k]] <- data.frame(patient_id = seq_len(n), month = k,
                           age = age, smk = smk, htn = htn, dys = dys,
                           L = L_k, A = A_k, Lprev = L_prev, Aprev = A_prev,
                           Y = Y_k, at_risk = at_risk)

    L_prev  <- L_k
    A_prev  <- A_k
    at_risk <- at_risk & (Y_k == 0)
  }

  d <- do.call(rbind, out)
  d <- d[d$at_risk | d$Y == 1, ]
  d <- d[order(d$patient_id, d$month), ]
  d$at_risk <- NULL
  rownames(d) <- NULL
  d
}

# ------------------------------------------------------------------------------
#  2. 生データ生成用の make_raw 関数 (01_prework.R より)
# ------------------------------------------------------------------------------
add_months <- function(d, n) {
  lt <- as.POSIXlt(d)
  lt$mon <- lt$mon + n
  as.Date(lt)
}

make_raw <- function(n) {
  age_std <- rnorm(n)                          # 内部計算用の標準化年齢
  age     <- round(65 + age_std * 8)           # 実年齢（平均65歳前後）
  sex     <- sample(c("M", "F"), n, replace = TRUE)
  smoking      <- rbinom(n, 1, 0.3)
  hypertension <- rbinom(n, 1, 0.4)
  dyslipidemia <- rbinom(n, 1, 0.4)
  start_date <- as.Date("2021-01-01") + sample(0:180, n, replace = TRUE)

  patients <- data.frame(
    patient_id     = seq_len(n),
    followup_start = start_date,        # フォローアップ開始日
    age            = age,
    sex            = sex,
    smoking        = smoking,
    hypertension   = hypertension,
    dyslipidemia   = dyslipidemia,
    stringsAsFactors = FALSE
  )

  presc_list <- list(); lab_list <- list(); event_list <- list()

  for (i in seq_len(n)) {
    a  <- age_std[i]; sm <- smoking[i]; ht <- hypertension[i]; dy <- dyslipidemia[i]
    L_prev <- 0L; A_prev <- 0L
    day0   <- start_date[i]
    presc_rows <- list(); lab_rows <- list(); event_month <- NA_integer_

    for (k in seq_len(n_int)) {
      month_date <- add_months(day0, k - 1)

      # HbA1c（実値）
      if (k == 1) {
        lpL <- b_L0["int"] + b_L0["age"]*a + b_L0["smk"]*sm + b_L0["htn"]*ht + b_L0["dys"]*dy
      } else {
        lpL <- b_Ltr["int"] + b_Ltr["Lprev"]*L_prev + b_Ltr["Astate"]*A_prev +
               b_Ltr["age"]*a + b_Ltr["smk"]*sm + b_Ltr["htn"]*ht + b_Ltr["dys"]*dy
      }
      L_k <- rbinom(1, 1, expit(lpL))
      hba1c <- if (L_k == 1) round(7.5 + abs(rnorm(1, 0.4, 0.3)), 1)
               else          pmin(7.4, round(7.5 - abs(rnorm(1, 0.5, 0.3)), 1))
      lab_rows[[k]] <- data.frame(patient_id = i, date = month_date, hba1c = hba1c)

      # 増量状態（A_state）を生成
      if (k == 1) {
        lpA <- b_A1["int"] + b_A1["L"]*L_k + b_A1["age"]*a + b_A1["htn"]*ht + b_A1["dys"]*dy
      } else {
        lpA <- b_Atr["int"] + b_Atr["Aprev"]*A_prev + b_Atr["L"]*L_k +
               b_Atr["age"]*a + b_Atr["htn"]*ht + b_Atr["dys"]*dy
      }
      A_k <- rbinom(1, 1, expit(lpA))

      # 用量：増量状態なら 1000mg 以上（幅を持たせる）、非増量なら 500mg（時々減量/中止）
      if (A_k == 1) {
        dose <- sample(c(1000L, 1250L, 1500L), 1, prob = c(0.5, 0.3, 0.2))
      } else {
        r <- runif(1)
        dose <- if (r < 0.10) 0L else if (r < 0.20) 250L else 500L
      }
      presc_rows[[k]] <- data.frame(patient_id = i, date = month_date, metformin_dose = dose)

      # 心血管イベント
      lpY <- b_Y["int"] + b_Y["A"]*A_k + b_Y["L"]*L_k +
             b_Y["age"]*a + b_Y["smk"]*sm + b_Y["htn"]*ht + b_Y["dys"]*dy
      Y_k <- rbinom(1, 1, expit(lpY))

      L_prev <- L_k; A_prev <- A_k
      if (Y_k == 1) { event_month <- k; break }
    }

    presc_list[[i]] <- do.call(rbind, presc_rows)
    lab_list[[i]]   <- do.call(rbind, lab_rows)

    last_k <- if (is.na(event_month)) n_int else event_month
    event_list[[i]] <- data.frame(
      patient_id      = i,
      followup_start  = day0,
      end_date        = add_months(day0, last_k - 1),
      followup_months = last_k,
      cvd_event       = if (is.na(event_month)) 0L else 1L
    )
  }

  list(
    patients      = patients,
    prescriptions = do.call(rbind, presc_list),
    labs          = do.call(rbind, lab_list),
    events        = do.call(rbind, event_list)
  )
}

# ------------------------------------------------------------------------------
#  3. データ生成の実行と保存
# ------------------------------------------------------------------------------
cat("Generating raw observed data (N=1000)...\n")
set.seed(123)  # 再現性のため乱数シードを固定
raw <- make_raw(1000)

patients      <- raw$patients
prescriptions <- raw$prescriptions
labs          <- raw$labs
events        <- raw$events

# 保存先相対パスの設定
if (dir.exists("scripts")) {
  data_dir <- "data"
} else if (dir.exists("../scripts")) {
  data_dir <- "../data"
} else {
  data_dir <- "data"
}

if (!dir.exists(data_dir)) {
  dir.create(data_dir, recursive = TRUE)
}
raw_dir <- file.path(data_dir, "raw_tables")
if (!dir.exists(raw_dir)) {
  dir.create(raw_dir, recursive = TRUE)
}

# CSV形式で保存（生データは raw_tables に保存）
write.csv(patients,      file.path(raw_dir, "patients.csv"),      row.names = FALSE)
write.csv(prescriptions, file.path(raw_dir, "prescriptions.csv"), row.names = FALSE)
write.csv(labs,          file.path(raw_dir, "labs.csv"),          row.names = FALSE)
write.csv(events,        file.path(raw_dir, "events.csv"),        row.names = FALSE)

# ------------------------------------------------------------------------------
#  4. 真値の計算と保存
# ------------------------------------------------------------------------------
cat("Calculating true causal effect (N=200000)...\n")
N_big <- 200000
d_all1 <- generate_data_for_truth(N_big, intervene = 1, seed = 111)  # 常に増量
d_all0 <- generate_data_for_truth(N_big, intervene = 0, seed = 111)  # 常に据置

risk_always_up   <- length(unique(d_all1$patient_id[d_all1$Y == 1])) / N_big
risk_always_hold <- length(unique(d_all0$patient_id[d_all0$Y == 1])) / N_big
true_rd <- risk_always_up - risk_always_hold

true_values <- data.frame(
  risk_always_up = risk_always_up,
  risk_always_hold = risk_always_hold,
  true_rd = true_rd
)
write.csv(true_values, file.path(data_dir, "true_values.csv"), row.names = FALSE)

cat("Virtual raw data files generated successfully in: ", data_dir, "\n")
cat(sprintf("True Risk Difference: %.3f\n", true_rd))
