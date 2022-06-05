#Control for avoiding repeated intro message on cluster
#creation
cf <- "started"
write(c("started","clusters"),cf,sep=",")

# if(.Platform$OS.type == "unix") {
#   my.cluster <-  makeForkCluster(detectCores() - 1,outfile="results/logs/parallelworkers.log",
#                                  envir=globalenv())
# } else {
  assign("my.cluster",parallel::makeCluster(
    parallel::detectCores() - 1, 
    type = "PSOCK"), envir=globalenv())
# }

file.remove(cf)
