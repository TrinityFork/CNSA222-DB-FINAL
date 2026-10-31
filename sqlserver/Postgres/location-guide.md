# How to find my Postgres' Database on the Debian Database Server
The following steps will walk you through how to connect to the database server, connect to my postgres database, and confirm there is usage data inside it.


1. Begin by connecting to the database server as yourself then changing over to my user oprobst.
The following is what I use to connect, but it is likely password protected: `SSH username@database-username.XXXXlab.net`
Additionally this server's IP is: 10.200.12.148.

2. Connect to the Postgres system user and open its database shell.
To do so run the following command:
`sudo -u postgres psql`

3. List all available databases on the server. We will be looking for "hospital."
To list all available databases run:
`\l`

4. Connect to the Hospital database with the following command. Upon running this command, if you are met with a prompt change to Hospital=#, that confirms that you are able to successfully connect to the database.
`\c hospital`

5. Run the command below to display a list of all the tables currently on the selected database.
`\dt`

From here you can write queries to mess around with this database further through a CLI.
