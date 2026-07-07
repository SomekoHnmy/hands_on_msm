# ==============================================================================
#  MSM・g-formula ハンズオン ／ 事前課題①：time-person データの作成
# ------------------------------------------------------------------------------
#  テーマ： バラバラの生データ（4つのテーブル）を読み込み、
#           月ごとに1行の person-interval（person-time）データへ畳み込む
# ==============================================================================

# 実行時のワーキングディレクトリ（プロジェクトルートか、scripts/ ディレクトリか）に応じて
# 相対パスを自動的に切り替えます。
if (dir.exists("data/raw_tables")) {
  data_dir <- "data/raw_tables"
  out_dir <- "data"
} else if (dir.exists("../data/raw_tables")) {
  data_dir <- "../data/raw_tables"
  out_dir <- "../data"
} else {
  stop("data/raw_tables ディレクトリが見つかりません。ワーキングディレクトリを確認してください。")
}

patients      <- read.csv(file.path(data_dir, "patients.csv"))
prescriptions <- read.csv(file.path(data_dir, "prescriptions.csv"))
labs          <- read.csv(file.path(data_dir, "labs.csv"))
events        <- read.csv(file.path(data_dir, "events.csv"))

cat("=== データの読み込み完了 ===\n")
cat("■ patients（患者マスタ）先頭5行:\n")
print(head(patients, 5), row.names = FALSE)
cat("\n■ prescriptions（処方ログ）先頭8行:\n")
print(head(prescriptions, 8), row.names = FALSE)
cat("\n■ labs（検査ログ）先頭8行:\n")
print(head(labs, 8), row.names = FALSE)
cat("\n■ events（イベントログ）先頭5行:\n")
print(head(events, 5), row.names = FALSE)
cat("\n")

# ==============================================================================
#  生データを月次 person-interval に畳み込む
# ==============================================================================
# --- 【Tip】person-time データと区間の「左閉右開」について ---
#  person-time データでは、各行が「ある時間区間」を表します。区間は
#  慣習的に [start, stop) の左閉右開（left-closed, right-open）で扱います。
#  つまり start 時点は含み、stop 時点は含まない。month=k の行は、
#  内部的には区間 [k-1, k) に対応すると考えると分かりやすいです。
#  こうすると、ある時点がちょうど一つの区間にだけ属し、区間の境目で
#  イベントや打ち切りを二重に数えたり取りこぼしたりするのを防げます。
#
#  今回はデータが月単位できれいに揃っているので、month を 1,2,…,6 の
#  整数ラベルで持つだけで十分で、この点を意識しなくても正しく解析できます。
#  ただし将来、日単位など不揃いな時間で person-time を自作するときは、
#  この左閉右開の規約を意識しないと境界でのズレが起こり得ます。

# --- metformin_high：その月に「増量状態にあるか」を 0/1 に単純化 ---
#
#  ★簡略化その1：治療を「増量状態にある（初期用量 500mg より高い用量で治療中）／初期用量のまま」
#    の二値にまとめています。
#    現実には、据え置き・減量・中止・再開など、治療の動きは多様です。
#    しかし今回は「その月の用量が初期用量 500mg より高いか（metformin_high）」だけに注目し、
#    それ以外（据え置き・減量・中止）はすべて 0 にまとめます。
#    これは、time-varying な治療の交絡という「本質」を最もシンプルな
#    形で見るための、教材上の意図的な単純化です。二値にすることで後の MSM・g-formula の
#    仕組みがぐっと追いやすくなります。

build_person_interval <- function(patients, prescriptions, labs, events) {
  rows <- list()

  for (i in patients$patient_id) {
    ev <- events[events$patient_id == i, ]
    pr <- prescriptions[prescriptions$patient_id == i, ]
    lb <- labs[labs$patient_id == i, ]
    n_months <- nrow(pr)

    pr <- pr[order(pr$date), ]
    lb <- lb[order(lb$date), ]

    for (m in seq_len(n_months)) {
      # 増量状態：その月の用量が初期用量 500 より高いか
      metformin_high <- as.integer(pr$metformin_dose[m] > 500)
      # 【実務注記】このシミュレーションデータでは「心血管イベントが発生した月にログが止まる」
      # というデータ生成側の都合を利用したショートカットを行っています。
      # 実データ解析では、イベント発生日と各月区間の日付を正確に突き合わせてフラグを作成する必要があります。
      cvd <- if (m == n_months && ev$cvd_event == 1) 1L else 0L

      rows[[length(rows) + 1]] <- data.frame(
        patient_id     = i,
        month          = m,
        hba1c          = lb$hba1c[m],
        metformin_dose = pr$metformin_dose[m],
        metformin_high = metformin_high,
        cvd_event      = cvd
      )
    }
  }

  pi <- do.call(rbind, rows)
  pi <- merge(pi, patients, by = "patient_id", all.x = TRUE)
  # 【注記】patients マスタには sex（性別）が含まれています。本シミュレーションのデータ生成ロジック(DGP)では
  # 実質的に非交絡ですが、実務の慣例に合わせ、かつ「なぜ性別は調整しないのか」という疑問に配慮し、
  # 時間非依存交絡（baseline 共変量）として以降のすべての解析モデルに含めて調整を行っています。
  pi <- pi[order(pi$patient_id, pi$month), ]

  # --- 時間依存交絡を二値化：HbA1c が 7.5% 以上か ---
  #
  #  ★簡略化その2：時間依存交絡である HbA1c を「7.5%以上(1)／未満(0)」の
  #    二値に落とします。生データでは HbA1c は実測値（連続値）で持っていますが、
  #    ここで二値化します。
  #    現実の解析では HbA1c を連続値のまま扱うこともでき、そのほうが情報を
  #    多く使えます。今回あえて二値にするのは、
  #      ・重み（MSM）や共変量モデル（g-formula）の計算が追いやすくなる
  #      ・「HbA1c が高い／低い」という二群の対比が直感的に見える
  #    という教材上の理由からです。連続値への一般化は、二値版を理解した後の
  #    自然な発展になります。

  pi$hba1c_high <- as.integer(pi$hba1c >= 7.5)

  # 履歴変数（前月の値）を作る
  pi$hba1c_high_prev      <- ave(pi$hba1c_high,      pi$patient_id, FUN = function(x) c(0L, head(x, -1)))
  pi$metformin_high_prev  <- ave(pi$metformin_high,  pi$patient_id, FUN = function(x) c(0L, head(x, -1)))

  rownames(pi) <- NULL
  pi
}

person_interval <- build_person_interval(patients, prescriptions, labs, events)

cat("=== person-interval データに畳み込みました ===\n")
cat(sprintf(
  "行数: %d 行, 患者数: %d 人\n\n",
  nrow(person_interval), length(unique(person_interval$patient_id))
))

# CSV 書き出し（出力先は data ディレクトリ直下）
output_path <- file.path(out_dir, "person_interval.csv")
write.csv(person_interval, output_path, row.names = FALSE)
cat(sprintf("畳み込み済みデータを書き出しました: %s\n", output_path))
