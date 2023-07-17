 
# https://r-transit.github.io/tidytransit/articles/timetable.html

knitr::opts_chunk$set(echo = TRUE)
# Load necessary packages
library(gtfsio)
library(tidytransit)
library(dplyr)
library(ggplot2)

gc()

current_dir <- getwd()
# print(current_dir)

# data_file_path <- paste0(current_dir, "/gtfs/MBTA_GTFS.zip")
data_file_path <- paste0(current_dir, "/gtfs/MBTA_GTFS.zip")
print(data_file_path)

# Read GTFS data into a gtfs object
print("loading mbta")
gtfs_mbta <- read_gtfs(data_file_path)

print("loading sample mta subway")
local_gtfs_path <- system.file("extdata", "google_transit_nyc_subway.zip", package = "tidytransit")
gtfs_mta_sample <- read_gtfs(local_gtfs_path)

print("loading bus")
gtfs_mta_latest_bus <- read_gtfs("http://web.mta.info/developers/data/nyct/bus/google_transit_manhattan.zip")

# the latest MTA subway file gives an error when loading:
# print("loading subway")
# gtfs_mta_latest_subway <- read_gtfs("http://web.mta.info/developers/data/nyct/subway/google_transit.zip")

# Warning message:
# In data.table::fread(file.path(tmpdir, file_txt), select = fields_classes,  :
#   Stopped early on line 129246. Expected 5 fields but found 0. Consider fill=TRUE and comment.char=. First discarded non-empty line: <<5..N70R,40.704817,-74.014065,0,>>


