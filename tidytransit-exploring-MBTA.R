 
# https://r-transit.github.io/tidytransit/articles/timetable.html

knitr::opts_chunk$set(echo = TRUE)
# Load necessary packages
library(gtfsio)
library(tidytransit)
library(dplyr)
library(ggplot2)
library(stringi)
library(lubridate)

gc()

current_dir <- getwd()
# print(current_dir)

# data_file_path <- paste0(current_dir, "/gtfs/MBTA_GTFS.zip")
data_file_path <- paste0(current_dir, "/gtfs/MBTA_GTFS.zip")
print(data_file_path)

# Read GTFS data into a gtfs object
print("loading mbta")
gtfs_mbta <- read_gtfs(data_file_path)
gtfs <- gtfs_mbta

# print("loading bus")
# gtfs_mta_latest_bus <- read_gtfs("http://web.mta.info/developers/data/nyct/bus/google_transit_manhattan.zip")

# the latest MTA subway file gives an error when loading:
# print("loading subway")
# gtfs_mta_latest_subway <- read_gtfs("http://web.mta.info/developers/data/nyct/subway/google_transit.zip")

# Warning message:
# In data.table::fread(file.path(tmpdir, file_txt), select = fields_classes,  :
#   Stopped early on line 129246. Expected 5 fields but found 0. Consider fill=TRUE and comment.char=. First discarded non-empty line: <<5..N70R,40.704817,-74.014065,0,>>

# print("loading sample mta subway")
# local_gtfs_path <- system.file("extdata", "google_transit_nyc_subway.zip", package = "tidytransit")
# gtfs_mta_sample <- read_gtfs(local_gtfs_path)
# gtfs <- gtfs_mta_sample

###############################################################
# Declare variables
###############################################################
route_target <- c("Green-C") #Use route_ids , not the full route names. Run 1-22 and see dat$routes for more information. 
#You can use up to 2 routes in the route_target argument, BUT the 2 routes must a) share at least 2 stops, and b) have the same direction_id-direction correspondances.
#For example, the J and M trains in New York run together, but a Metropolitan Ave-bound M and a Jamaica-bound J have direction_ids of 1 and 0, respectively, so you
#cannot plot both at the same time. You can, however, put them in the routes_secondary argument, provided you plan to plot directions 0 and 1.

# Stop Name
stop_target <- "Park Street"

# Park Street stop_id list (Green and Red lines)
stop_mand <- c(70075, 70076, 70196, 70197, 70197, 70198, 70199, 70200, 71199) #If you want to ensure that the string plot includes a certain (branch of a route serving a) stop, add its stop ID here. 
#Remember to include that stop's ID in both directions if plotting a bidirectional plot! 

routes_secondary <- c() #Add any other routes you'd like to see shown on your string plot. Not many rules for what can/can't go here!

dir_target <- c(0,1) #Select one or both directions to view. Possible directions are 0 and 1. What they correspond to varies by agency.

date_target <- as.Date("2023-07-11") #Choose your sample date. This MUST lie within the target/end dates of your gtfs. Run lines 1-63 and 
#paste View(dat$.$dates_services) in the command line to see available dates, or see the dates listed on the GTFS download site. 

time_target <- period_to_seconds(hms("04:00:00")) #target time for the plot
time_end <- period_to_seconds(hms("10:00:00")) #End time for the plot 

# ggsave(stri_c("R_Plot_p1_","_",as.numeric(Sys.time()),".png"),device="png",
save_filename <- stri_c(current_dir, "/plots/","R_Plot_p1_",route_target, "_", date_target,"_",as.numeric(Sys.time()),".png")
print(save_filename)
# stop("stopping")

###############################################################
# Code targets here
###############################################################
print("trip_origin and trip_headsign")

# To display where a bus (or any public transit vehicle) is headed on a timetable we need the column trip_headsign in gtfs$trips. This is an optional field but our example feed provides this information. To display where a vehicle comes from on the timetable we need to create a new column in gtfs$trips which we'll call trip_origin.

print("get the id of the first stop in the trip's stop sequence") 
first_stop_id <- gtfs$stop_times %>%
  group_by(trip_id) %>%
  summarise(stop_id = stop_id[which.min(stop_sequence)])

# print(first_stop_id, n = Inf)
print(first_stop_id)

print("join with the stops table to get the stop_name") 
first_stop_names <- left_join(first_stop_id, gtfs$stops, by="stop_id")

# rename the first stop_name as trip_origin
trip_origins <- first_stop_names %>% select(trip_id, trip_origin = stop_name)

print("join the trip origins back onto the trips") 
gtfs$trips <- left_join(gtfs$trips, trip_origins, by = "trip_id")

gtfs$trips %>%
  select(route_id, trip_origin) %>%
  head()

print("In case trip_headsign does not exist in the feed it can be generated similarly to trip_origin:") 

if(!exists("trip_headsign", where = gtfs$trips)) {
  # get the last id of the trip's stop sequence
  trip_headsigns <- gtfs$stop_times %>%
    group_by(trip_id) %>%
    summarise(stop_id = stop_id[which.max(stop_sequence)]) %>%
    left_join(gtfs$stops, by="stop_id") %>%
    select(trip_id, trip_headsign.computed = stop_name)

  print("assign the headsign to the gtfs ") 
  gtfs$trips <- left_join(gtfs$trips, trip_headsigns, by = "trip_id")
}

