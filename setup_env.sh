#!/bin/bash
#
# 这是一个用于交互式生成 docker-compose 所需的 .env 文件的脚本。
# 它会自动检测并建议默认值，然后询问是否立即构建 Docker 镜像。

# 设置脚本在遇到错误时立即退出
set -e

# --- 辅助函数，用于提示用户输入 ---
# 功能: 向用户询问一个值，并提供一个默认值。
# 用法: user_input=$(prompt_for_var "变量名" "描述" "默认值")
prompt_for_var() {
    local var_name="$1"
    local description="$2"
    local default_value="$3"
    local user_input

    # 使用 read -p 显示提示信息，包括描述和默认值
    read -p "$description [$default_value]: " user_input

    # 如果用户直接按 Enter (输入为空)，则使用默认值
    echo "${user_input:-$default_value}"
}
# --- 检查 .env 文件是否存在 ---
if [ -f ".env" ]; then
    # -n 1 表示读取一个字符后立即返回，-r 表示禁止反斜杠转义
    read -p ".env 文件已存在。您想覆盖它吗？ (y/N): " -n 1 -r
    echo # 输出一个换行符，使输出更美观
    # 使用正则表达式检查用户的输入是否为 'y' 或 'Y'
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消。"
        exit 1
    fi
fi

echo "--- 正在为 docker-compose 生成 .env 文件 ---"
echo "请输入以下值。按 Enter 键接受默认值。"
echo

# --- 获取各项配置的默认值 ---

# CUDA_VERSION: 尝试从 nvidia-smi 获取，如果命令不存在则留空
DEFAULT_CUDA_VERSION=""
if command -v nvidia-smi &> /dev/null; then
    # 提取 nvidia-smi 中的 CUDA 版本，如 "12.1"
    raw_version=$(nvidia-smi | sed -n 's/.*CUDA Version: \([0-9.]\+\).*/\1/p' | tr -d '[:space:]')
    if [[ "$raw_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        # 如果版本是 x.y 格式（如 12.1），自动补全为 x.y.0（如 12.1.0）
        DEFAULT_CUDA_VERSION="${raw_version}.0"
    elif [[ "$raw_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # 如果已经是 x.y.z 格式，直接使用
        DEFAULT_CUDA_VERSION="$raw_version"
    else
        # 无法解析
        DEFAULT_CUDA_VERSION=""
    fi
fi

# 检查是否成功获取版本号，如果失败则提供一个通用示例
if [ -z "$DEFAULT_CUDA_VERSION" ]; then
    echo "警告: 未能通过 nvidia-smi 自动检测到 CUDA 版本。请手动输入。"
    DEFAULT_CUDA_VERSION="12.1.0" 
fi


# USER_NAME, USER_UID, USER_GID: 从当前用户环境中获取
DEFAULT_USER_NAME=${USER:-$(whoami)}
DEFAULT_USER_UID=$(id -u)
DEFAULT_USER_GID=$(id -g)

# REPO_NAME: 使用当前目录的名称
DEFAULT_REPO_NAME=$(basename "$PWD")

# 其他来自 docker-compose.yml 的默认值
DEFAULT_SHM_SIZE="32g"
DEFAULT_NVIDIA_VISIBLE_DEVICES="all"
DEFAULT_UBUNTU_MIRROR="https://mirrors.bfsu.edu.cn/ubuntu/"
DEFAULT_PYPI_MIRROR="https://mirrors.aliyun.com/pypi/simple/"
DEFAULT_HUGGINGFACE_MIRROR="https://hf-mirror.com"


# --- 逐个提示用户输入 ---

CUDA_VERSION=$(prompt_for_var "CUDA_VERSION" "请输入 CUDA 版本 (例如: 12.1.0). 查看可用版本: https://hub.docker.com/r/nvidia/cuda/tags" "$DEFAULT_CUDA_VERSION")
USER_NAME=$(prompt_for_var "USER_NAME" "请输入您的用户名" "$DEFAULT_USER_NAME")
USER_UID=$(prompt_for_var "USER_UID" "请输入您的用户 ID (UID)" "$DEFAULT_USER_UID")
USER_GID=$(prompt_for_var "USER_GID" "请输入您的用户组 ID (GID)" "$DEFAULT_USER_GID")
REPO_NAME=$(prompt_for_var "REPO_NAME" "请输入仓库/项目名称" "$DEFAULT_REPO_NAME")
SHM_SIZE=$(prompt_for_var "SHM_SIZE" "请输入共享内存大小" "$DEFAULT_SHM_SIZE")
NVIDIA_VISIBLE_DEVICES=$(prompt_for_var "NVIDIA_VISIBLE_DEVICES" "请输入可见的 NVIDIA 设备" "$DEFAULT_NVIDIA_VISIBLE_DEVICES")
UBUNTU_MIRROR=$(prompt_for_var "UBUNTU_MIRROR" "请输入 Ubuntu 镜像地址" "$DEFAULT_UBUNTU_MIRROR")
PYPI_MIRROR=$(prompt_for_var "PYPI_MIRROR" "请输入 PyPI 镜像地址" "$DEFAULT_PYPI_MIRROR")
HUGGINGFACE_MIRROR=$(prompt_for_var "HUGGINGFACE_MIRROR" "请输入 Hugging Face 镜像地址" "$DEFAULT_HUGGINGFACE_MIRROR")

# --- 将收集到的变量写入 .env 文件 ---

# 使用 heredoc (here document) 格式，可以方便地写入多行文本
cat > .env << EOL
# Docker Compose 环境变量文件
# 生成于: $(date)

# Devcontainer 镜像使用的 CUDA 版本
CUDA_VERSION=${CUDA_VERSION}

# 用户配置
USER_NAME=${USER_NAME}
USER_UID=${USER_UID}
USER_GID=${USER_GID}

# 用于挂载的仓库/项目名称
REPO_NAME=${REPO_NAME}

# Docker 运行时设置
SHM_SIZE=${SHM_SIZE}
NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES}

# 用于加速下载的镜像源设置
UBUNTU_MIRROR=${UBUNTU_MIRROR}
PYPI_MIRROR=${PYPI_MIRROR}
HUGGINGFACE_MIRROR=${HUGGINGFACE_MIRROR}
EOL

echo
echo ".env 文件已成功创建！"

mkdir -p ~/.cache/huggingface ~/.cache/uv ~/.cache/torch/hub/ ~/.local/share/uv/

# --- 询问用户是否要立即构建 Docker 镜像 ---
echo
read -p "您想现在就执行 'docker compose build' 来构建镜像吗？ (y/N): " -n 1 -r
echo # 输出一个换行符
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "--- 正在执行 docker compose build ---"
    # 检查 docker compose 命令是否存在
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        docker compose build
        echo "--- 构建完成 ---"
    else
        echo "错误: 未找到 'docker compose' 命令。请确保 Docker 已正确安装并正在运行。"
        exit 1
    fi
else
    echo "操作完成。您可以稍后手动运行 'docker compose build'。"
fi
