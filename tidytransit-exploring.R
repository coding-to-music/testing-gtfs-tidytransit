 
# https://r-transit.github.io/tidytransit/articles/timetable.html

knitr::opts_chunk$set(echo = TRUE)
# Load necessary packages
library(gtfsio)
library(tidytransit)
library(dplyr)
library(ggplot2)
library(stringi)

gc()

current_dir <- getwd()
# print(current_dir)

# data_file_path <- paste0(current_dir, "/gtfs/MBTA_GTFS.zip")
# data_file_path <- paste0(current_dir, "/gtfs/MBTA_GTFS.zip")
# print(data_file_path)

# Read GTFS data into a gtfs object
# print("loading mbta")
# gtfs_mbta <- read_gtfs(data_file_path)

# print("loading bus")
# gtfs_mta_latest_bus <- read_gtfs("http://web.mta.info/developers/data/nyct/bus/google_transit_manhattan.zip")

# the latest MTA subway file gives an error when loading:
# print("loading subway")
# gtfs_mta_latest_subway <- read_gtfs("http://web.mta.info/developers/data/nyct/subway/google_transit.zip")

# Warning message:
# In data.table::fread(file.path(tmpdir, file_txt), select = fields_classes,  :
#   Stopped early on line 129246. Expected 5 fields but found 0. Consider fill=TRUE and comment.char=. First discarded non-empty line: <<5..N70R,40.704817,-74.014065,0,>>

print("loading sample mta subway")
local_gtfs_path <- system.file("extdata", "google_transit_nyc_subway.zip", package = "tidytransit")
gtfs_mta_sample <- read_gtfs(local_gtfs_path)
gtfs <- gtfs_mta_sample

print("trip_origin and trip_headsign")

# To display where a bus (or any public transit vehicle) is headed on a timetable we need the column trip_headsign in gtfs$trips. This is an optional field but our example feed provides this information. To display where a vehicle comes from on the timetable we need to create a new column in gtfs$trips which we'll call trip_origin.

print("get the id of the first stop in the trip's stop sequence") 
first_stop_id <- gtfs$stop_times %>%
  group_by(trip_id) %>%
  summarise(stop_id = stop_id[which.min(stop_sequence)])

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
  filter(stop_name == "Times Sq - 42 St") %>%
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

departures <- departures %>%
  left_join(gtfs$routes %>%
              select(route_id,
                     route_short_name),
            by = "route_id")

print("Now we have a data frame that tells us about the origin, destination, and time at which each train departs from Times Square for every possible schedule of service.") 

departures %>%
  select(arrival_time,
         departure_time,
         trip_headsign,trip_origin,
         route_id) %>%
  head() %>%
  knitr::kable()

print("However, we do not know days on which these trips run. Using the service_id column on our calculated departures and tidytransit's calculated dates_services data frame, we can filter trips to a given date of interest.") 

head(gtfs$.$dates_services)

# Please see the servicepatterns vignette for further examples on how to use this table.

print("Extract a single day") 

# Now we are ready to extract the same service table for any given day of the year.

# For example, for August 23rd 2018, a typical weekday, we can filter as follows:

services_on_180823 <- gtfs$.$dates_services %>%
  filter(date == "2018-08-23") %>% select(service_id)

departures_180823 <- departures %>%
  inner_join(services_on_180823, by = "service_id")

# How services and trips are set up depends largely on the feed. For an idea how to handle other dates and questions about schedules have a look at the servicepatterns vignette.

departures_180823 %>%
  arrange(departure_time, stop_id, route_short_name) %>%
  select(departure_time, stop_id, route_short_name, trip_headsign) %>%
  filter(departure_time >= hms::hms(hours = 7)) %>%
  filter(departure_time < hms::hms(hours = 7, minutes = 10)) %>%
  knitr::kable()

print("Simple plot") 

print("We will now plot all departures from Times Square depending on trip_headsign and route. We can use the route colors provided in the feed.") 

route_colors <- gtfs$routes %>% select(route_id, route_short_name, route_color)
route_colors$route_color[which(route_colors$route_color == "")] <- "454545"
route_colors <- setNames(paste0("#", route_colors$route_color), route_colors$route_short_name)

ggplot(departures_180823) + theme_bw() +
  geom_point(aes(y=trip_headsign, x=departure_time, color = route_short_name), size = 0.2) +
  scale_x_time(breaks = seq(0, max(as.numeric(departures$departure_time)), 3600),
               labels = scales::time_format("%H:%M")) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  theme(legend.position = "bottom") +
  scale_color_manual(values = route_colors) +
  labs(title = "Departures from Times Square on 08/23/18")

print("Now we plot departures for all stop_ids with the same name, so we can separate for different stop_ids. The following plot shows all departures for stop_ids 127N and 127S from 7 to 8 AM.") 

departures_180823_sub_7to8 <- departures_180823 %>%
  filter(stop_id %in% c("127N", "127S")) %>%
  filter(departure_time >= hms::hms(hours = 7) & departure_time <= hms::hms(hour = 8))

p <- ggplot(departures_180823_sub_7to8) + theme_bw() +
  geom_point(aes(y=trip_headsign, x=departure_time, color = route_short_name), size = 1) +
  scale_x_time(breaks = seq(7*3600, 9*3600, 300), labels = scales::time_format("%H:%M")) +
  scale_y_discrete(drop = F) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  theme(legend.position = "bottom") +
  labs(title = "Departures from Times Square on 08/23/18") +
  facet_wrap(~stop_id, ncol = 1)

# Of course this plot idea can be expanded further. You could also differentiate each route by direction (using direction_id, headsign, origin or next/previous stops). Another approach is to calculate frequencies and show different levels of service during the day, all depending on the goal of your analysis.

plot(p)

ggsave(stri_c("stringline","_",as.numeric(Sys.time()),".png"),device="png",
       plot = p, width = 25, height = 20, units = "in", dpi = 300) 
