# prod環境。手動リリース + 承認3段（ADR-0003）
#
# 実験なのでタスク数は1。実務では2以上にしてAZ冗長を取る
env                = "prod"
desired_count      = 1
cpu                = "1024"
memory             = "2048"
log_retention_days = 90
