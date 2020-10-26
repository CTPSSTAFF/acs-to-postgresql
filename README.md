# acs-to-postgresql
R script to download ACS census tables and load them into a PostgreSQL database

The author of the original version of this script is Margaret Atkinson (matkinson@ctps.org).  
This repository has been set up to support revising the script to make it more generic and reusable.  
This revision is a work-in-progress begun by Ben Krepp (bkrepp@ctps.org).

Variables whose values are to be "plugged in" by the user have been collected into five vectors,
which we are treating as simple key-value-pairs:

1. Directories: (__dirs__)
	1. working_dir
	2. tracts_bgs_subfolder_name
2. FTP download urls: (__urls__)
	1. non_tracts_bgs_download_url
	2. tracts_bgs_download_url
	3. templates_url
3. Zip filenames: (__zip_filenames__)
	1. non_tracts_bgs_zip_filename
	2. tracts_bgs_zip_filename
	3. templates_zip_filename
4. PostgreSQL database connection parameters and user info: (__postgres_info__)
	1. database_name 
	2. database_host 
	3. database_port
	4. database_username 
	5. database_password
	6. database_all_user - User with "ALL" privileges on database
	7. database_select_user -- User with only "SELECT" privileges on database
5. Data dictionary file name (__dataDictfile__)
