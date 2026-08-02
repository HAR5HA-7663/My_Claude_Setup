# Key Projects for Applications

Use these projects when answering "tell me about a project" questions. Match project to role type.

## For ML/AI Roles

### Resume Optimizer (QLoRA Fine-tuning)
Fine-tuned Qwen3-4B using QLoRA (4-bit NF4) for resume optimization. Reduced GPU memory to 18-22GB while maintaining quality. Used Hugging Face, PEFT, and custom training pipelines.

### ML Sentiment Analysis Loop (MLOps)
Built end-to-end MLOps pipeline with 8 microservices on Kubernetes. Implemented model training, evaluation, deployment, and monitoring with Prometheus/Grafana. Full CI/CD with automated retraining.

### Traffic Flow Prediction (GNN)
Applied Graph Neural Networks to predict traffic patterns using real-world sensor data. Combined spatial-temporal modeling with attention mechanisms.

### Pneumonia Detection (Computer Vision)
Built CNN-based medical image classifier achieving 92% accuracy. Implemented proper train/val/test splits and model interpretability with Grad-CAM.

## For Backend/SDE Roles

### FieldFuze Backend (Go + AWS)
Built entire backend in Go with 60+ AWS Lambda functions. Integrated Stripe (payments), Twilio (SMS), DocuSign (contracts), QuickBooks (accounting). Serves enterprise clients including Ferrari and Boeing.

### Job Portal API (FastAPI + HATEOAS)
RESTful API with HATEOAS architecture using FastAPI. Implemented proper pagination, filtering, and hypermedia controls. PostgreSQL with SQLAlchemy ORM.

### Lambda Microservices Architecture
Designed and deployed 94 Lambda functions with proper API Gateway configuration, error handling, and monitoring.

## For DevOps/Platform Roles

### Telegram Toxicity Bot (Kubernetes)
Deployed ML-based content moderation bot on EKS. Implemented circuit breakers, autoscaling, and Prometheus monitoring. Full Terraform infrastructure as code.

### Online Learning Portal (CI/CD)
Built Jenkins pipelines for automated testing and deployment. Implemented blue-green deployments and rollback strategies.

## For Full Stack Roles

### FieldFuze Mobile (React Native)
Built React Native app with 104+ components. Implemented offline-first architecture, push notifications, and real-time sync.

### VSCode Portfolio (Next.js)
Personal portfolio styled as VS Code interface. Next.js with TypeScript, responsive design, and animations.

## Quick Match Guide
| Role Type | Lead With |
|-----------|-----------|
| ML Engineer | Resume Optimizer (QLoRA), ML Sentiment Loop |
| Backend SDE | FieldFuze Backend, Job Portal API |
| DevOps/SRE | Telegram Bot (K8s), ML Sentiment Loop |
| Full Stack | FieldFuze (Go + React Native) |
| AI/LLM | Resume Optimizer, CRE Agent (RAG) |
