#!/bin/bash

# =============================================================================
# Claude Relay Service - 快速部署脚本
# =============================================================================
#
# 使用方法:
#   1. 本地导出数据: ./deploy.sh export
#   2. 服务器部署:   ./deploy.sh deploy
#   3. 导入数据:     ./deploy.sh import
#   4. 完整流程:     ./deploy.sh all
#
# =============================================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
BACKUP_FILE="production-backup-$(date +%Y%m%d-%H%M%S).json"
PROJECT_DIR="/opt/claude-relay"
DOCKER_COMPOSE="docker-compose"

# 打印函数
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 未安装,请先安装"
        exit 1
    fi
}

# 导出本地数据
export_data() {
    print_header "导出本地数据"

    if [ ! -f "scripts/data-transfer-enhanced.js" ]; then
        print_error "找不到数据导出脚本,请确保在项目根目录运行"
        exit 1
    fi

    print_info "开始导出数据..."
    node scripts/data-transfer-enhanced.js export --output="$BACKUP_FILE"

    if [ -f "$BACKUP_FILE" ]; then
        print_success "数据导出成功: $BACKUP_FILE"
        print_info "文件大小: $(du -h $BACKUP_FILE | cut -f1)"
    else
        print_error "数据导出失败"
        exit 1
    fi
}

# 部署到服务器
deploy_to_server() {
    print_header "部署服务到服务器"

    # 检查 Docker
    check_command docker
    check_command docker-compose

    # 创建必要的目录
    print_info "创建项目目录..."
    sudo mkdir -p "$PROJECT_DIR"/{logs,data,redis_data}
    sudo chown -R $(id -u):$(id -g) "$PROJECT_DIR"

    # 复制配置文件
    if [ -f ".env.production" ]; then
        print_info "复制生产环境配置..."
        cp .env.production "$PROJECT_DIR/.env"
        print_success "配置文件已复制"
    else
        print_warning "未找到 .env.production,请手动配置 $PROJECT_DIR/.env"
    fi

    # 复制 docker-compose.yml
    if [ -f "docker-compose.yml" ]; then
        cp docker-compose.yml "$PROJECT_DIR/"
        print_success "Docker Compose 配置已复制"
    else
        print_error "找不到 docker-compose.yml"
        exit 1
    fi

    # 启动服务
    print_info "启动 Docker 服务..."
    cd "$PROJECT_DIR"
    $DOCKER_COMPOSE pull
    $DOCKER_COMPOSE up -d

    # 等待服务启动
    print_info "等待服务启动..."
    sleep 10

    # 检查服务状态
    if $DOCKER_COMPOSE ps | grep -q "Up"; then
        print_success "服务启动成功"
        $DOCKER_COMPOSE ps
    else
        print_error "服务启动失败"
        $DOCKER_COMPOSE logs
        exit 1
    fi

    # 测试健康检查
    print_info "测试服务健康状态..."
    if curl -f http://localhost:3000/health &> /dev/null; then
        print_success "服务健康检查通过"
    else
        print_warning "健康检查失败,请查看日志"
    fi
}

# 导入数据到服务器
import_data() {
    print_header "导入数据到服务器"

    # 查找最新的备份文件
    if [ -z "$1" ]; then
        IMPORT_FILE=$(ls -t production-backup-*.json 2>/dev/null | head -1)
        if [ -z "$IMPORT_FILE" ]; then
            print_error "未找到备份文件,请指定文件名: ./deploy.sh import backup.json"
            exit 1
        fi
    else
        IMPORT_FILE="$1"
    fi

    if [ ! -f "$IMPORT_FILE" ]; then
        print_error "备份文件不存在: $IMPORT_FILE"
        exit 1
    fi

    print_info "使用备份文件: $IMPORT_FILE"

    # 复制备份文件到容器
    print_info "上传备份文件到容器..."
    cd "$PROJECT_DIR"

    # 获取容器名称
    CONTAINER_NAME=$($DOCKER_COMPOSE ps -q claude-relay)
    if [ -z "$CONTAINER_NAME" ]; then
        print_error "服务未运行,请先部署服务"
        exit 1
    fi

    docker cp "$IMPORT_FILE" "$CONTAINER_NAME:/app/backup.json"
    print_success "备份文件已上传"

    # 执行导入
    print_info "开始导入数据..."
    docker exec -it "$CONTAINER_NAME" node scripts/data-transfer-enhanced.js import \
        --input=/app/backup.json \
        --force

    print_success "数据导入完成"

    # 验证导入
    print_info "验证数据导入..."
    docker exec "$CONTAINER_NAME" npm run cli status
}

# 查看服务状态
show_status() {
    print_header "服务状态"

    cd "$PROJECT_DIR" 2>/dev/null || {
        print_error "项目目录不存在: $PROJECT_DIR"
        exit 1
    }

    print_info "Docker 容器状态:"
    $DOCKER_COMPOSE ps

    echo ""
    print_info "服务健康检查:"
    curl -s http://localhost:3000/health | jq . 2>/dev/null || \
        curl -s http://localhost:3000/health

    echo ""
    print_info "最近日志:"
    $DOCKER_COMPOSE logs --tail=20 claude-relay
}

# 查看日志
show_logs() {
    print_header "服务日志"

    cd "$PROJECT_DIR" 2>/dev/null || {
        print_error "项目目录不存在: $PROJECT_DIR"
        exit 1
    }

    $DOCKER_COMPOSE logs -f claude-relay
}

# 停止服务
stop_service() {
    print_header "停止服务"

    cd "$PROJECT_DIR" 2>/dev/null || {
        print_error "项目目录不存在: $PROJECT_DIR"
        exit 1
    }

    $DOCKER_COMPOSE down
    print_success "服务已停止"
}

# 重启服务
restart_service() {
    print_header "重启服务"

    cd "$PROJECT_DIR" 2>/dev/null || {
        print_error "项目目录不存在: $PROJECT_DIR"
        exit 1
    }

    $DOCKER_COMPOSE restart
    print_success "服务已重启"
}

# 完整部署流程
deploy_all() {
    print_header "完整部署流程"

    # 1. 导出数据
    export_data

    # 2. 部署服务
    deploy_to_server

    # 3. 导入数据
    import_data "$BACKUP_FILE"

    # 4. 显示状态
    show_status

    print_success "部署完成!"
    print_info "访问 Web 界面: http://localhost:3000/web"
    print_info "查看日志: ./deploy.sh logs"
}

# 显示帮助
show_help() {
    cat << EOF
Claude Relay Service - 部署脚本

用法: ./deploy.sh <command> [options]

命令:
  export              导出本地数据
  deploy              部署服务到服务器
  import [file]       导入数据 (可选指定备份文件)
  all                 执行完整部署流程 (export + deploy + import)
  status              查看服务状态
  logs                查看服务日志
  restart             重启服务
  stop                停止服务
  help                显示帮助信息

示例:
  # 导出数据
  ./deploy.sh export

  # 部署服务
  ./deploy.sh deploy

  # 导入数据 (使用最新备份)
  ./deploy.sh import

  # 导入指定备份
  ./deploy.sh import production-backup-20250101.json

  # 完整部署流程
  ./deploy.sh all

  # 查看状态
  ./deploy.sh status

  # 查看日志
  ./deploy.sh logs
EOF
}

# 主函数
main() {
    case "${1:-}" in
        export)
            export_data
            ;;
        deploy)
            deploy_to_server
            ;;
        import)
            import_data "$2"
            ;;
        all)
            deploy_all
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        restart)
            restart_service
            ;;
        stop)
            stop_service
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
