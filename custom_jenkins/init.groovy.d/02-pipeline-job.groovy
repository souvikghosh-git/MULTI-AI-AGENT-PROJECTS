import jenkins.model.*
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import hudson.plugins.git.*

def instance = Jenkins.getInstance()
def jobName = "multi-ai-agent-pipeline"
def repoUrl = "https://github.com/souvikghosh-git/MULTI-AI-AGENT-PROJECTS.git"
def branch = "*/main"
def scriptPath = "Jenkinsfile"

println "--> Creating / Updating Pipeline Job: ${jobName}..."

def job = instance.getItem(jobName)
if (job == null) {
    job = instance.createProject(WorkflowJob.class, jobName)
}

def userRemoteConfigs = [new UserRemoteConfig(repoUrl, null, null, null)]
def branches = [new BranchSpec(branch)]
def gitSCM = new GitSCM(userRemoteConfigs, branches, false, [], null, null, [])

def flowDefinition = new CpsScmFlowDefinition(gitSCM, scriptPath)
flowDefinition.setLightweight(true)
job.setDefinition(flowDefinition)

job.save()
instance.save()
println "--> Pipeline Job '${jobName}' configured successfully from Git SCM!"
