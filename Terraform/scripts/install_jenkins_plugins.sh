#!/bin/bash

# Exit immediately if any command fails
set -e

# Ensure the script is run with sudo privileges to read the initialAdminPassword file
# if [ "$EUID" -ne 0 ]; then
#   echo "❌ Please run this script with sudo (e.g., sudo ./install_jenkins_plugins.sh)"
#   exit 1
# fi

# ==========================================
# CONFIGURATION
# ==========================================
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"

# Fetch the temporary initialization password created during installation
INITIAL_PASSWORD_FILE="/var/lib/jenkins/secrets/initialAdminPassword"

if [ ! -f "$INITIAL_PASSWORD_FILE" ]; then
    echo "❌ Error: $INITIAL_PASSWORD_FILE not found."
    echo "This script assumes a fresh Jenkins installation that hasn't been set up yet."
    exit 1
fi

ADMIN_PASSWORD=$(cat "$INITIAL_PASSWORD_FILE")

# ==========================================
# PLUGIN DEFINITIONS
# ==========================================
SUGGESTED_PLUGINS=(
    "cloudbees-folder" "antisamy-markup-formatter" "build-timeout" 
    "credentials-binding" "timestamper" "ws-cleanup" "ant" "gradle" 
    "workflow-aggregator" "github-branch-source" "pipeline-stage-view" 
    "git" "subversion" "ssh-slaves" "matrix-auth" "pam-auth" "ldap" 
    "email-ext" "mailer"
)

CUSTOM_PLUGINS=(
    "slack" "sonar" "nodejs" "docker-plugin" "docker-commons" 
    "docker-workflow" "kubernetes" "kubernetes-client-api" 
    "kubernetes-credentials" "kubernetes-cli" 
    "kubernetes-credentials-provider" "prometheus"
)

ALL_PLUGINS=("${SUGGESTED_PLUGINS[@]}" "${CUSTOM_PLUGINS[@]}")

# ==========================================
# EXECUTION STEPS
# ==========================================

echo "====== Starting Headless Jenkins Plugin Installation ======"

# Step 1: Wait for Jenkins to fully boot up and accept connections
echo "⏳ Waiting for Jenkins web service to become responsive..."
until curl -s -o /dev/null -w "%{http_code}" "${JENKINS_URL}/login" | grep -q "200\|403"; do
    sleep 3
done

# Step 2: Download the matching jenkins-cli.jar tool from your instance
echo "📥 Downloading jenkins-cli.jar from ${JENKINS_URL}..."
curl -sS "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" -o jenkins-cli.jar

# Step 3: Install all plugins using the initial admin password
echo "⚙️  Installing ${#ALL_PLUGINS[@]} plugins via CLI..."
java -jar jenkins-cli.jar -s "$JENKINS_URL" \
    -auth "${JENKINS_USER}:${ADMIN_PASSWORD}" \
    install-plugin "${ALL_PLUGINS[@]}" -deploy

# Step 4: Skip the UI Setup Wizard for subsequent restarts
# This prevents Jenkins from asking you to install "Suggested Plugins" via browser
echo "⏭️  Configuring Jenkins to skip the UI Setup Wizard..."
mkdir -p /var/lib/jenkins/updates
echo "2.0" > /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion
chown -R jenkins:jenkins /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

# Step 5: Safe restart Jenkins to register changes
echo "🔄 Restarting Jenkins safely to apply updates..."
java -jar jenkins-cli.jar -s "$QA_JENKINS_URL" \
    -auth "${JENKINS_USER}:${ADMIN_PASSWORD}" \
    safe-restart

# Clean up local CLI utility jar file
rm jenkins-cli.jar

echo "✅ Success! Jenkins is rebooting with all plugins pre-loaded."
echo "👉 You can now log into the web UI using the username 'admin' and the password found in: $INITIAL_PASSWORD_FILE"
