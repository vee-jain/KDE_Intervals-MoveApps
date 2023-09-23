library('amt')
library('move2')
library('lubridate')
library('purrr')
library('dplyr')
library('ggplot2')
library('ggforce')
library('mapview')
library('RColorBrewer')
library('leafsync')
library('zip')

## The parameter "data" is reserved for the data object passed on from the previous app
# to display messages to the user in the log file of the App in MoveApps
# one can use the function from the logger.R file:
# logger.fatal(), logger.error(), logger.warn(), logger.info(), logger.debug(), logger.trace()

# Showcase injecting app setting (parameter `year`)
rFunction = function(data, interval_option, ...) {
  
  ####----Function to make movement track----####
  move2_TO_track.xyt <- function(mv2){
    if(mt_is_move2(mv2)){
      warning("!!INFO!!: only coordinates, timestamps and track IDs are retained")
      track(
        x=sf::st_coordinates(mv2)[,1],
        y=sf::st_coordinates(mv2)[,2],
        t=mt_time(mv2),
        id=mt_track_id(mv2),
        crs = sf::st_crs(mv2)
      )
    }
  }
  
  #' Make movement track
  data_track <- move2_TO_track.xyt(data)  
  
  #' Create columns for weekly, monthly
  data_track <- data_track %>% 
    arrange(id,t_) %>%
    mutate(date = as.Date(data_track$t_, format = "%Y-%m-%d"),
           weekly_interval = week(date),
           monthly_interval = month(date),
           year = format(date, format = "%Y"))
  
  ####----Radio button setting----####
  if(interval_option == "weekly"){
    track_list <- data_track %>% 
      nest(info = -c(id, weekly_interval, year)) 
    names(track_list)[names(track_list) == "weekly_interval"] <- "interval"
  }
  
  if(interval_option == "monthly"){
    track_list <- data_track %>% 
      nest(info = -c(id, monthly_interval, year)) 
    names(track_list)[names(track_list) == "monthly_interval"] <- "interval"
  }
  
  ####----KDE estimation----####
  #' Setting requirement for minimum number of points for each interval
  track_list <- track_list %>% 
    mutate(
      row = sapply(track_list$info, nrow)
    ) %>%
    filter(row >= 10)
  
  #' KDE estimates
  hr <- list()
  hr <-  track_list %>%
    mutate( 
      hr_kde = (map(track_list$info, ~hr_kde(., levels = c(0.50, 0.95)))), #probabilistic
    )
  
  #' KDE changes through time
  hr_all <- hr %>%
    mutate(hr = map(hr_kde, possibly(hr_area, otherwise = NA))) %>%
    unnest(hr) %>% na.omit()
  
  #' Plot as pdf
  if(interval_option == "weekly"){
    kde_time_plts <- hr_all %>% 
      arrange(id,year, interval) %>%
      mutate(id = as.factor(id)) %>%
      split(.$id) %>% 
      map(~ggplot(data = .x, 
                  mapping = aes(x = interval, y = area/1000000, color = as.factor(level), group = as.factor(level))) + 
            geom_point()+
            geom_path()+
            facet_wrap_paginate(id~as.factor(year), scales = "free", ncol = 1, nrow = 2)+
            theme_minimal()+
            scale_x_continuous(breaks=seq(1,53, 1), 
                               limits=c(1, 53))+
            ylab("Area in"~km^2)+xlab("Interval")+
            labs(color = "KDE measure") + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)))
  }
  
  if(interval_option == "monthyl"){
    kde_time_plts <- hr_all %>% 
      arrange(id,year, interval) %>%
      mutate(id = as.factor(id)) %>%
      split(.$id) %>% 
      map(~ggplot(data = .x, 
                  mapping = aes(x = interval, y = area/1000000, color = as.factor(level), group = as.factor(level))) + 
            geom_point()+
            geom_path()+
            facet_wrap_paginate(id~as.factor(year), scales = "free", ncol = 1, nrow = 2)+
            theme_minimal()+
            scale_x_continuous(breaks=seq(1,12, 1), 
                               limits=c(1, 12))+
            ylab("Area in"~km^2)+xlab("Interval")+
            labs(color = "KDE measure") + theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)))
  }
  
  #' Output 1: export KDE by interval
  pdf(appArtifactPath("kde_time_plots.pdf"),onefile = TRUE)
  walk(kde_time_plts, print)
  dev.off()
  
  #' Output 2: export KDE by interval as csv
  kde_df <- hr_all %>% dplyr::select(-c(info, hr_kde, row))
  write.csv(kde_df, file = appArtifactPath("kde_df.csv"), row.names = FALSE)
  
  ####----KDE maps----####
  #' Create spatial object for points 
  plot_pts <- sf::st_as_sf(x = data_track,                         
                     coords = c("x_", "y_"),
                     crs = sf::st_crs(data))
  
  #' Extract isopleths (polygons)
  kde_values <- hr_all %>% 
    mutate(isopleth = map(hr_kde, possibly(hr_isopleths, otherwise = "NA"))) %>%
    filter(isopleth != "NA")
  
  #' Add columns back
  isopleths <- unique(do.call(rbind, kde_values$isopleth))
  isopleths$id <- kde_values$id
  isopleths$year <- kde_values$year
  isopleths$interval <- kde_values$interval
  
  #' Set colours
  nb.cols <- length(unique(isopleths$interval))
  mycolors <- colorRampPalette(brewer.pal(8, "Blues"))(nb.cols)
  
  #' Core plots 
  isopleths_core <- isopleths %>% filter(level == 0.5) %>% 
    mutate(interval = as.factor(interval))
  isopleths_core$id_year <- paste0(isopleths_core$id," ",isopleths_core$year)
  
  isopleths_core <- isopleths_core %>% split(.$id_year)
  
  m1 <- mapview(isopleths_core, zcol = "interval", 
                alpha.regions = 0.3, col.regions = mycolors, burst = TRUE)+
    mapview(plot_pts, zcol = "id",
            alpha.regions = 0.3, burst = TRUE)
  
  #' Range plots
  isopleths_range <- isopleths %>% filter(level == 0.95) %>% 
    mutate(interval = as.factor(interval))
  isopleths_range$id_year <- paste(isopleths_range$id, isopleths_range$year)
  isopleths_range <- isopleths_range %>% split(.$id_year)
  
  m2 <- mapview(isopleths_range, zcol = "interval", 
                alpha.regions = 0.3, col.regions = mycolors, burst = TRUE)+
    mapview(plot_pts, zcol = "id",
            alpha.regions = 0.3, burst = TRUE)

  #' Output 3: Export maps as html
  #also exporting these plots into the temporary directory
  dir.create(targetDirHtmlFiles <- tempdir())
  
  mapshot(m1, url = file.path(targetDirHtmlFiles, paste0("map_core_plot.html")))
  mapshot(m2, url = file.path(targetDirHtmlFiles, paste0("map_range_plot.html")))
  
  zip_file <- appArtifactPath(paste0("map_html_files.zip"))
  zip::zip(zip_file, 
           files = list.files(targetDirHtmlFiles, full.names = TRUE,
                              pattern="^map.*html"),
           mode = "cherry-pick")
  
  # provide my result to the next app in the MoveApps workflow
  return(data)
}
