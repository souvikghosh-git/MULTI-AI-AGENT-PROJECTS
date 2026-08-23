import jenkins.model.*
import hudson.plugins.sonar.*
import hudson.plugins.sonar.utils.*
import hudson.tools.*

def instance = Jenkins.getInstance()

println "--> Configuring SonarQube Scanner Tool and Global Configuration..."

// 1. Configure SonarQube Scanner Tool Installation
def descriptor = instance.getDescriptorByType(SonarRunnerInstallation.DescriptorImpl.class)
def installations = descriptor.getInstallations() as List

def toolName = "Sonarqube"
def existingTool = installations.find { it.name == toolName }

if (!existingTool) {
    def autoInstaller = new SonarRunnerInstaller("5.0.1.3006")
    def prop = new InstallSourceProperty([autoInstaller])
    def installation = new SonarRunnerInstallation(toolName, null, [prop])
    installations.add(installation)
    descriptor.setInstallations(installations as SonarRunnerInstallation[])
    descriptor.save()
    println "--> SonarQube Scanner Tool '${toolName}' auto-installer registered."
}

// 2. Configure SonarQube Server Connection
def sonarDescriptor = instance.getDescriptorByType(SonarGlobalConfiguration.class)
def serverName = "Sonarqube"
def serverUrl = "http://sonarqube-dind:9000"
def existingServer = sonarDescriptor.getInstallations().find { it.name == serverName }

if (!existingServer) {
    def sonarInstallation = new SonarInstallation(
        serverName,
        serverUrl,
        null, // credentialsId
        null, // secret
        null, // webhookSecretId
        null, // additionalAnalysisProperties
        null  // additionalProperties
    )
    sonarDescriptor.setInstallations((sonarDescriptor.getInstallations() ?: []) + [sonarInstallation] as SonarInstallation[])
    sonarDescriptor.save()
    println "--> SonarQube Global Server '${serverName}' (${serverUrl}) registered."
}

instance.save()
println "--> SonarQube tool and server configuration completed."
