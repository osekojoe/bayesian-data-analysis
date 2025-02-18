# load libraries ------------------------------------
library(tidyverse)
library(R2jags)
library(coda)
library(readxl)
library(pacman)
library(MCMCvis)
library(mcmcplots)
library(rjags)
library(AICcmodavg)


# Leo's final ---------------------------------------
## data preparation ----
DDKdata <- read.csv("data/bda_data.csv")

DDKdata <- DDKdata  |> 
  arrange(sex, age, naam)

datajags2 <- list(
  n_munic = length(unique(DDKdata$naam)),
  n_munic_arr = array(1:n_munic, dim = c(300, 5, 2)),
  n_age = length(unique(DDKdata$age)),
  n_sex = length(unique(DDKdata$sex)),
  Niag = array(c(DDKdata$invited), dim = c(300, 5, 2)), 
  Yiag = array(c(DDKdata$participant), dim = c(300, 5, 2)),
  male = array(c(DDKdata$male), dim = c(300, 5, 2)),
  age1 = array(c(DDKdata$age1), dim = c(300, 5, 2)),
  age2 = array(c(DDKdata$age2), dim = c(300, 5, 2)),
  age3 = array(c(DDKdata$age3), dim = c(300, 5, 2)),
  age4 = array(c(DDKdata$age4), dim = c(300, 5, 2))
)

## winbugs code ----

