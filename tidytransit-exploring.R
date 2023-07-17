 
# https://r-transit.github.io/tidytransit/articles/timetable.html

knitr::opts_chunk$set(echo = TRUE)
library(tidytransit)
library(dplyr)
library(ggplot2)

gc()

current_dir <- getwd()
# print(current_dir)

data_file_path <- paste0(current_dir, "/gtfs/MBTA_GTFS.zip")
print(data_file_path)

local_gtfs_path <- system.file("extdata", "google_transit_nyc_subway.zip", package = "tidytransit")
gtfs <- read_gtfs(local_gtfs_path)
# gtfs <- read_gtfs("http://web.mta.info/developers/data/nyct/subway/google_transit.zip")


# Load necessary packages
library(gtfsio)

# Read GTFS data into a gtfs object
g <- read_gtfs(data_file_path)

# Remove or modify duplicated IDs in the fare_products table
# For example, let's append "_dup" to the duplicated IDs
g$fare_products$fare_product_id <- make.unique(g$fare_products$fare_product_id)

# Convert the modified data to a tidygtfs object
# tidy_g <- as_tidygtfs(g)

# mbta_local_gtfs_path <- system.file("extdata", data_file_path, package = "tidytransit")
# dat_master <- read_gtfs(data_file_path) #this should be the path to your GTFS file.

# Exclude the fare_products table during conversion
tidy_g <- gtfs_to_tidygtfs(g, exclude_tables = "fare_products")