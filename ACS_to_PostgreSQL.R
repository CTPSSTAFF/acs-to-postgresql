# This is a script to download one year's worth of data from the ACS,
# and move it into a PostgreSQL database. 
#
# Assumption: The structure and schema etc will already been in place.
#
# *** TBD: Write SQL to generate DB tables with appropriate schema.
#
# Author: Margaret Atkinson (matkinson@ctps.org)
# 10/15/2019
#
# Revised (genericized) by Ben Krepp (bkrepp@ctps.org) 
# This is currently a work-in-progress.
# October, 2020


# *** BEGIN: Variables to be set by user ***
#
# 1. Directories:
#   a. working_dir
#   b. tracts_bgs_subfolder_name
#
# 2. FTP download urls:
# 	a. non_tracts_bgs_download_url
#   b. tracts_bgs_download_url
#   c templates_url
#
# 3. Zip filenames:
#   a. non_tracts_bgs_zip_filename
#   b. tracts_bgs_zip_filename
#   c. templates_zip_filename
#
# 4. PostgreSQL database connection and user info:
#   a. database_name 
#   b. database_host 
#   c. database_port
#   d. database_username 
#   e. database_password
#   f. database_all_user - User with "ALL" privileges on database
#   g. database_select_user -- User with only "SELECT" privileges on database
#
# 5. Data dictionary file name

# Directories
#
directories <- c(working_dir <- "M/CensusTest",
                 tracts_bgs_subfolder_name <- "TBG")

# FTP download URLs
#
urls <- c(non_tracts_bgs_download_url <- "https://www2.census.gov/programs-surveys/acs/summary_file/2018/data/5_year_by_state/Massachusetts_All_Geographies_Not_Tracts_Block_Groups.zip",
          tracts_bgs_download_url <- "https://www2.census.gov/programs-surveys/acs/summary_file/2018/data/5_year_by_state/Massachusetts_Tracts_Block_Groups_Only.zip",
		  templates_url <- "https://www2.census.gov/programs-surveys/acs/summary_file/2018/data/2018_5yr_Summary_FileTemplates.zip")

# Zip file names
#
zip_filenames <- c(non_tracts_bgs_zip_filename <- "MA_2018_ACS_5YR_AG.zip",
                   tracts_bgs_zip_filename <- "MA_2018_ACS_5YR_TBG.zip",
				   templates_zip_filename <- "MA_2018_ACS_5YR_Templates.zip")

# PostgreSQL database connection parameters and user names
#
postgres_info <- c(database_name <- "MY_DATABASE_NAME",
                   database_host <- "foo.bar.org",
				   database_port <- "5432", # Default PostgreSQL port
				   database_username <- "MY_DATABASE_USERNAME",
				   database_password <- "MY_DATABASE_PASSWORD",
				   database_all_user <- "MY_ALL_PRIVS_USERNAME",
				   database_select_user <- "MY_SELECT_ONLY_USERNAME")

# Data dictionary file name
#
dataDictfile <- "M:/CensusDownloading/ACS_5yr_Seq_Table_Number_Lookup.xlsx"

# *** END of variables to be set by the user. ***

# Install package that allows connection between R and PostgreSQL
install.packages("RPostgres")
install.packages("readxl")
install.packages("dplyr")
install.packages("sqldf")
install.packages("stringr")

library(RPostgres)
library(readxl)
library(dplyr)
library(sqldf)
library(stringr)

#
# *** MAIN BODY OF CODE BEGINS HERE ***
#

setwd(directories['working_dir'])

# Download the zip file via ftp for non-tract and blockgroup geometries
download.file(urls['non_tracts_bgs_download_url'], zip_filenames['non_tracts_bgs_zip_filename']) #don't need to loop should be 1 file

# Download the zip file for tracts & block groups geometries
download.file(urls['tracts_bgs_download_url'],zip_filenames['tracts_bgs_zip_filename'])

# Load data dictionary
dataDict <- read_excel(dataDictfile)
dataDict <- data.frame(dataDict)

# Create a 'dictionary' to be used to store the used tables and their corresponding sequences
# Create a vector with all the table names that we use to loop through
tableVector <- c('B00001','B00002','B01001','B01002','B01003','B03002','B05006','B06001','B06010','B06011','B08006','B08012',
                 'B08013','B08015','B08111','B08128','B08131','B08133','B08135','B08136','B08137','B08141','B08201','B08202',
                 'B08203','B08301','B08303','B08526','B08528','B08601','B09019','B11001','B11002','B11016','B12006','B14003',
                 'B15001','B16001','C16002','B16003','B16004','B16005','B17001','C17002','B17017','B17026','B18101','B18102',
                 'B18103','B18104','B18105','B18106','B18107','B08134','B18135','B18140','B19001','B19001H','B19013','B19019','B19025',
                 'B19056','B19057','B19058','B19301','B23001','B23025','B24080','B25002','B25003','B25044','B25046','B25063',
                 'B25064','B25070','B26001','B99162','C17002','C24010','C24030','C24040')
