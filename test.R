library(readr)

d <- rnorm(100)

write_csv(data.frame(num = d), "my_file.csv")