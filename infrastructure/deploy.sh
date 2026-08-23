#!/usr/bin/env bash
# ==============================================================================
# Multi-AI-Agent Complete End-to-End Automated AWS Deployment Script
# Provisions CloudFormation Infrastructure, Builds & Pushes Docker Image,
# Deploys ECS Fargate Service, and Boots Jenkins & SonarQube.
# ==============================================================================
set -e

STACK_NAME=${1:-"multi-ai-agent-stack"}
REGION=${AWS_REGION:-"us-east-1"}
PROFILE_ARG=""
if [ -n "$AWS_PROFILE" ]; then
  PROFILE_ARG="--profile $AWS_PROFILE"
fi
ENV_NAME="prod"
KEY_NAME="jenkins-key"

echo "==================================================================="
echo "🚀 1-Click Multi-AI-Agent Deployment Starting..."
echo "Stack:   $STACK_NAME"
echo "Region:  $REGION"
if [ -n "$AWS_PROFILE" ]; then
  echo "Profile: $AWS_PROFILE"
fi
echo "==================================================================="

# 1. Create SSH Key Pair if not already present
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" $PROFILE_ARG >/dev/null 2>&1; then
  echo "🔑 Creating EC2 Key Pair '$KEY_NAME'..."
  rm -f ~/"${KEY_NAME}.pem"
  aws ec2 create-key-pair \
    --key-name "$KEY_NAME" \
    --query "KeyMaterial" \
    --output text \
    --region "$REGION" \
    $PROFILE_ARG > ~/"${KEY_NAME}.pem"
  chmod 400 ~/"${KEY_NAME}.pem"
  echo "✅ Key saved to ~/${KEY_NAME}.pem"
else
  echo "✅ Key Pair '$KEY_NAME' already exists"
fi

# 2. Fetch Default VPC
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region "$REGION" \
  $PROFILE_ARG)

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
  echo "❌ Error: Default VPC not found. Please specify a VPC ID manually."
  exit 1
fi
echo "✅ Detected Default VPC: $VPC_ID"

# 3. Fetch Public Subnets
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=defaultForAz,Values=true" \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region "$REGION" \
  $PROFILE_ARG | tr '\t' ',')

echo "✅ Detected Subnets: $SUBNET_IDS"

# 4. Read API Keys from environment or local .env
if [ -f .env ]; then
  source .env
fi

GROQ_KEY=${GROQ_API_KEY:-""}
TAVILY_KEY=${TAVILY_API_KEY:-""}

if [ -z "$GROQ_KEY" ]; then
  read -sp "Enter your GROQ_API_KEY: " GROQ_KEY
  echo ""
fi

if [ -z "$TAVILY_KEY" ]; then
  read -sp "Enter your TAVILY_API_KEY: " TAVILY_KEY
  echo ""
fi

# 5. Deploy CloudFormation Stack
echo ""
echo "⏳ Step 1/3: Provisioning AWS CloudFormation Infrastructure (5-8 mins)..."
aws cloudformation deploy \
  --template-file infrastructure/cloudformation.yaml \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      EnvironmentName="$ENV_NAME" \
      GroqApiKey="$GROQ_KEY" \
      TavilyApiKey="$TAVILY_KEY" \
      VpcId="$VPC_ID" \
      SubnetIds="$SUBNET_IDS" \
      EcrRepositoryName="my-repo" \
      DeployJenkinsServer="true" \
      JenkinsInstanceType="m7i-flex.large" \
      JenkinsKeyName="$KEY_NAME" \
  --region "$REGION" \
  $PROFILE_ARG

echo "✅ CloudFormation Stack provisioned successfully!"

# 6. Get Stack Outputs
ACCOUNT_ID=$(aws sts get-caller-identity $PROFILE_ARG --query "Account" --output text)
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/my-repo"
CLUSTER_NAME="multi-ai-agent-cluster-${ENV_NAME}"
SERVICE_NAME="multi-ai-agent-service-${ENV_NAME}"

# 7. Build and Push Docker Image to ECR
echo ""
echo "🐳 Step 2/3: Building and Pushing Docker Image to ECR ($ECR_URI)..."
aws ecr get-login-password --region "$REGION" $PROFILE_ARG | docker login --username AWS --password-stdin "$ECR_URI"
docker build -t "${ECR_URI}:latest" .
docker push "${ECR_URI}:latest"
echo "✅ Docker image pushed to ECR!"

# 8. Force ECS Service Update with new image
echo ""
echo "🚀 Step 3/3: Deploying Container to ECS Fargate..."
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --force-new-deployment \
  --region "$REGION" \
  $PROFILE_ARG > /dev/null

echo "⏳ Waiting for ECS task to start running..."
sleep 25

TASK_ARN=$(aws ecs list-tasks \
  --cluster "$CLUSTER_NAME" \
  --service-name "$SERVICE_NAME" \
  --desired-status RUNNING \
  --region "$REGION" \
  $PROFILE_ARG \
  --query "taskArns[0]" --output text 2>/dev/null || echo "")

TASK_IP=""
if [ -n "$TASK_ARN" ] && [ "$TASK_ARN" != "None" ]; then
  ENI_ID=$(aws ecs describe-tasks \
    --cluster "$CLUSTER_NAME" \
    --tasks "$TASK_ARN" \
    --region "$REGION" \
    $PROFILE_ARG \
    --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text)

  TASK_IP=$(aws ec2 describe-network-interfaces \
    --network-interface-ids "$ENI_ID" \
    --region "$REGION" \
    $PROFILE_ARG \
    --query "NetworkInterfaces[0].Association.PublicIp" --output text 2>/dev/null || echo "")
fi

JENKINS_IP=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  $PROFILE_ARG \
  --query "Stacks[0].Outputs[?OutputKey=='JenkinsPublicIp'].OutputValue" --output text 2>/dev/null || echo "")

echo ""
echo "==================================================================="
echo "🎉 DEPLOYMENT COMPLETE & LIVE!"
echo "==================================================================="
if [ -n "$TASK_IP" ] && [ "$TASK_IP" != "None" ]; then
  echo "🖥️  Live Streamlit Web App: http://${TASK_IP}:8501"
  echo "⚡ FastAPI Backend Endpoint: http://${TASK_IP}:9999"
else
  echo "🖥️  Live Web App: Starting up on ECS (check ECS console in 1 min)"
fi

if [ -n "$JENKINS_IP" ] && [ "$JENKINS_IP" != "None" ]; then
  echo "⚙️  Jenkins CI/CD Dashboard: http://${JENKINS_IP}:8080"
  echo "🔍 SonarQube Quality Gate:  http://${JENKINS_IP}:9000"
fi
echo "==================================================================="
