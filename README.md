# DevOps Test App

A simple Node.js application deployed to Azure App Service with CI/CD via GitHub Actions.

## 🚀 Live Demo

https://webapp-myapp-dev-1764619174.azurewebsites.net

## 📁 Project Structure

```
├── .github/workflows/
│   └── ci-cd-pipeline.yml    # GitHub Actions CI/CD pipeline
├── src/
│   ├── index.js              # Main application entry point
│   └── index.test.js         # Unit tests
├── infrastructure.sh          # Azure infrastructure setup (Bash)
├── monitoring-setup.ps1       # Azure Monitor setup (PowerShell)
├── package.json
└── README.md
```

## 🛠️ Prerequisites

- [Node.js 22+](https://nodejs.org/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Git Bash](https://git-scm.com/) or WSL (for running bash scripts on Windows)

## 🏗️ Infrastructure Setup

### 1. Create Azure Resources

```bash
# Login to Azure
az login

# Run infrastructure script (creates Resource Group, App Service Plan, Web App)
bash infrastructure.sh
```

### 2. Configure GitHub OIDC Authentication

```bash
# Create app registration
az ad app create --display-name "github-actions-deploy"

# Create service principal
az ad sp create --id <APP_ID>

# Assign Contributor role
az role assignment create --assignee <APP_ID> --role "Contributor" --scope "/subscriptions/<SUB_ID>/resourceGroups/rg-myapp-dev"

# Add federated credentials for GitHub Actions
az ad app federated-credential create --id <APP_OBJECT_ID> --parameters '{
  "name": "github-main-branch",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<OWNER>/<REPO>:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"]
}'

az ad app federated-credential create --id <APP_OBJECT_ID> --parameters '{
  "name": "github-environment-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<OWNER>/<REPO>:environment:production",
  "audiences": ["api://AzureADTokenExchange"]
}'
```

### 3. Add GitHub Secrets

Add these secrets to your repository (Settings → Secrets → Actions):

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | App registration client ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

### 4. Setup Monitoring (Optional)

```powershell
.\monitoring-setup.ps1 -ResourceGroupName "rg-myapp-dev" -WebAppName "<WEB_APP_NAME>" -AlertEmailAddress "your-email@example.com"
```

## 💻 Local Development

```bash
# Install dependencies
npm install

# Run locally
npm start

# Run tests
npm test
```

The app runs on http://localhost:8080

## 🔄 CI/CD Pipeline

The GitHub Actions workflow automatically:

1. **Build**: Installs dependencies, runs tests, builds the app
2. **Deploy**: Deploys to Azure Web App on push to `main`

Trigger a deployment by pushing to the `main` branch.

## 📊 Monitoring

The monitoring setup creates:

- **Log Analytics Workspace** - Centralized logging
- **Application Insights** - Performance monitoring
- **Alert Rules**:
  - CPU > 80%
  - Memory > 85%
  - HTTP 5xx errors > 10
  - Response time > 5s

## 🧹 Cleanup

To delete all Azure resources:

```bash
az group delete --name rg-myapp-dev --yes --no-wait
```

## 📝 License

MIT
