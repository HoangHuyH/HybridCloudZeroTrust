#!/bin/bash
#====================================================================
# BUILD AND PUSH DOCKER IMAGE FOR DEMO APP
# Author: ZTA Capstone Project Team
#====================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
IMAGE_NAME="haothandong/zta-demo"
IMAGE_TAG="4.0"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
APP_DIR="/home/deployer/ZTAproject/projectfinal/k8s/app"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   BUILD & PUSH DOCKER IMAGE           ${NC}"
echo -e "${BLUE}========================================${NC}"

# Navigate to app directory
cd $APP_DIR
echo -e "\n${YELLOW}📂 Working directory: $(pwd)${NC}"

# Build image
echo -e "\n${YELLOW}[1/2] Building Docker image: ${FULL_IMAGE}${NC}"
docker build -t $FULL_IMAGE .

echo -e "${GREEN}✓ Build thành công!${NC}"

# Push image
echo -e "\n${YELLOW}[2/2] Pushing to Docker Hub...${NC}"
echo -e "⚠️  Đảm bảo bạn đã login: docker login"
docker push $FULL_IMAGE

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   HOÀN TẤT!                           ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Image: ${BLUE}${FULL_IMAGE}${NC}"
echo -e "\n${YELLOW}Bước tiếp theo:${NC}"
echo -e "  1. Copy files lên master node:"
echo -e "     ${BLUE}scp -i mykey1.pem -r /home/deployer/ZTAproject/projectfinal ubuntu@172.10.0.190:~/${NC}"
echo -e "  2. SSH vào master và chạy deploy:"
echo -e "     ${BLUE}ssh -i mykey1.pem ubuntu@172.10.0.190${NC}"
echo -e "     ${BLUE}chmod +x ~/projectfinal/scripts/deploy-complete.sh${NC}"
echo -e "     ${BLUE}~/projectfinal/scripts/deploy-complete.sh${NC}"