# Initialize the 'dictionary'
tableSeqList <- list()
# Initialize a separate vector to keep track of the base numbers for the tables
bareSeqNum <- c()

# for each table name in the table vector find the sequence number and use as the value in the 'dict'
for (tabl in tableVector) {
  seq <- sqldf(sprintf('select "Sequence.Number" from dataDict where "Table.ID" = "%s"', tabl), row.names = TRUE)
  seqNum <- seq[1,1]
  bareSeqNum <- append(bareSeqNum, seqNum)
  # Pad sequence numbers into 4 digit strings with zeros for ease in constructing file names
  seqNum <- str_pad(seqNum, 4, pad = "0")
  seqNum <- str_pad(seqNum, 7, "right", pad = "0")
  tableSeqList[[tabl]] <- seqNum
}

# Ssave the zip file title (?? - title --> name)
zipFile  <- zip_filenames['non_tracts_bgs_zip_filename']
zipFile2 <- zip_filenames['tracts_bgs_zip_filename']

# Get the file names
zippedNames <- unzip(zipFile,list = TRUE)
# All the files in a list?
files <- zippedNames[,1]

# Initialize the check
# *** TBD: What are we checking for???? Document this.
check <- '0'

seqNames <- c()
# Loop through the file names
# Find the tables that contain the sequence number (e.g. the table number)
# Add these tables to a list
for (tabl in tableSeqList){
  print(tabl)
  if (tabl != check){
    name <- files[grep(tabl, files)]
    # Append these two names to seqNames
    seqNames <- append(seqNames,c(name[1], name[2]))
  } else {
    # print(tabl)
    message("sequence number is identical to previous sequence number")
  }
  check <- tabl
}

# Unzip only the files we want
unzip(zipFile, seqNames) 

# Load tracts & block groups into a different folder to not overwrite other files
unzip(zipFile2, seqNames, exdir = directories['tracts_bgs_subfolder_name'])

# Make a list of file names
filez <- list.files(path=working_dir, pattern="*.txt", full.names=FALSE, recursive=FALSE)
# or maybe just take the list of table names and make a list
tbg_fullpath <- paste(working_dir, "/", directories['tracts_bgs_subfolder_name'])
filez2 <- list.files(path=tbg_fullpath,pattern="*.txt",full.names=FALSE,recursive=FALSE)

mergedfilez <- list()

# Match and merge the files that are the same
for (z in filez){
  for (z2 in filez2){
    if (z == z2){
      z2_path <- paste(tbg_fullpath, z2, sep="")
      dataTable <- read.table(z, sep = ",", na.strings = '.',
                              colClasses = c(V2 = 'character', V4 = 'character', V5 = 'character'))
      dataTable2 <- read.table(z2_path, sep = ",", na.strings = '.',
                               colClasses = c(V2 = 'character',V4 = 'character', V5 = 'character'))
      m <- rbind(dataTable, dataTable2)
      m <- data.frame(m)
      mergedfilez[[z]] = m
      
    } else{
      pass <- 0
    }
  }
}

# Load templates - download the zip file via ftp
download.file(urls['templates_url'], zip_filenames['templates_zip_filename']) #don't need to loop should be 1 file
zipFile2 <- zip_filenames['templates_zip_filename']

# Only grab the template file names for templates we need
templateNames <- c()
zipTempNames <- unzip(zipFile2,list = TRUE)
# All the files in a list?
filesT <- zipTempNames[,1]
check <- '0'
bareSeqNum <- sort(bareSeqNum)
for (sNum in bareSeqNum){
  if (sNum != check){
    sNam <- paste('seq',sNum,".xlsx", sep = "")
    name <- filesT[grep(sNam, filesT)]
    templateNames<- append(templateNames,name)
  }else{
    message("sequence number is identical to previous sequence number")
  }
  check <- sNum
}

# Only read into R the headers we need
# Unzip the whole file
unzip(zipFile2)
# Set a counter 
Chocula <- 1
# Take only the unique sequence numbers
ubareSeqNum <- unique(bareSeqNum)

ubareSeqNum <- as.character(ubareSeqNum)
# Order the unique sequence numbers
ubareSeqNum <- sort(ubareSeqNum)
ubareSeqNum <- as.numeric(ubareSeqNum)
# Order templateNames
templateNames <- sort(templateNames)

# Initialize a vector and a list for storage in next loop
headerNames <- c()
tableHeaders <- list()

