# Get AWS account info
$AWS_ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
$AWS_REGION = "ap-southeast-1"

# Login to ECR
$ECR_PASSWORD = aws ecr get-login-password --region $AWS_REGION
$ECR_PASSWORD | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Build and push each service
$services = @("config-server", "api-gateway", "customers-service", "visits-service", "vets-service")

foreach ($service in $services) {
    Write-Host "Building $service..." -ForegroundColor Green
    
    docker build -f ../docker/Dockerfile `
        --build-arg ARTIFACT_NAME="spring-petclinic-$service-3.2.4" `
        --build-arg EXPOSED_PORT=8080 `
        -t "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/petclinic/${service}:latest" `
        "../spring-petclinic-$service/target"
    
    Write-Host "Pushing $service..." -ForegroundColor Green
    docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/petclinic/${service}:latest"
}

Write-Host "All images pushed to ECR!" -ForegroundColor Cyan

Write-Host "Verifying images.." -ForegroundColor Cyan

foreach ($service in $services) {
    Write-Host "${service}:" -ForegroundColor Yellow
    aws ecr describe-images --repository-name "petclinic/$service" --query "imageDetails | sort_by(@, &imagePushedAt)[-1].imageTags" --output json
}