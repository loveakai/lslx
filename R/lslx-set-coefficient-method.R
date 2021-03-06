lslx$set("public",
         "free_coefficient",
         function(name,
                  start,
                  verbose = TRUE) {
           private$set_coefficient(
             name = name,
             start = start,
             type = "free",
             verbose = verbose
           )
         })



lslx$set("public",
         "fix_coefficient",
         function(name,
                  start,
                  verbose = TRUE) {
           private$set_coefficient(
             name = name,
             start = start,
             type = "fixed",
             verbose = verbose
           )
         })


lslx$set("public",
         "penalize_coefficient",
         function(name,
                  start,
                  verbose = TRUE) {
           private$set_coefficient(
             name = name,
             start = start,
             type = "pen",
             verbose = verbose
           )
         })



lslx$set("private",
         "set_coefficient",
         function(name,
                  start,
                  type,
                  verbose = TRUE) {
           if (missing(name)) {
             stop("Argument 'name' must be given.")
           }
           name <-
             gsub(pattern = "[[:blank:]]",
                  replacement = "",
                  x = name)
           name <-
             sapply(
               X = name,
               FUN = function(name_i) {
                 if (!grepl(pattern = "<-[^>]|<->", x = name_i)) {
                   stop("Some coefficient name doesn't contain valid operator ('<-' and '<->').")
                 }
                 if (!grepl(pattern = "\\|", x = name_i)) {
                   if (length(private$model$name_group) == 1) {
                     name_i <- paste0(name_i, "|", private$model$name_group)
                   } else {
                     stop("Some coefficient name doesn't contain group name.")
                   }
                 }
                 name_i_split <-
                   strsplit(x = name_i, split = c("<-|\\||<->"))[[1]]
                 if (length(name_i_split) != 3) {
                   stop("The format of some coefficient name is incorrect.")
                 }
                 left_i <- name_i_split[1]
                 right_i <- name_i_split[2]
                 group_i <- name_i_split[3]
                 
                 if (left_i == 1) {
                   stop("Intercept term '1' cannot be presented at the left-hand side of '<-'.")
                 }
                 
                 if (!(left_i %in% private$model$name_eta)) {
                   stop(
                     "Some specified left response or factor name is unrecognized.",
                     "\n  Response or factor name(s) currently recognized by 'lslx' is ",
                     do.call(paste, as.list(private$model$name_eta)),
                     ".",
                     "\n  The unrecognized variable or factor name is ",
                     left_i,
                     "."
                   )
                 }
                 
                 if (!(right_i %in% c(private$model$name_eta, 1))) {
                   stop(
                     "Some specified right response or factor name is unrecognized.",
                     "\n  Response or factor name(s) currently recognized by 'lslx' is ",
                     do.call(paste, as.list(private$model$name_eta)),
                     ".",
                     "\n  The unrecognized response or factor name is ",
                     right_i,
                     "."
                   )
                 }
                 
                 if (!(group_i %in% private$model$name_group)) {
                   stop(
                     "Some specified group name is unrecognized.",
                     "\n  Group name(s) currently recognized by 'lslx' is ",
                     do.call(paste, as.list(private$model$name_group)),
                     ".",
                     "\n  The unrecognized group name is ",
                     group_i,
                     "."
                   )
                 }
                 if (grepl(pattern = "<->",
                           x = name_i)) {
                   if (right_i == 1) {
                     stop("Intercept term '1' cannot be presented at the right-hand side of '<->'.")
                   }
                   if ((
                     match(left_i, private$model$name_eta) <
                     match(right_i, private$model$name_eta)
                   )) {
                     name_i <-
                       paste0(right_i, "<->", left_i, "|", group_i)
                   }
                 }
                 return(name_i)
               },
               simplify = TRUE,
               USE.NAMES = FALSE
             )
           
           if (missing(start)) {
             if (type == "free") {
               start <- rep(NA_real_, length(name))
             } else {
               start <- rep(0, length(name))
             }
           } else {
             if (!is.numeric(start)) {
               stop("The argument 'start' must be a numeric vector.")
             }
             if (length(start) == 1) {
               start <- rep(start, length(name))
             }
             if (length(start) != length(name)) {
               stop(
                 "Argument 'start' has ambiguous length.",
                 "\n  The length of 'start' must be the same with the length of 'name' or just one."
               )
             }
           }
           
           for (i in seq_len(length(name))) {
             if (name[i] %in% rownames(private$model$specification)) {
               private$model$specification[name[i], "type"] <- type
               private$model$specification[name[i], "start"] <-
                 start[i]
               specification_i <-
                 private$model$specification[name[i], , drop = FALSE]
             } else {
               relation_i <-
                 substr(name[i],
                        start = 1,
                        stop = regexpr("\\|", name[i]) - 1)
               name_i_split <-
                 strsplit(x = name[i], split = c("<-|\\||<->"))[[1]]
               left_i <- name_i_split[1]
               right_i <- name_i_split[2]
               group_i <- name_i_split[3]
               
               matrice_i <-
                 ifelse(grepl(pattern = "<->",
                              x = name[i]),
                        "psi",
                        ifelse(
                          grepl(pattern = "<-[^>]",
                                x = name[i]),
                          ifelse(right_i == "1",
                                 "alpha",
                                 "beta")
                        ))
               block_i_left <-
                 ifelse(left_i %in% private$model$name_response,
                        "y",
                        "f")
               block_i_right <-
                 ifelse(
                   right_i %in% private$model$name_response,
                   "y",
                   ifelse(
                     right_i %in% private$model$name_factor,
                     "f",
                     ifelse(right_i == "1",
                            "1",
                            "@")
                   )
                 )
               block_i_middle <-
                 ifelse(
                   matrice_i %in% c("alpha", "beta", "tau"),
                   "<-",
                   ifelse(matrice_i == "psi",
                          "<->",
                          "")
                 )
               block_i <-
                 paste0(block_i_left, block_i_middle, block_i_right)
               
               specification_i <-
                 data.frame(
                   relation = relation_i,
                   left = left_i,
                   right = right_i,
                   group = group_i,
                   reference =
                     ifelse(
                       is.na(private$model$reference_group),
                       FALSE,
                       ifelse(group_i == private$model$reference_group,
                              TRUE,
                              FALSE)),
                   matrice = matrice_i,
                   block = block_i,
                   type = type,
                   start = start[i],
                   stringsAsFactors = FALSE
                 )
               rownames(specification_i) <- name[i]
               private$model$specification <-
                 rbind(private$model$specification,
                       specification_i)
             }
             if (verbose) {
               cat(
                 "The relation",
                 specification_i$relation,
                 "under",
                 specification_i$group,
                 "is set as",
                 ifelse(
                   type == "pen",
                   "PENALIZED",
                   ifelse(type == "free",
                          "FREE",
                          "FIXED")
                 ),
                 "with starting value =",
                 paste0(specification_i$start, "."),
                 "\n"
               )
             }
           }
           
           if (verbose & !is.na(private$model$reference_group)) {
               cat(
                 "NOTE: Because",
                 private$model$reference_group,
                 "is set as reference,",
                 "a relation under other group", 
                 "actually represents an increment between the specified group",
                 "and the reference group",
                 paste0(private$model$reference_group, ".\n")
               )
             cat(
               "NOTE: Please check whether the starting value for the increment represents a difference. \n"
             )
           }

           private$model$specification <-
             private$model$specification <-
             private$model$specification[order(
               private$model$specification$reference,
               private$model$specification$group,
               private$model$specification$matrice,
               private$model$specification$block,
               match(private$model$specification$right, private$model$name_eta),
               match(private$model$specification$left, private$model$name_eta),
               decreasing = c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE),
               method = "radix"
             ), ]
           
           private$model$name_endogenous <-
             unique(private$model$specification$left[private$model$specification$matrice == "beta"])
           private$model$name_exogenous <-
             setdiff(x = private$model$name_eta,
                     y = private$model$name_endogenous)
           private$fitting <- NULL
         })
