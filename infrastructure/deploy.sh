#!/usr/bin/env bash
# ==============================================================================
# Multi-AI-Agent AWS CloudFormation Automated Deployment Script
# ==============================================================================
set -e

STACK_NAME=${1:-"multi-ai-agent-stack"}
REGION=${AWS_REGION:-"us-east-1"}
PROFILE=${AWS_PROFILE:-"443628962478_admin"}
ENV_NAME="prod"

echo "==================================================================="
echo "🚀 Deploying Multi-AI-Agent CloudFormation Stack: $STACK_NAME"
echo "Region:  $REGION"
echo "Profile: $PROFILE"
echo "==================================================================="

# 1. Fetch Default VPC
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=isDefault,Values=true" \
  --query "Vpcs[0].VpcId" \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE")

if [ -z "$VPC_ID" ] || [ "$VPC_ID" == "None" ]; then
  echo "❌ Error: Default VPC not found. Please specify a VPC ID manually."
  exit 1
fi
echo "✅ Detected VPC: $VPC_ID"

# 2. Fetch Subnets
SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=defaultForAz,Values=true" \
  --query "Subnets[*].SubnetId" \
  --output text \
  --region "$REGION" \
  --profile "$PROFILE" | tr '\t' ',')

echo "✅ Detected Subnets: $SUBNET_IDS"

# 3. Read API Keys from environment or local .env
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

# 4. Deploy CloudFormation Stack
echo "⏳ Creating / Updating CloudFormation Stack..."
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
      JenkinsKeyName="jenkins-key" \
  --region "$REGION" \
  --profile "$PROFILE"

echo "==================================================================="
echo "🎉 CloudFormation Deployment Succeeded!"
echo "==================================================================="

# Print Outputs
aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query "Stacks[0].Outputs" \
  --output table
