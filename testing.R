
##### BEFORE USING THIS CODE, PLEASE READ THE LAST SECTIONS OF THIS (https://homesignalblog.wordpress.com/2022/11/26/stringlines/) BLOG POST, WHICH EXPLAIN HOW TO USE IT #####

library(purrr)
library(data.table)
library(dplyr)
library(ggplot2)
library(lubridate)
library(stringi)
library(tidytransit)
library(tidyr)
library(ggmap)
library(sf)
library(rgeos)
library(scales)
library(rlist)
library(maptools)
library(dotenv)

current_dir <- getwd()
# print(current_dir)
env_file_path <- paste0(current_dir, "/.env")
# print(env_file_path)

dotenv::load_dot_env(env_file_path)

data_file_path <- paste0(current_dir, "/gtfs/MBTA_GTFS.zip")
print(data_file_path)
# data_file <- Sys.getenv("DATA_FILE")
# working_dir <- Sys.getenv("WORKING_DIR")

# print(data_file)
# print(working_dir)

setwd(current_dir) #Set a path to your R working directory here. eg. "C:/Users/yourname/Documents/RProjects/Stringlines" This is an optional step.
#If you do not set a working directory, scroll to the end of the code and set a path for the plot save function, lest it clutter your 
#Documents folder. 

#For more on working directories, see: 

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
############### parameters here ############### 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

# dat_master <- read_gtfs("C:/Users/Uday/Downloads/mbta_gtfs.zip") #this should be the path to your GTFS file.
dat_master <- read_gtfs(data_file_path) #this should be the path to your GTFS file.
#You may also insert the download link to an agency GTFS feed here. 

#NOTE: for all of these fields, when leaving elements blank, do not use "". The code's function depends on it.
#Eg. leaving routes_secondary blank should look like routes_secondary <- c() not routes_secondary <- c(")

template_choice <- "Longest" #Most (for most common) or Longest (for longest pattern). 

name_elim <- FALSE #Whether you want the code to reduce the number of stops shown on the Y axis. TRUE or FALSE. 
use_rt_sht <- FALSE #Should the code replace route_ids with route_short_names

route_tar <- c("74") #Use route_ids , not the full route names. Run 1-22 and see dat$routes for more information. 
#You can use up to 2 routes in the route_tar argument, BUT the 2 routes must a) share at least 2 stops, and b) have the same direction_id-direction correspondances.
#For example, the J and M trains in New York run together, but a Metropolitan Ave-bound M and a Jamaica-bound J have direction_ids of 1 and 0, respectively, so you
#cannot plot both at the same time. You can, however, put them in the routes_secondary argument, provided you plan to plot directions 0 and 1.

stop_mand <- c() #If you want to ensure that the string plot includes a certain (branch of a route serving a) stop, add its stop ID here. 
#Remember to include that stop's ID in both directions if plotting a bidirectional plot! 

routes_secondary <- c() #Add any other routes you'd like to see shown on your string plot. Not many rules for what can/can't go here!

dir_tar <- c(0,1) #Select one or both directions to view. Possible directions are 0 and 1. What they correspond to varies by agency.

date_tar <- as.Date("2023-07-11") #Choose your sample date. This MUST lie within the start/end dates of your gtfs. Run lines 1-63 and 
#paste View(dat$.$dates_services) in the command line to see available dates, or see the dates listed on the GTFS download site. 

time_start <- period_to_seconds(hms("8:00:00")) #Start time for the plot
time_end <- period_to_seconds(hms("13:00:00")) #End time for the plot 

#Along with all these parameters, you may also wish to change the dimensions of the output plot. Use the last line of the code to do that.
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
############### code begins here ############### 
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

`%notin%` <- Negate(`%in%`)

gc()

# dat <- dat_master
# dat <- set_servicepattern(dat)

# svc <- dat$.$dates_services
# print(svc)

# svc <- svc%>%
# dplyr::filter(date == date_tar)