print("Create A Departure Time Table") 

# To create a departure timetable, we first need to find the ids of all stops in the stops table with the same same name, as stop_name might cover different platforms and thus have multiple stop_ids in the stops table.

stop_ids <- gtfs$stops %>%
  # filter(stop_name == "Times Sq - 42 St") %>%
  filter(stop_name == stop_target) %>%
  select(stop_id)

# Note that multiple unrelated stops can have the same stop_name, see cluster_stops() for examples how to find these cases.

print("Trips departing from stop") 

# To the selected stop_ids for Time Square, we can join trip columns: route_id, service_id, trip_headsign, and trip_origin. Because stop_ids and trips are linked via the stop_times data frame, we do this by joining the stop_ids we've selected to the stop_times data frame and then to the trips data frame.

departures <- stop_ids %>%
  inner_join(gtfs$stop_times %>%
               select(trip_id, arrival_time,
                      departure_time, stop_id),
             by = "stop_id")

departures <- departures %>%
  left_join(gtfs$trips %>%
              select(trip_id, route_id,
                     service_id, trip_headsign,
                     trip_origin),
            by = "trip_id")

print("add route info (route_short_name)")

print("Each trip belongs to a route, and the route short name can be added to the departures by joining the trips data frame with gtfs$routes.") 

# print(gtfs$routes)

departures <- departures %>%
  left_join(gtfs$routes %>%
              select(route_id,
                     route_short_name),
            by = "route_id")

# print(departures[1-9])
# View(departures[1:9, ])
print(departures[1:9, ], n = Inf)

print(stri_c("Now we have a data frame that tells us about the origin, destination, and time at which each train departs from ", stop_target, " for every possible schedule of service.")) 

print(departures %>%
  select(arrival_time,
         departure_time,
         trip_headsign,trip_origin,
         route_id) %>%
  head() %>%
  knitr::kable()
)

print(dim(departures))

print("However, we do not know days on which these trips run. Using the service_id column on our calculated departures and tidytransit's calculated dates_services data frame, we can filter trips to a given date of interest.") 

print(head(gtfs$.$dates_services))

# Please see the servicepatterns vignette for further examples on how to use this table.

print("Extract a single day") 

# Now we are ready to extract the same service table for any given day of the year.

# For example, for August 23rd 2018, a typical weekday, we can filter as follows:

services_on_date_target <- gtfs$.$dates_services %>%
  filter(date == date_target) %>% select(service_id)

departures_date_target <- departures %>%
  inner_join(services_on_date_target, by = "service_id")

# How services and trips are set up depends largely on the feed. For an idea how to handle other dates and questions about schedules have a look at the servicepatterns vignette.

departures_date_target %>%
  arrange(departure_time, stop_id, route_short_name) %>%
  select(departure_time, stop_id, route_short_name, trip_headsign) %>%
  filter(departure_time >= hms::hms(hours = 7)) %>%
  filter(departure_time < hms::hms(hours = 7, minutes = 10)) %>%
  knitr::kable()

print("Simple plot") 

print(stri_c("We will now plot all departures from ", stop_target, " depending on trip_headsign and route. We can use the route colors provided in the feed.")) 

route_colors <- gtfs$routes %>% select(route_id, route_short_name, route_color)
route_colors$route_color[which(route_colors$route_color == "")] <- "454545"
route_colors <- setNames(paste0("#", route_colors$route_color), route_colors$route_short_name)

plot_title <- stri_c("Departures from ", stop_target, " on ", date_target)

p1 <- ggplot(departures_date_target) + theme_bw() +
  geom_point(aes(y=trip_headsign, x=departure_time, color = route_short_name), size = 0.2) +
  scale_x_time(breaks = seq(0, max(as.numeric(departures$departure_time)), 3600),
               labels = scales::time_format("%H:%M")) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  theme(legend.position = "bottom") +
  scale_color_manual(values = route_colors) +
  labs(title = plot_title)

print("Now we plot departures for all stop_ids with the same name, so we can separate for different stop_ids. The following plot shows all departures for stop_ids 127N and 127S from 7 to 8 AM.") 

departures_date_target_sub_7to8 <- departures_date_target %>%
  # filter(stop_id %in% c("127N", "127S")) %>%
  filter(stop_id %in% stop_mand) %>%
  filter(departure_time >= hms::hms(hours = 7) & departure_time <= hms::hms(hour = 8))

p2 <- ggplot(departures_date_target_sub_7to8) + theme_bw() +
  geom_point(aes(y=trip_headsign, x=departure_time, color = route_short_name), size = 1) +
  scale_x_time(breaks = seq(7*3600, 9*3600, 300), labels = scales::time_format("%H:%M")) +
  scale_y_discrete(drop = F) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  theme(legend.position = "bottom") +
  labs(title = plot_title) +
  facet_wrap(~stop_id, ncol = 1)

# Of course this plot idea can be expanded further. You could also differentiate each route by direction (using direction_id, headsign, origin or next/previous stops). Another approach is to calculate frequencies and show different levels of service during the day, all depending on the goal of your analysis.

plot(p1)

# ggsave(save_filename, device="png",
#        plot = p1, width = 25, height = 20, units = "in", dpi = 300) 

plot(p2)

# ggsave(stri_c("R_Plot_p2_","_",as.numeric(Sys.time()),".png"),device="png",
#        plot = p2, width = 25, height = 20, units = "in", dpi = 300) 
