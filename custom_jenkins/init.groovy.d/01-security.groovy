import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

println "--> Configuring Jenkins Admin User and Security..."

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
def adminUser = hudsonRealm.createAccount("admin", "admin123")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
println "--> Security configuration successfully applied (User: admin / admin123)."
