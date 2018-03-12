library(foreign)
library(here)
library(geojsonio)
library(magrittr)
library(raster)
library(RColorBrewer)
library(tidyverse)

# these might need to become a function later if we add more modules
module_01 <- read.spss(here::here("enaho/2016/546-Modulo01/Enaho01-2016-100.sav")) %>%
  as_tibble() %>%
  setNames(tolower(names(.))) %>%
  select(año, mes, conglome, vivienda, hogar, ubigeo, dominio, estrato, periodo, factor07, longitud, latitud)

module_summary <- read.spss(here::here("enaho/2016/546-Modulo34/Sumaria-2016.sav")) %>%
  as_tibble() %>%
  setNames(tolower(names(.))) %>%
  select(conglome, vivienda, inghog1d)

modules_joined <- left_join(module_summary, module_01, by = c("conglome", "vivienda")) %>%
  select(ubigeo, conglome, vivienda, hogar, factor07, inghog1d) %>%
  mutate(department = as.numeric(str_sub(ubigeo, 1, 2))) %>% 
  group_by(department) %>%
  summarize(w_income = weighted.mean(inghog1d, factor07))

department_table <- tribble(~department, ~name,
                           01, "amazonas",
                           02, "ancash",
                           03, "apurímac",
                           04, "arequipa",
                           05, "ayacucho",
                           06, "cajamarca",
                           07, "callao",
                           08, "cusco",
                           09, "huancavelica",
                           10, "huánuco",
                           11, "ica",
                           12, "junín",
                           13, "la libertad",
                           14, "lambayeque",
                           15, "lima",
                           16, "loreto",
                           17, "madre de dios",
                           18, "moquegua",
                           19, "pasco",
                           20, "piura",
                           21, "puno",
                           22, "san martín",
                           23, "tacna",
                           24, "tumbes",
                           25, "ucayali")

income_dept <- left_join(modules_joined, department_table, by = "department") %>%
  mutate(w_income_cat = factor(cut(w_income, c(10000, 20000, 25000, 30000, 40000, 50000, 60000)),
                               labels = c("10 to 19", "20 to 24", "25 to 29", 
                                          "30 to 39", "40 to 49", "50 to 59")))
income_dept[nrow(income_dept) + 1, ] <- income_dept %>% filter(name == "lima")
income_dept[nrow(income_dept), "name"] <- "lima province"

# do we have the correct number of households? The documentation says there
# should be 38,386 viviendas, but we have 44,485 unique viviendas. Where do the extra
# 6,099 viviendas come from?
# the weight is a vivienda weight

# number of unique viviendas
module_01 %>%
  count(conglome, vivienda) %>%
  nrow

# number of duplicated viviendas
module_01 %>%
  count(conglome, vivienda) %>%
  filter(n > 1) %>%
  nrow

# the duplicate viviendas are accounted for by adding hogar
module_01 %>%
  count(conglome, vivienda, hogar) %>%
  nrow

# define a theme for the map
theme_map <- function(...) {
  theme_minimal() +
    theme(
      text = element_text(family = "Arial Narrow", color = "#22211d"),
      axis.line = element_blank(),
      axis.text.x = element_blank(),
      axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      axis.title.x = element_blank(),
      axis.title.y = element_blank(),
      # panel.grid.minor = element_line(color = "#ebebe5", size = 0.2),
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      plot.background = element_blank(), 
      panel.background = element_blank(), 
      legend.background = element_blank(),
      panel.border = element_blank(), 
      legend.title = element_text()
    )
}

# check out the points for each conglomerado on a map
peru_poly <- getData("GADM", country = "PER", level = 1)

income_data_fortified <- fortify(peru_poly, region = "NAME_1") %>%
  mutate(id = tolower(id))

# INEI counts Lima and Lima Province as the same
income_data_fortified$id[income_data_fortified$id == "lima province"] <- "lima"

# get centroids of departments for labels and remove Lima Province
dept_coords <- as.tibble(coordinates(peru_poly)) %>%
  mutate(name = peru_poly@data$NAME_1) %>%
  filter(name != "Lima Province") %>%
  setNames(c("long", "lat", "name"))

dept_coords$long[dept_coords$name == "Callao"] <- dept_coords$long[dept_coords$name == "Callao"] - 0.50
dept_coords$color <- "black"
dept_coords$color[dept_coords$name %in% c("Cajamarca", "Huancavelica", 
                                          "Ayacucho", "Apurímac", "Amazonas",
                                          "Huánuco", "Pasco", "Puno")] <- "white"

income_map_data <- left_join(income_data_fortified, income_dept, by = c("id" = "name")) 

#colors <- brewer.pal(6, 'Greens')

map <- ggplot()  + 
  geom_polygon(data = income_map_data, aes(x = long - 0.10, y = lat - 0.050,
                                           group = group),
               color = "grey50", size = 0.2, fill = "grey50") +
  geom_polygon(data = income_map_data, aes(fill = w_income_cat, 
                   x = long,
                   y = lat,
                   group = group), color = "grey10", size = 0.2) +
  viridis::scale_fill_viridis(discrete = TRUE, name = "Net Annualized \nIncome ('000 soles)") +
  geom_text(data = dept_coords, aes(x = long, y = lat, label = name, color = color), 
            show.legend = FALSE) +
  scale_color_manual(values = c("black", "white")) + theme_map()
map

### Cool! Now let's save the peru polygon as a topojson file

peru_poly@data <- peru_poly@data %>% mutate(lower_name = tolower(NAME_1))

geojson_write(peru_poly, lon = "long", lat = "lat", 
               geometry = polygon, file = here::here("peru_adm1.geojson"),
               convert_wgs84 = TRUE)

write_csv(income_dept, here::here("income_dept.csv"))

### Let's add an ADM0 Peru map for the drop shadow in d3
peru_adm0 <- getData("GADM", country = "PER", level = 0)

geojson_write(peru_adm0, lon = "long", lat = "lat",
              geometry = polygon, file = here::here("peru_adm0.geojson"),
              convert_wgs84 = TRUE)










