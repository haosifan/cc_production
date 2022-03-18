## -----------------------------------------------------------------------------------------------------------
library(dplyr)
library(purrr)
library(tibble)
library(stringr)
library(readr)
library(tidyr)
library(rvest)
library(lubridate)
library(glue)
library(pdftools)

setwd("/home/epvoteadmin/cc_production/")

## -----------------------------------------------------------------------------------------------------------
maxpage <- read_html("https://www.consilium.europa.eu/en/meetings/calendar/?Category=meeting&Page=1&dateFrom=2019%2F07%2F01&dateTo=2022%2F06%2F08&filters=2024&filters=2027&filters=2021&filters=2020&filters=2026&filters=2022&filters=2025&filters=2028&filters=2029&filters=2023&filters=2019&filters=") %>% 
  html_nodes(".pagination-lg a") %>% 
  html_attr("data-page") %>% 
  as_tibble() %>% 
  mutate(value = parse_integer(value)) %>% 
  filter(value == max(value, na.rm = TRUE)) %>% 
  distinct() %>% 
  pull(value)


## -----------------------------------------------------------------------------------------------------------
search_urls <- tibble(page = 1:maxpage) %>% 
  mutate(searchurl = glue("https://www.consilium.europa.eu/en/meetings/calendar/?Category=meeting&Page={page}&dateFrom=2019%2F07%2F01&dateTo=2022%2F06%2F08&filters=2024&filters=2027&filters=2021&filters=2020&filters=2026&filters=2022&filters=2025&filters=2028&filters=2029&filters=2023&filters=2019&filters=")) %>% pull(searchurl)

init_list <- function(searchurl){

  html_landingpage <- read_html(searchurl)
  
  
  title <- html_landingpage %>% html_nodes(".d-block-mobile a") %>% html_text()
  link <- html_landingpage %>% html_nodes(".d-block-mobile a") %>% html_attr("href") %>% paste0("https://www.consilium.europa.eu",.)
  
  t <- tibble(title = title, link = link)
  return(t)
}

linklist_meetings <- map_dfr(search_urls, init_list) %>% 
  filter(!grepl(pattern = "Brussels", title)) %>% 
  filter(!grepl(pattern = "members", title)) %>% 
  filter(!grepl(pattern = "EU Chiefs of Defence", title)) %>% 
  filter(!grepl(pattern = "Cooperation", title)) %>% 
  filter(!grepl(pattern = "Joint", title))


## -----------------------------------------------------------------------------------------------------------
find_pdflinks <- function(meeting_link){
  
  html_meeting <- read_html(meeting_link)
  
  linktext <- html_meeting %>% html_nodes(".link-pdf") %>% html_text()
  link <- html_meeting %>% html_nodes(".link-pdf") %>% html_attr("href") %>% paste0("https://www.consilium.europa.eu",.)
  
  pdf_link <- tibble(linktext, link) %>% 
    filter(grepl("List of participants", linktext)) %>% 
    pull(link) %>% 
    .[1]
      
  
  return(pdf_link)
}


## -----------------------------------------------------------------------------------------------------------
linklist_meetings_pdf <- linklist_meetings %>% 
  mutate(pdf_link = map_chr(link, find_pdflinks))


## -----------------------------------------------------------------------------------------------------------
list_clean <- linklist_meetings_pdf %>% 
  mutate(configuration = link %>% 
           str_remove(pattern = "https://www.consilium.europa.eu/en/meetings/") %>% 
           str_remove(pattern = "-art50") %>% 
           str_extract(pattern = "^[:alpha:]*"),
         date = str_remove(link, pattern = "https://www.consilium.europa.eu/en/meetings/[:alpha:]*\\/"),
         date = case_when(str_length(date) == 14 ~ str_sub(date, end = -4),
                          TRUE ~ str_sub(date, end = -1)),
         date = lubridate::ymd(date),
         destfile = glue("pdf_participants/{configuration}_{date}.pdf")) %>% 
  filter(configuration != "international")

list_clean %>% count(configuration)


## -----------------------------------------------------------------------------------------------------------
safe_download <- safely(~ download.file(.x , .y, mode = "wb"))

#to download uncomment
walk2(list_clean$pdf_link, list_clean$destfile, safe_download)


## -----------------------------------------------------------------------------------------------------------
eu_cntries <- c("Austria:", "Belgium:", "Bulgaria:", "Croatia:", "Republic of Cyprus:", "Cyprus:", "Czechia:", "Czech Republic:", "Denmark:", "Estonia:", "Finland:", "France:", "Germany:", "Greece:", "Hungary:", "Ireland:", "Italy:", "Latvia:", "Lithuania:", "Luxembourg:", "Malta:", "Netherlands:", "Poland:", "Portugal:", "Romania:", "Slovakia:", "Slovenia:", "Spain:", "Sweden:", "Commission:")

regex_remove_title <- c("Informal videoconference of Ministers responsible for ",
                        "Informal videoconference of Ministers of the ", 
                        "REV[:digit:]*\\*",
                        "Brussels, ",
                        "BRUSSELS",
                        "LUXEMBOURG",
                        "Luxembourg",
                        "[:digit:]*",
                        "PARTICIPANTS",
                        "October",
                        lubridate::month(1:12, 
                                         label = TRUE, 
                                         abbr = FALSE) %>% 
                          as.character()) %>% 
  glue_collapse(sep = "|")


## -----------------------------------------------------------------------------------------------------------
f_extract_participants_pdf <- function(path){

  date <- basename(path) %>%
    str_sub(start = -14, end = -5)
  
  abbr <- basename(path) %>%
    str_remove(pattern = "_.{10}\\.pdf$")
  
  pdf_raw <- pdf_text(path)
    
  full_title <- pdf_text(path) %>% 
    read_lines() %>%
    str_split(pattern = "[:blank:][:blank:][:blank:]*", simplify = TRUE) %>% 
    as_tibble() %>%
    pull(V1) %>% 
    .[1:3] %>%
    glue_collapse(sep = " ") %>% 
    str_remove_all(pattern = regex_remove_title)
    
  participants <- pdf_raw %>% 
    read_lines() %>%
    str_split(pattern = "[:blank:][:blank:][:blank:]*", simplify = TRUE) %>% 
    as_tibble() %>% 
    mutate(cntry = case_when(V1 %in% eu_cntries ~ V1,
                             TRUE ~ NA_character_),
           V1 = na_if(V1, "")) %>%
    fill(cntry, .direction = "down") %>%
    filter(cntry != "Commission:") %>% 
    fill(V1, .direction = "down") %>% 
    filter(V2 != "") %>% 
    group_by(V1) %>% 
    mutate(office = paste0(V2, collapse = " ")) %>% 
    distinct_at(.vars = vars(V1, cntry, office)) %>% 
    rename(name = V1) %>% 
    mutate(cntry = str_remove(cntry, ":"),
           date = date,
           abbr = abbr,
           full_title = full_title) %>% 
    select(abbr, full_title, date, cntry, name, office)
  return(participants)
}



## -----------------------------------------------------------------------------------------------------------
paths_to_pdfs <- paste0("pdf_participants/",dir("pdf_participants/"))
map_dfr(paths_to_pdfs, f_extract_participants_pdf) %>% write_excel_csv2("data/list_council_meetings_participants.csv")