sink("model2.txt")
cat("
model {
# Priors
  for (i in 1:n_munic){
    alpha[i] ~ dnorm(mu.int, tau.int) # Intercepts
}
  mu.int ~ dnorm(0, 0.001) # Hyperparameter for random intercepts
  tau.int <- 1 / (sigma.int * sigma.int)
  sigma.int ~ dunif(0, 10)
  
  for (j in 1:n_age) {
    beta[j] ~ dnorm(0, 0.001) # age effects
  }
  
  for (k in 1:n_sex) {
    gamma[k] ~ dnorm(0, 0.001) # sex effects
  }
  
  # Binomial likelihood
  for (i in 1:n_munic) {        # Loop over municipalities
    for (j in 1:n_age) {        # Loop over age groups
      for (k in 1:n_sex) {      # Loop over genders
  Yiag[i,j,k] ~ dbin(pi[i,j,k], Niag[i,j,k])
  logit(pi[i,j,k]) <- alpha[n_munic_arr[i, j, k]] + beta[j]*age1[i,j,k] + 
  beta[j]*age2[i,j,k] + beta[j]*age3[i,j,k] + beta[j]*age4[i,j,k] + 
  gamma[k]*male[i,j,k]
      }
    }
  }
}
", fill = TRUE)
sink()

# Initial values
inits2 <- function() {
  list(
    alpha = rnorm(n_munic, 0, 2),
    beta = rnorm(n_age, 1, 1),
    gamma = rnorm(n_sex, 1, 1),
    mu.int = rnorm(1, 0, 1)
  )
}

params <- c("beta", "gamma", "mu.int", "sigma.int", "pi", "alpha")

## Run the model ----
mod2.fit <- jags(
  data = datajags2,
  inits = inits2,
  parameters.to.save = params,
  model.file = "model2.txt",
  n.chains = 3,
  n.iter = 10000,
  n.burnin = 5000,
  jags.seed = 123,
  quiet = FALSE
)

# print pD and DIC ---------------------------------------
options(max.print=999999)
sink("model2res1.txt")
print(mod2.fit)
sink()

options(max.print=999999)
sink("model2res1.txt")
bayes2mcmc <- as.mcmc(mod2.fit)
summary(bayes2mcmc)
sink()

summary(bayes2mcmc)
## diagnostics ----------------------------------------------
mcmc_samples <- as.mcmc(mod2.fit)

png("pictures/mod2trace.png", width = 18, 
    height = 15, units = "cm", res = 300)
#traceplot(mcmc_samples[, c("alpha[1]", "beta1[1]", "beta1[2]", "beta1[3]", 
#                           "beta1[4]", "gamma1[2]", "mu.int", 
#                           "sigma.int", "alpha[2]", "alpha[3]", "alpha[4]", 
#                           "alpha[5]")])
dev.off()

## library coda -----------------------------------------------
library(coda)

## autocorrelation
autocorr.diag(as.mcmc(mod2.fit))
autocorr.plot(as.mcmc(mod2.fit))

png("pictures/mod2rmean_sigmaint.png", width = 18, 
    height = 10, units = "cm", res = 300)
rmeanplot(as.mcmc(mod2.fit), parms = "sigma.int")
dev.off()

## geweke diag - works
png("pictures/mod2geweke_sigmaint.png", width = 18, 
    height = 10, units = "cm", res = 300)
geweke.plot(as.mcmc(mod2.fit), parms = "sigma.int")
dev.off()

# Heidel diag
heidel.diag(as.mcmc(mod2.fit))

# BGR diagnostics
gelman.diag(as.mcmc(mod2.fit))
gelman.plot(as.mcmc(mod2.fit))

# Raftery-Lewis
raftery.diag(as.mcmc(mod2.fit))

# HW diagnostic
sink("model2heidel.txt")
heidel.diag(as.mcmc(mod2.fit))
sink()

# effective sample size
effectiveSize(as.mcmc(mod2.fit))

### library ggmcmc -----------------------------------------------
library(ggmcmc)
bayes2mcmcggs <- ggs(bayes2mcmc)

png("pictures/mod2trace_muint.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_traceplot(bayes2mcmcggs, family = "mu.int")
dev.off()

png("pictures/mod2autocorr_gamma.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_autocorrelation(bayes2mcmcggs, family = "gamma")
dev.off()

png("pictures/mod2rmean_muint.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_running(bayes2mcmcggs, family = "mu.int")
dev.off()

png("pictures/mod2geweke_sigmaint.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_geweke(bayes2mcmcggs, family = "sigma.int")
dev.off()

png("pictures/mod2gbr_gamma.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_grb(bayes2mcmcggs, family = "gamma")
dev.off()


print(ggs_diagnostics(bayes2mcmcggs, family = "pi"), n=500)

#------------------------------------------------------------------
### Extract posterior samples for pi

# extract chains
ex2 <- MCMCchains(bayes2mcmc, params = 'pi')

# Compute P(pi_i < 0.30) for each column
(probs2 <- apply(ex2, 2, function(x) mean(x < 0.30)))

# Find columns where P(pi_i < 0.30) > 0.9
select2 <- which(probs2 > 0.9)

# Display results
list(
  Columns = select2,
  Probabilities = probs[select2]
)


### --------------------------------------------------------



####################### outliers detection -------------------------------------------------------
# Load posterior samples from JAGS
library(coda)

jags2 <- jags.model(file="model2.txt",
                   data = datajags2,
                   inits = inits2,
                   n.chains = 3)

update(jags2, 5000) # burn-in period

samples <- coda.samples(model = jags2,
                          variable.names = params,
                          n.iter=10000, 
                          thin=5)


### ############## HIERARCHICAL CENTERING ----------------

sink("model22.txt")
cat("
model {
  # Priors
    for (i in 1:n_munic){
      alpha[i] ~ dnorm(mu.int, tau.int) # Intercepts
  }
    mu.int ~ dnorm(0, 0.001) # Hyperparameter for random intercepts
    tau.int <- 1 / (sigma.int * sigma.int)
    sigma.int ~ dunif(0, 10)
  
  for (j in 1:n_age) {
    beta1[j] ~ dnorm(0, 0.001) # age effects
  }
  
  for (k in 1:n_sex) {
    gamma1[k] ~ dnorm(0, 0.001) # sex effects
  }
  
  # Binomial likelihood
  for (i in 1:n_munic) {        # Loop over municipalities
    for (j in 1:n_age) {        # Loop over age groups
      for (k in 1:n_sex) {      # Loop over genders
      
        Yiag[i,j,k] ~ dbin(pi[i,j,k], Niag[i,j,k])
        
        m[i, j, k] <- beta1[j]*age1[i,j,k] + 
        beta1[j]*age2[i,j,k] + beta1[j]*age3[i,j,k] + beta1[j]*age4[i,j,k] + 
        gamma1[k]*male[i,j,k]
      
        n[i, j, k] <- m[i, j, k] + alpha[n_munic_arr[i, j, k]]
        
        logit(pi[i,j,k]) <- n[i, j, k]
      
        #n[i, j, k] ~ dnorm(m[i, j, k], tau)
      }
    }
  }
}
", fill = TRUE)
sink()

inits2 <- function() {
  list(
    alpha = rnorm(n_munic, 0, 2),
    beta1 = rnorm(n_age, 1, 1),
    gamma1 = rnorm(n_sex, 1, 1),
    mu.int = rnorm(1, 0, 1)
  )
}

params <- c("alpha", "beta1", "gamma1", "mu.int", "sigma.int")

## Run the model ----
mod22.fit <- jags(
  data = datajags2,
  inits = inits2,
  parameters.to.save = params,
  model.file = "model22.txt",
  n.chains = 3,
  n.iter = 10000,
  n.burnin = 5000,
  jags.seed = 123,
  quiet = FALSE
)

options(max.print=999999)
sink("model22info.txt")
print(mod22.fit)
sink()

options(max.print=999999)
sink("model22res.txt")
bayes22mcmc <- as.mcmc(mod22.fit)
summary(bayes22mcmc)
sink()

#-------------new model 2 ---------------------------------
datajags23 <- list(
  n_munic = length(unique(DDKdata$naam)),
  #n_munic_arr = array(1:n_munic, dim = c(300, 5, 2)),
  n_age = length(unique(DDKdata$age)),
  n_sex = length(unique(DDKdata$sex)),
  Niag = array(c(DDKdata$invited), dim = c(300, 5, 2)), 
  Yiag = array(c(DDKdata$participant), dim = c(300, 5, 2)),
  male = array(c(DDKdata$male), dim = c(300, 5, 2)),
  age1 = array(c(DDKdata$age1), dim = c(300, 5, 2)),
  age2 = array(c(DDKdata$age2), dim = c(300, 5, 2)),
  age3 = array(c(DDKdata$age3), dim = c(300, 5, 2)),
  age4 = array(c(DDKdata$age4), dim = c(300, 5, 2))
)

sink("model23.txt")
cat("
model {
# Priors
  alpha ~ dnorm(0, 0.01)   # Vague prior for intercept
  
  for (i in 1:n_munic){
    b[i] ~ dnorm(mu, tau)   # Random intercepts
  }
  
  mu ~ dnorm(0, 0.01)
  tau <- 1 / (sigma * sigma)
  sigma ~ dunif(0, 10)
  
  for (j in 1:n_age) {
    beta[j] ~ dnorm(0, 0.001) # Age effects
  }
  
  for (k in 1:n_sex) {
    gamma[k] ~ dnorm(0, 0.001) # Sex effects
  }
  
  # Binomial likelihood
  for (i in 1:n_munic) {        # Loop over municipalities
    for (j in 1:n_age) {        # Loop over age groups
      for (k in 1:n_sex) {      # Loop over genders
        Yiag[i,j,k] ~ dbin(pi[i,j,k], Niag[i,j,k])
        logit(pi[i,j,k]) <- alpha + beta[j]*age1[i,j,k] + 
                          beta[j]*age2[i,j,k] + beta[j]*age3[i,j,k] +
                          beta[j]*age4[i,j,k] + gamma[k]*male[i,j,k] + b[i]
      }
    }
  }
}
", fill = TRUE)
sink()

## Hierarchical centering ----------------------------------------------

DDKdata <- read.csv("data/bda_data.csv")

DDKdata <- DDKdata  |> 
  arrange(sex, age, naam)

datajags2 <- list(
  n_munic = length(unique(DDKdata$naam)),
  n_munic_arr = array(1:n_munic, dim = c(300, 5, 2)),
  n_age = length(unique(DDKdata$age)),
  n_sex = length(unique(DDKdata$sex)),
  Niag = array(c(DDKdata$invited), dim = c(300, 5, 2)), 
  Yiag = array(c(DDKdata$participant), dim = c(300, 5, 2)),
  male = array(c(DDKdata$male), dim = c(300, 5, 2)),
  age1 = array(c(DDKdata$age1), dim = c(300, 5, 2)),
  age2 = array(c(DDKdata$age2), dim = c(300, 5, 2)),
  age3 = array(c(DDKdata$age3), dim = c(300, 5, 2)),
  age4 = array(c(DDKdata$age4), dim = c(300, 5, 2)),
  age5 = array(c(DDKdata$age5), dim = c(300, 5, 2)),
  female = array(c(DDKdata$female), dim = c(300, 5, 2))
)

sink("model2.txt")
cat("
model {
# Priors
  mu ~ dnorm(0, 0.001) # overall mean
  for (i in 1:n_munic){
  b[i] ~ dnorm(0, tau)
  }
  tau <- 1 / (sigma * sigma)
  sigma ~ dunif(0, 1)
  
  # for (i in 1:n_munic){
  #   alpha[i] ~ dnorm(mu.int, tau.int) # Intercepts
#}
  # mu.int ~ dnorm(0, 0.001) # Hyperparameter for random intercepts
  # tau.int <- 1 / (sigma.int * sigma.int)
  # sigma.int ~ dunif(0, 10)
  # 
  # for (j in 1:n_age) {
  #   beta1[j] ~ dnorm(0, 0.001) # age effects
  # }
  # 
  # for (k in 1:n_sex) {
  #   gamma1[k] ~ dnorm(0, 0.001) # sex effects
  # }
  
  # Binomial likelihood
  for (i in 1:n_munic) {        # Loop over municipalities
  logit(pi[i]) <- mu + b[i]
    for (j in 1:n_age) {        # Loop over age groups
      for (k in 1:n_sex) {      # Loop over genders
  Yiag[i,j,k] ~ dbin(pi[i], Niag[i,j,k])
      }
    }
  }
}
", fill = TRUE)
sink()

sink("model2.txt")
cat("
model {
# Priors
  for (i in 1:n_munic){
    # alpha[i] ~ dnorm(mu.int, tau.int) # Intercepts
    b[i] ~ dnorm(mu.int, tau.int)
}
  mu.int ~ dnorm(0, 0.001) # Hyperparameter for random intercepts
  tau.int <- 1 / (sigma.int * sigma.int)
  sigma.int ~ dunif(0, 10)
  
  for (j in 1:n_age) {
    beta1[j] ~ dnorm(0, 0.001) # age effects
  }
  
  for (k in 1:n_sex) {
    gamma1[k] ~ dnorm(0, 0.001) # sex effects
  }
  
  # Binomial likelihood
  for (i in 1:n_munic) {        # Loop over municipalities
    for (j in 1:n_age) {        # Loop over age groups
      for (k in 1:n_sex) {      # Loop over genders
  Yiag[i,j,k] ~ dbin(pi[i,j,k], Niag[i,j,k])
  
  m[i, j, k] <- beta1[j]*age1[i,j,k] + 
  beta1[j]*age2[i,j,k] + beta1[j]*age3[i,j,k] + beta1[j]*age4[i,j,k] + 
  beta1[j]*age5[i,j,k] + gamma1[k]*male[i,j,k] + gamma1[k]*female[i,j,k]
  
  logit(pi[i,j,k]) <-  m[i, j, k] + b[n_munic_arr[i, j, k]]
  }
    }
  }
}
", fill = TRUE)
sink()

# Initial values
# inits2 <- function() {
#   list(
#     mu = rnorm(1, 0.5, 0.1),
#     b = rnorm(n_munic, 0, 1),
#     sigma = runif(1, 0, 1)
#   )
# }

n_munic <- length(unique(DDKdata$naam))
n_age <- length(unique(DDKdata$age))
n_sex <- length(unique(DDKdata$sex))

inits2 <- function() {
  list(
    b = rnorm(n_munic, 0, 2),
    beta1 = rnorm(n_age, 1, 1),
    gamma1 = rnorm(n_sex, 1, 1),
    mu.int = rnorm(1, 0, 1)
  )
}

# params <- c("mu", "b", "pi", "sigma")
params <- c("beta1")

## Run the model ----
mod2.fit <- jags(
  data = datajags2,
  inits = inits2,
  parameters.to.save = params,
  model.file = "model2.txt",
  n.chains = 3,
  n.iter = 10000,
  n.burnin = 5000,
  jags.seed = 123,
  quiet = FALSE
)

traceplot(mod2.fit)

# print pD and DIC ---------------------------------------
options(max.print=999999)
sink("model2_result.txt")
print(mod2.fit)
sink()

# Initial values
inits23 <- function() {
  list(
    alpha = rnorm(n_munic, 0, 2),
    beta = rnorm(n_age, 1, 1),
    gamma = rnorm(n_sex, 1, 1),
    sigma = rnorm(1, 0, 1)
  )
}

inits23 <- function() {
  list(
    alpha = rnorm(1, 0, 2),               # Single intercept parameter
    beta = rnorm(n_age, 0, 1),           # Age effects (vector of size n_age)
    gamma = rnorm(n_sex, 0, 1),          # Sex effects (vector of size n_sex)
    b = rnorm(n_munic, 0, 1),            # Random intercepts for municipalities
    tau = rgamma(1, 0.001, 0.001)        # Precision for random intercepts
  )
}


params23 <- c("alpha", "beta", "gamma", "sigma", "mu")

mod23.fit <- jags.model(file="model23.txt",
                               data = datajags23,
                               n.chains = 3,
                        n.adapt=1000)
update(mod23.fit,5000)
model23.sim <- coda.samples(model = mod23.fit,
                           variable.names = params23,
                           n.iter=10000, 
                           thin=1)

sink("model23res.txt")
summary(model23.sim)
sink()

rmeanplot(model23.sim)
traceplot(model23.sim)
par("mar")
par(mar=c(1,1,1,1))
geweke.plot(model23.sim)
gelman.plot(model23.sim)
heidel.diag(model23.sim)
raftery.diag(model23.sim)

## Run the model ----
mod23.fit <- jags(
  data = datajags23,
  #inits = inits23,
  parameters.to.save = params23,
  model.file = "model23.txt",
  n.chains = 3,
  n.iter = 10000,
  n.burnin = 5000,
  jags.seed = 123,
  quiet = FALSE
)


#-------------Joe version model 2 ---------------------------------

datajags23 <- list(
  n_munic = length(unique(DDKdata$naam)),
  #n_munic_arr = array(1:n_munic, dim = c(300, 5, 2)),
  n_age = length(unique(DDKdata$age)),
  n_sex = length(unique(DDKdata$sex)),
  Niag = array(c(DDKdata$invited), dim = c(300, 5, 2)), 
  Yiag = array(c(DDKdata$participant), dim = c(300, 5, 2)),
  male = array(c(DDKdata$male), dim = c(300, 5, 2)),
  age1 = array(c(DDKdata$age1), dim = c(300, 5, 2)),
  age2 = array(c(DDKdata$age2), dim = c(300, 5, 2)),
  age3 = array(c(DDKdata$age3), dim = c(300, 5, 2)),
  age4 = array(c(DDKdata$age4), dim = c(300, 5, 2))
)

sink("model23.txt")
cat("
model {
# Priors
  alpha ~ dnorm(0, 0.01)   # Vague prior for intercept
  
  for (i in 1:n_munic){
    b[i] ~ dnorm(mu, tau)   # Random intercepts
  }
  
  mu ~ dnorm(0, 0.01)
  tau <- 1 / (sigma * sigma)
  sigma ~ dunif(0, 10)
  
  for (j in 1:n_age) {
    beta[j] ~ dnorm(0, 0.001) # Age effects
  }
  
  for (k in 1:n_sex) {
    gamma[k] ~ dnorm(0, 0.001) # Sex effects
  }
  
  # Binomial likelihood
  for (i in 1:n_munic) {        # Loop over municipalities
    for (j in 1:n_age) {        # Loop over age groups
      for (k in 1:n_sex) {      # Loop over genders
        Yiag[i,j,k] ~ dbin(pi[i,j,k], Niag[i,j,k])
        logit(pi[i,j,k]) <- alpha + beta[j]*age1[i,j,k] + 
                          beta[j]*age2[i,j,k] + beta[j]*age3[i,j,k] +
                          beta[j]*age4[i,j,k] + gamma[k]*male[i,j,k] + b[i]
      }
    }
  }
}
", fill = TRUE)
sink()


# Initial values
inits23 <- function() {
  list(
    alpha = rnorm(n_munic, 0, 2),
    beta = rnorm(n_age, 1, 1),
    gamma = rnorm(n_sex, 1, 1),
    sigma = rnorm(1, 0, 1)
  )
}

inits23 <- function() {
  list(
    alpha = rnorm(1, 0, 2),               # Single intercept parameter
    beta = rnorm(n_age, 0, 1),           # Age effects (vector of size n_age)
    gamma = rnorm(n_sex, 0, 1),          # Sex effects (vector of size n_sex)
    b = rnorm(n_munic, 0, 1),            # Random intercepts for municipalities
    tau = rgamma(1, 0.001, 0.001)        # Precision for random intercepts
  )
}


params23 <- c("alpha", "beta", "gamma", "sigma", "mu")

mod23.fit <- jags.model(file="model23.txt",
                        data = datajags23,
                        n.chains = 3,
                        n.adapt=1000)
update(mod23.fit,5000)
model23.sim <- coda.samples(model = mod23.fit,
                            variable.names = params23,
                            n.iter=10000, 
                            thin=1)

sink("model23res.txt")
summary(model23.sim)
sink()

rmeanplot(model23.sim)
traceplot(model23.sim)
par("mar")
par(mar=c(1,1,1,1))
geweke.plot(model23.sim)
gelman.plot(model23.sim)
heidel.diag(model23.sim)
raftery.diag(model23.sim)

## Run the model ----
mod23.fit <- jags(
  data = datajags23,
  #inits = inits23,
  parameters.to.save = params23,
  model.file = "model23.txt",
  n.chains = 3,
  n.iter = 10000,
  n.burnin = 5000,
  jags.seed = 123,
  quiet = FALSE
)



#######--------------centering FINAL -----------------------------------

#######--------------centering-----------------------------------

datajags23 <- list(
  n_munic = length(unique(DDKdata$naam)),
  #n_munic_arr = array(1:n_munic, dim = c(300, 5, 2)),
  n_age = length(unique(DDKdata$age)),
  n_sex = length(unique(DDKdata$sex)),
  Niag = array(c(DDKdata$invited), dim = c(300, 5, 2)), 
  Yiag = array(c(DDKdata$participant), dim = c(300, 5, 2)),
  male = array(c(DDKdata$male), dim = c(300, 5, 2)),
  age1 = array(c(DDKdata$age1), dim = c(300, 5, 2)),
  age2 = array(c(DDKdata$age2), dim = c(300, 5, 2)),
  age3 = array(c(DDKdata$age3), dim = c(300, 5, 2)),
  age4 = array(c(DDKdata$age4), dim = c(300, 5, 2))
)

n_munic <- length(unique(DDKdata$naam))
n_age <- length(unique(DDKdata$age))
n_sex <- length(unique(DDKdata$sex))


sink("model2cent.txt")
cat("
model {
# Priors
  for (i in 1:n_munic){
    for (j in 1:n_age) {
      for (k in 1:n_sex) {
        # process model
        Yiag[i,j,k] ~ dbin(pi[i,j,k], Niag[i,j,k])
        logit(pi[i,j,k]) <- b[i,j,k]
        
        # data model
        b[i,j,k] ~ dnorm(mu[i,j,k], tau)
        mu[i,j,k] <- alpha + beta[j]*age1[i,j,k] + 
                          beta[j]*age2[i,j,k] + beta[j]*age3[i,j,k] +
                          beta[j]*age4[i,j,k] + gamma[k]*male[i,j,k]
      }
    }
  }
  
  # priors for fixed effects
  alpha ~ dnorm(0, 0.001) # intercept
  for (j in 1:n_age) {
    beta[j] ~ dnorm(0, 0.001) # Age effects
  }
  
  for (k in 1:n_sex) {
    gamma[k] ~ dnorm(0, 0.001) # Sex effects
  }
  
  tau ~ dgamma(0.001, 0.001) # variance of random effects
}  
", fill = TRUE)
sink()

inits2c <- function() {
  list(
    alpha = rnorm(1, 0, 2),         # Single intercept parameter
    beta = rnorm(n_age, 0, 1),      # Age effects (vector of size n_age)
    gamma = rnorm(n_sex, 0, 1),     # Sex effects (vector of size n_sex)
    tau = rgamma(1, 0.001, 0.001)   # Precision for random intercepts
  )
}

params2c <- c("alpha", "beta", "gamma", "tau")


## Run the model -- r2jags
mod2c.fit <- jags(
  data = datajags23,
  #inits = inits2c,
  parameters.to.save = params2c,
  model.file = "model2cent.txt",
  n.chains = 3,
  n.iter = 10000,
  n.burnin = 5000,
  jags.seed = 123,
  quiet = FALSE
)

# print pD and DIC ---------------------------------------
options(max.print=999999)
sink("model2cresults.txt")
print(mod2c.fit)
sink()

###------ using rjags 
mod2cent.fit <- jags.model(file="model2cent.txt",
                           data = datajags23,
                           n.chains = 3,
                           n.adapt=10000)

update(mod2cent.fit,5000)

model2c.sim <- coda.samples(model = mod2cent.fit,
                            variable.names = params2c,
                            n.iter=10000, 
                            thin=1)

options(max.print=999999)
sink("model2centres.txt")
summary(model2c.sim)
sink()


model2centered.mcmc <- as.mcmc.list(model2c.sim)

##-------convergence checks FINAL --------------------------------------------
traceplot(model2centered.mcmc)
rmeanplot(model2centered.mcmc)
autocorr.plot(model2centered.mcmc)
geweke.diag(model2centered.mcmc)
geweke.plot(model2centered.mcmc)
gelman.diag(model2centered.mcmc)
heidel.diag(model2centered.mcmc)
raftery.diag(model2centered.mcmc)
effectiveSize(model2centered.mcmc) 

effectiveSize(mod2c.fit)

#### -------------------------------------------------------------------
traceplot(model2centered.mcmc)


### library ggmcmc -----------------------------------------------
library(ggmcmc)
bayes2cent.ggmcmc <- ggs(model2centered.mcmc)

# parameters #alpha, beta,gamma, tau

png("pictures/centered/centtracetau.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_traceplot(bayes2cent.ggmcmc, family = "tau")
dev.off()

png("pictures/centered/centautocortau.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_autocorrelation(bayes2cent.ggmcmc, family = "tau")
dev.off()

png("pictures/centered/centrmeanalpha.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_running(bayes2cent.ggmcmc, family = "alpha")
dev.off()

png("pictures/centered/centgewktau.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_geweke(bayes2cent.ggmcmc, family = "tau")
dev.off()

png("pictures/centered/centgbraltau.png", width = 18, 
    height = 10, units = "cm", res = 300)
ggs_grb(bayes2cent.ggmcmc, family = "tau")
dev.off()


print(ggs_diagnostics(bayes2cent.ggmcmc, family = "alpha"), n=500)

#------------------------------------------------------------------