Chocula <- 1
# For each template in the list, create a table reading in the header
for (Tfile in templateNames){
  #Tfile <- paste("MA_2018_ACS_5YR_Templates/", Tfile, sep = "")
  print(Tfile)
  # Pad the numbers of the template numbers (for sorting later)
  tempnumber <- str_pad(ubareSeqNum[Chocula], 4, pad = "0")
  tempnumber <- str_pad(tempnumber, 7, "right", pad = "0")
  
  # Create a string to name the header tables (for both estimates and moe)
  headerE <- paste("Header", tempnumber, sep = "e") 
  headerM <- paste("Header", tempnumber, sep = "m")
  print(headerE)
  
  # Create the header tables
  ETable <- assign(headerE[1], read_excel(Tfile, "e"))
  MTable <- assign(headerM[1], read_excel(Tfile, "m"))
  
  # Add the header table names to a vector
  headerNames <- append(headerNames, c(headerE,headerM))
  
  # Add the table names and the tables to a list
  tableHeaders[[headerE]] <- ETable
  tableHeaders[[headerM]] <- MTable
  Chocula <- Chocula +1
}

headerNames <- sort(headerNames)
headerNames2 <- substr(headerNames, 7, 14)

# Load files

dataFrames <- list()

# Sort the names of the tables in mergedfilez
namesMerged <- sort(names(mergedfilez))

countess <- 1

for (x in namesMerged){
  # Get the table that is being chosen
  dataDF <- mergedfilez[[x]]
  # Find the header that matches with the table (x)
  # Find the name
  nameH <- headerNames[countess]
  # print(nameH)
  # Use the name to find the table
  headerDF <- tableHeaders[[nameH]]
  
  # Grab the column names of the header
  header <- colnames(headerDF)
  print(header)
  
  # Add the template header to the dataframe
  colnames(dataDF) <- header
  
  nameDF <- substr(x[1], 1,15)
  # print(nameDF)
  # Assign the name to the dataframe with the header
  fred <-assign(nameDF, dataDF)
  
  dataFrames[[nameDF]] <- dataDF
  
  countess <- countess + 1
}

# Find all the useful 'tables' (sections of the large tables) 
# by parsing from the data dictionary.
# In the future this should be a loop of all 81 used tables
newTabList <- list()

# Separate the useful tables into their own dataframes

for (table in names(dataFrames)){
  print(table)

  fullTab <- data.frame(dataFrames[[table]])
  
  columns <- colnames(data.frame(dataFrames[[table]]))
                      
  for (name in tableVector) {
    seg <- grep(name, columns, ignore.case = TRUE, value = TRUE)
    #if the pattern (name) is not in the col names for the table do nothing
    if (identical(seg, character(0))) {
      pass <- 0
    } else {
      print(seg)
      if (substring(table, 1, 1) == 'e'){
        name_2 <- paste('acs2018_5yr_sf_ma_',tolower(name),'_est', sep = "") 
        print(name_2)
      } else {
        name_2 <- paste('acs2018_5yr_sf_ma_',tolower(name),'_moe', sep = "") 
      }
      newTabList[[name_2]]<- fullTab[,c('FILEID', 'FILETYPE', 'STUSAB','CHARITER', 'SEQUENCE', 'LOGRECNO',seg)]
      #make all column names lowercase
      colnames(newTabList[[name_2]]) <- tolower(colnames(newTabList[[name_2]]))
    }
  }
}
 
# Connect to the PostgreSQL database
# Connecting to PostgreSQL with the specified parameters.
# *** Assumption: The structure and schema etc will already been in place.
# *** TBD: Write SQL to generate DB tables with appropriate schema.
#
con <- dbConnect(RPostgres::Postgres(), 
                 dbname = postgres_info['database_name'], 
                 host = postgres_info['database_host'], 
				 port = postgres_info['database_port'],
                 password = postgres_info['database_password'], 
				 user = postgres_info['database_username'])

#write dataframe as table into the database
#dbWriteTable(con, "newtable", dataDF)
#transfer data to the PostgreSQL database

# if the connection to the database is valid, set as database
if (postgresHasDefault(dbname = postgres_info['database_name'], 
                       host = postgres_info['database_host'], 
					   port = postgres_info['database_port'],
                       password = postgres_info['database_password'], 
					   user = postgres_info['database_username'])) {
  db <- postgresDefault(dbname = postgres_info['database_name'], 
                        host = postgres_info['database_host'], 
						port = postgres_info['database_port'],
                        password = postgres_info['database_password'], 
						user = postgres_info['database_username'])
  
  # Write dataframe as table into the database
  for (table in names(newTabList)){
    dbWriteTable(con, table, newTabList[[table]])
    # Set permissions per table
    query <- paste('GRANT ALL ON TABLE ', table,' TO "', postgres_info['database_all_user'], '";')
    query2 <- paste('GRANT SELECT ON TABLE ', table,' TO "', postgres_info['database_select_user'], '";')
    dbSendQuery(con, query)
    dbSendQuery(con, query2)
  }
  
  # Disconnect from db
  dbDisconnect(db)
}

# For testing purposes only
#
db <- postgresDefault(dbname = postgres_info['database_name'], 
                      host = postgres_info['database_host'], 
					  port = postgres_info['database_port'],
                      password = postgres_info['database_password'], 
					  user = postgres_info['database_username'])

for (table in names(newTabList)){
  print(table)
  dbWriteTable(con, table, newTabList[[table]])
}
