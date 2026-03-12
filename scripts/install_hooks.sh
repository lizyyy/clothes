#!/usr/bin/env bash
# 文件input：当前 git 仓库配置、`.githooks` 目录结构
# 文件output：core.hooksPath 写入结果与安装状态提示
# 文件pos：仓库级 hook 安装入口脚本
# 一旦我被更新，务必更新我的开头注释，以及所属的文件夹的 ARCH.md。
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath .githooks
echo "[hooks] core.hooksPath=.githooks 已启用"
