# ==============================================================================
#  MSM・g-formula ハンズオン ／ 本番パート① : MSM（IP weighting）
# ------------------------------------------------------------------------------
#  「作業 → その場で確認」を1ステップとして、上から順に進めます。
#  各見出しが、そのステップで何をする／何を確かめるところかを示します。
#
#  データ：data/person_interval.csv（事前課題で生データから畳み込んだもの）
#    metformin_high = その月に増量状態にあるか（初期用量より高い用量で治療中）＝治療 A
#    hba1c_high     = その月の HbA1c 7.5%以上か ＝時間依存交絡 L
#    cvd_event      = その月の心血管イベント ＝アウトカム Y
#    *_prev         = 前月の値（履歴）
# ==============================================================================

# --- パッケージの準備（未インストールなら自動インストール）---
required_pkgs <- c("ggplot2", "cobalt", "sandwich")
new_pkgs <- required_pkgs[!sapply(required_pkgs, requireNamespace, quietly = TRUE)]
if (length(new_pkgs) > 0) {
  cat(sprintf("以下のパッケージをインストールします: %s\n", paste(new_pkgs, collapse = ", ")))
  install.packages(new_pkgs, repos = "https://cran.r-project.org")
}
library(ggplot2)
library(cobalt)
library(sandwich)

# ==============================================================================
#  ステップ0：データを読み込む
# ==============================================================================
if (file.exists("data/person_interval.csv")) {
  dat <- read.csv("data/person_interval.csv")
} else if (file.exists("../data/person_interval.csv")) {
  dat <- read.csv("../data/person_interval.csv")
} else {
  stop("data/person_interval.csv が見つかりません。")
}
n_int <- max(dat$month)
dat$age_z <- (dat$age - mean(dat$age)) / sd(dat$age)   # 年齢は標準化
dat <- dat[order(dat$patient_id, dat$month), ]
cat(sprintf("データ: %d 行, %d 人, 増量状態割合 %.3f\n\n",
            nrow(dat), length(unique(dat$patient_id)), mean(dat$metformin_high)))
